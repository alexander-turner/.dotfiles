function claude --description 'Run Claude Code; auto-launches the dotfiles devcontainer when invoked outside one'
    # Already inside a devcontainer (Dockerfile sets DEVCONTAINER=true) — pass through.
    # Same if the user opted out for this invocation with CLAUDE_NO_SANDBOX=1.
    if test -n "$DEVCONTAINER"; or set -q CLAUDE_NO_SANDBOX
        command claude $argv
        return $status
    end

    if not type -q devcontainer
        echo "claude: devcontainer CLI not installed (run setup.sh, or 'pnpm i -g @devcontainers/cli')." >&2
        echo "claude: falling back to host execution; set CLAUDE_NO_SANDBOX=1 to silence this notice." >&2
        command claude $argv
        return $status
    end

    # Use the repo's own .devcontainer if present, else fall back to the dotfiles config.
    set -l cfg_args
    if not test -e .devcontainer/devcontainer.json
        set cfg_args --config "$HOME/.dotfiles/.devcontainer/devcontainer.json"
    end

    # Idempotent — fast no-op once the container is running for this workspace folder.
    if not devcontainer up --workspace-folder "$PWD" $cfg_args >/dev/null
        echo "claude: 'devcontainer up' failed; bypass with CLAUDE_NO_SANDBOX=1." >&2
        return 1
    end

    devcontainer exec --workspace-folder "$PWD" $cfg_args claude $argv
end
