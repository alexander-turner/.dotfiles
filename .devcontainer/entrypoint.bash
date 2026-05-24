#!/bin/bash
# Post-start entrypoint: configures the firewall as root, then locks
# it down so the node user cannot modify iptables rules.
#
# Strategy: after the firewall is up, remove the sudoers entry that
# allowed node to run this script, and strip setuid/capabilities from
# network and namespace tools so unprivileged users can't touch them.
set -euo pipefail

# Harden the monitor FIRST — before any other work — so monitor.bash is
# never world-readable during the window between image build and lockdown.
WORKSPACE="/workspace"
if [[ -x /workspace/.devcontainer/harden-monitor.bash ]]; then
    bash /workspace/.devcontainer/harden-monitor.bash
elif [[ -f /workspace/.devcontainer/harden-monitor.bash ]]; then
    bash /workspace/.devcontainer/harden-monitor.bash
fi

/usr/local/bin/init-firewall.bash

echo "Locking down firewall and namespace tools..."

rm -f /etc/sudoers.d/node-firewall

for bin in iptables iptables-save iptables-restore ip6tables ipset \
    ip nft nsenter unshare; do
    path=$(command -v "$bin" 2>/dev/null) || continue
    chmod u-s "$path"
    setcap -r "$path" 2>/dev/null || true
done

SAFE_VARS="NODE_OPTIONS|NPM_CONFIG_PREFIX|CLAUDE_CONFIG_DIR|CLAUDE_CODE_VERSION"
BASH_SCRUB=/etc/profile.d/scrub-secrets.sh
FISH_SCRUB=/etc/fish/conf.d/scrub-secrets.fish
mkdir -p /etc/fish/conf.d

cat >"$BASH_SCRUB" <<SCRUB_BASH
#!/bin/bash
while IFS='=' read -r name _; do
    case "\${name,,}" in
        *token*|*secret*|*key*|*pass*|*credential*|*auth*|*api*)
            case "\$name" in
                $SAFE_VARS) ;;
                *) unset "\$name" ;;
            esac
            ;;
    esac
done < <(env)
SCRUB_BASH

cat >"$FISH_SCRUB" <<'SCRUB_FISH'
for name in (env | string match -r '^[^=]+' )
    set -l lower (string lower $name)
    if string match -qr 'token|secret|key|pass|credential|auth|api' $lower
        switch $name
            case NODE_OPTIONS NPM_CONFIG_PREFIX CLAUDE_CONFIG_DIR CLAUDE_CODE_VERSION
            case '*'
                set -e $name
        end
    end
end
SCRUB_FISH

WORKSPACE="/workspace"
if [[ "${CLAUDE_SELF_EDIT:-0}" == "1" ]]; then
    echo "CLAUDE_SELF_EDIT=1 — skipping .claude/ lockdown (supervised mode)."
else
    echo "Making .claude/ config root-owned so the agent cannot modify its own guardrails..."
    if [[ -d "$WORKSPACE/.claude" ]]; then
        chown -R root:root "$WORKSPACE/.claude"
        chmod -R a+r,a-w "$WORKSPACE/.claude"
        chmod a+x "$WORKSPACE/.claude" "$WORKSPACE/.claude/hooks" 2>/dev/null || true
        find "$WORKSPACE/.claude/hooks" -name '*.bash' -exec chmod a+x {} + 2>/dev/null || true
    fi
    echo ".claude/ is root-owned — agent cannot modify its own settings or hooks."
fi

# User-level config is locked unconditionally (including CLAUDE_SELF_EDIT=1)
# because supervised mode unlocks the *project* config, not global overrides.
CLAUDE_USER_DIR="/home/node/.claude"
if [[ -d "$CLAUDE_USER_DIR" ]]; then
    echo "Locking down user-level Claude config..."
    for f in settings.json settings.local.json; do
        touch "$CLAUDE_USER_DIR/$f"
        chown root:root "$CLAUDE_USER_DIR/$f"
        chmod 444 "$CLAUDE_USER_DIR/$f"
    done
    mkdir -p "$CLAUDE_USER_DIR/hooks"
    chown root:root "$CLAUDE_USER_DIR/hooks"
    chmod 555 "$CLAUDE_USER_DIR/hooks"

    # Per-project user overrides live in ~/.claude/projects/<hash>/. Lock
    # the entire tree so the agent can't create or modify per-project
    # settings that might widen its own permissions.
    mkdir -p "$CLAUDE_USER_DIR/projects"
    chown -R root:root "$CLAUDE_USER_DIR/projects"
    chmod -R a+r,a-w "$CLAUDE_USER_DIR/projects"
    find "$CLAUDE_USER_DIR/projects" -type d -exec chmod a+x {} + 2>/dev/null || true
else
    echo "WARN: $CLAUDE_USER_DIR does not exist — skipping user-level lockdown"
fi

# History expansion verification: !! and !n show the expanded command
# for confirmation instead of executing immediately. Prevents planted
# history entries from executing via blind re-use.
echo 'shopt -s histverify' >/etc/profile.d/histverify.sh

echo "Lockdown complete."
