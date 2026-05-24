function claude --description 'Route claude into devcontainer with per-session worktree + config snapshot'
    # Per-invocation bypasses:
    #   CLAUDE_NO_SANDBOX=1    skip the container (worktree still applies)
    #   CLAUDE_NO_WORKTREE=1   skip the worktree (container still applies)
    # Inside a devcontainer (DEVCONTAINER=true): both bypasses are implied.

    if test -n "$DEVCONTAINER"
        command claude $argv
        return $status
    end

    # workspace_folder = repo root, NOT the worktree dir — git worktrees keep
    # their .git pointer in <repo_root>/.git/worktrees/, so the container has
    # to bind-mount the repo root to make `git` work inside the worktree.
    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    set -l workspace_folder $repo_root
    test -z "$workspace_folder"; and set workspace_folder $PWD
    set -l target_cwd $PWD
    set -l container_cwd /workspace

    if test -n "$repo_root"; and not set -q CLAUDE_NO_WORKTREE
        set -l ts (date -u +%Y%m%dT%H%M%S)-$fish_pid
        set -l branch "claude/$ts"
        set -l wt_relpath ".worktrees/claude-$ts"
        set -l wt_dir "$repo_root/$wt_relpath"
        mkdir -p "$repo_root/.worktrees"
        if not git -C "$repo_root" worktree add "$wt_dir" -b "$branch" >&2
            echo "claude: failed to create worktree; bypass with CLAUDE_NO_WORKTREE=1." >&2
            return 1
        end
        set target_cwd "$wt_dir"
        set container_cwd "/workspace/$wt_relpath"
    end

    if set -q CLAUDE_NO_SANDBOX
        cd "$target_cwd"
        command claude $argv
        return $status
    end

    if not type -q devcontainer
        echo "claude: devcontainer CLI not installed (run setup.bash, or 'pnpm add -g @devcontainers/cli')." >&2
        echo "claude: falling back to host execution; set CLAUDE_NO_SANDBOX=1 to silence this notice." >&2
        cd "$target_cwd"
        command claude $argv
        return $status
    end

    set -l cfg_args
    if not test -e "$workspace_folder/.devcontainer/devcontainer.json"
        set cfg_args --config "$HOME/.dotfiles/.devcontainer/devcontainer.json"
    end

    set -l container_id (docker ps --filter "label=devcontainer.local_folder=$workspace_folder" -q | head -1)
    if test -z "$container_id"
        echo "claude: devcontainer for $workspace_folder not running, starting..." >&2
        if not devcontainer up --workspace-folder "$workspace_folder" $cfg_args >/dev/null
            echo "claude: 'devcontainer up' failed; bypass with CLAUDE_NO_SANDBOX=1." >&2
            return 1
        end
        set container_id (docker ps --filter "label=devcontainer.local_folder=$workspace_folder" -q | head -1)
    end

    if test -z "$container_id"
        echo "claude: container not found via label devcontainer.local_folder=$workspace_folder after 'devcontainer up'." >&2
        echo "claude: bypass with CLAUDE_NO_SANDBOX=1." >&2
        return 1
    end

    # Best-effort snapshot of /home/node/.claude (the claude-code-config named
    # volume) so a corruption inside this session is rollback-able. Keeps 10.
    if test -n "$container_id"
        set -l snap_dir "$HOME/.cache/claude-config-backups"
        mkdir -p "$snap_dir"
        set -l snap_file "$snap_dir/"(date -u +%Y%m%dT%H%M%SZ)".tar"
        if not docker exec $container_id tar -cf - -C /home/node .claude >"$snap_file" 2>/dev/null
            rm -f "$snap_file"
        end
        for old in (find "$snap_dir" -maxdepth 1 -name '*.tar' | sort -r | tail -n +11)
            rm -f "$old"
        end
    end

    set -l docker_flags -i
    if isatty stdin; and isatty stdout
        set -a docker_flags -t
    end
    exec docker exec $docker_flags -w "$container_cwd" -u node "$container_id" \
        claude --dangerously-skip-permissions $argv
end
