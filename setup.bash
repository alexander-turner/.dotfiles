#!/bin/bash
set -euo pipefail

LINK_ONLY=false
if [[ "${1:-}" == "--link-only" ]]; then
    LINK_ONLY=true
fi

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

status_msg() {
    echo ":: $1"
}

# Resolve dotfiles directory from this script's location
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=bin/lib/safe_link.sh disable=SC1091
source "$DOTFILES_DIR/bin/lib/safe_link.sh"
# shellcheck source=bin/lib/symlinks.sh disable=SC1091
source "$DOTFILES_DIR/bin/lib/symlinks.sh"

# ── Symlinks (always run) ────────────────────────────────────────────────────
status_msg "Linking dotfiles..."
# Iterate the shared list. safe_link handles directory targets via mv-to-backup,
# so nvim/borders/aerospace all flow through this one path with no bespoke branches.
# Anything bespoke (in-repo .hooks/pre-push, launchagent plists) stays inline below.
while IFS='|' read -r target source _label; do
    mkdir -p "$(dirname "$target")"
    safe_link "$source" "$target"
done < <(managed_symlinks)

# Neovim config — kept as a second pass because the directory branch uses
# `rm -rf` (more destructive than safe_link's mv-to-backup) after explicit
# user consent. See CLAUDE.md → "Linker upkeep".
NEOVIM_CONFIG_DIR="$HOME/.config/nvim"
if [ -L "$NEOVIM_CONFIG_DIR" ] && [ "$(readlink "$NEOVIM_CONFIG_DIR")" = "$DOTFILES_DIR/apps/nvim" ]; then
    : # already correct (managed_symlinks handled it)
elif [ -e "$NEOVIM_CONFIG_DIR" ] && [ ! -L "$NEOVIM_CONFIG_DIR" ]; then
    read -rp "nvim config dir exists (not a symlink). Overwrite? (y/N) " choice
    case "$choice" in
    y | Y)
        rm -rf "$NEOVIM_CONFIG_DIR"
        ln -s "$DOTFILES_DIR/apps/nvim" "$NEOVIM_CONFIG_DIR"
        ;;
    *) echo "Skipping nvim config" ;;
    esac
else
    rm -f "$NEOVIM_CONFIG_DIR"
    ln -s "$DOTFILES_DIR/apps/nvim" "$NEOVIM_CONFIG_DIR"
fi

# Git hooks for this dotfiles repo (relative symlink — target is inside the
# repo, not under $HOME, so it stays bespoke).
safe_link "../bin/pre-push" "$DOTFILES_DIR/.hooks/pre-push"

touch "$HOME"/.extras.{bash,fish}
touch "$HOME"/.hushlogin
touch "$HOME"/.vimextras

if [ "$LINK_ONLY" = true ]; then
    status_msg "Symlinks refreshed."
    bash "$DOTFILES_DIR/bin/doctor.bash" --quiet || true
    exit 0
fi

# ── Package installation (skipped with --link-only) ──────────────────────────

# Install Homebrew first -- many subsequent steps depend on it
if ! command_exists brew; then
    status_msg "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null
fi

# Always (re)load brew shellenv into this script's environment — handles
# the case where brew was already installed but isn't in PATH (e.g., fresh
# bash invocation without ~/.profile sourced). Also ensures ~/.profile has
# the eval line on Linux for future login shells; the line is appended at
# most once.
if [ "$(uname)" = "Darwin" ]; then
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        # shellcheck disable=SC2016 # literal string, expanded at shell startup
        BREW_EVAL_LINE='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
        if ! grep -qxF "$BREW_EVAL_LINE" "$HOME/.profile" 2>/dev/null; then
            echo "$BREW_EVAL_LINE" >>"$HOME/.profile"
        fi
    fi
fi

brew_quiet_install() {
    brew install --quiet "$@"
}

# Install all brew packages from Brewfile. Retry on transient failure —
# GitHub's HTTP/2 frontend occasionally drops `git clone` mid-tap, and a
# second attempt almost always succeeds. doctor.bash at the end of setup
# catches anything that's still missing after 3 tries.
status_msg "Installing from Brewfile..."
for attempt in 1 2 3; do
    if brew bundle --quiet --file="$DOTFILES_DIR/Brewfile"; then
        break
    fi
    if [ "$attempt" -lt 3 ]; then
        status_msg "brew bundle failed (attempt $attempt/3); retrying in $((attempt * 10))s..."
        sleep $((attempt * 10))
    fi
done

# Bitwarden CLI bootstrap. Bitwarden is the cross-machine source of truth
# for secrets; envchain is the local runtime cache. We use the personal
# API key flow (so WebAuthn-only accounts work) and stash both the API
# credentials and the master password in macOS Keychain so the seeder
# can run unattended at shell startup.
#
# All prompts inside bw-login.bash are skippable (empty input).
if command_exists bw && [ -t 0 ]; then
    # `bw status` exits 0 with JSON containing status: "unauthenticated" |
    # "locked" | "unlocked". We grep for the logged-in markers; absence ==
    # not logged in (the safe default that triggers the bootstrap prompt).
    if ! bw status --raw 2>/dev/null | grep -qE '"status":"(locked|unlocked)"'; then
        status_msg "Bitwarden CLI not logged in."
        read -rp "Run bw login bootstrap now? (y/N) " choice
        case "$choice" in
        y | Y) bash "$DOTFILES_DIR/bin/bw-login.bash" || status_msg "bw bootstrap skipped/failed; rerun bin/bw-login.bash later." ;;
        *) status_msg "Skipping. Rerun later with: bash $DOTFILES_DIR/bin/bw-login.bash" ;;
        esac
    fi
elif ! command_exists bw; then
    status_msg "WARN: bw (bitwarden-cli) not installed; check Brewfile."
fi

# GitHub CLI — install and authenticate on first login
if ! command_exists gh; then
    brew_quiet_install gh
fi
if ! gh auth status &>/dev/null; then
    if bash "$DOTFILES_DIR/bin/gh-auth-from-bw.bash" 2>/dev/null; then
        status_msg "gh authenticated from Bitwarden."
    elif [ -t 0 ]; then
        status_msg "Falling back to interactive gh auth (scopes needed: repo, read:org)."
        gh auth login --git-protocol ssh || status_msg "gh auth skipped — run 'gh auth login' later."
    else
        status_msg "Skipping gh auth (non-interactive, no Bitwarden PAT). Run 'gh auth login' manually."
    fi
fi

# Install fish and configure
"$DOTFILES_DIR"/bin/install_fish.bash

if [ "$(uname)" = "Darwin" ]; then
    status_msg "Configuring macOS packages..."

    # Escape $USER for literal sed replacement (guards against `/` and `&` in
    # unusual usernames). Used for both the sudoers and Tailscale templates.
    ESCAPED_USER="$(printf '%s' "$USER" | sed 's/[\/&]/\\&/g')"

    # Aerospace window manager setup (requires custom tap)
    brew_quiet_install --cask nikitabobko/tap/aerospace

    # Brew autoupdate: update once a week (604800 seconds) with --sudo.
    # Uses a NOPASSWD sudoers fragment scoped to /opt/homebrew/bin/brew
    # so the background launchd job can run sudo without prompting.
    SUDOERS_TEMPLATE="$DOTFILES_DIR/etc/sudoers.d/brew-autoupdate.template"
    SUDOERS_DEST="/etc/sudoers.d/brew-autoupdate"
    if [ -f "$SUDOERS_TEMPLATE" ] && [ ! -f "$SUDOERS_DEST" ]; then
        SUDOERS_RENDERED="$(mktemp)"
        sed "s/__USERNAME__/$ESCAPED_USER/g" "$SUDOERS_TEMPLATE" >"$SUDOERS_RENDERED"
        if sudo visudo -cf "$SUDOERS_RENDERED" >/dev/null; then
            sudo install -o root -g wheel -m 0440 "$SUDOERS_RENDERED" "$SUDOERS_DEST"
        else
            status_msg "WARN: rendered sudoers fragment failed validation; skipping install."
        fi
        rm -f "$SUDOERS_RENDERED"
    fi
    brew tap homebrew/autoupdate 2>/dev/null || true
    brew autoupdate start 604800 --upgrade --cleanup --sudo >/dev/null 2>&1 || true

    # OrbStack: lightweight Docker alternative for macOS
    brew_quiet_install --cask orbstack

    # Tailscale VPN daemon — `com.$USER.tailscaled` is the sole daemon; boot
    # out homebrew's if present. Two daemons racing on /var/run/tailscaled.socket
    # leaves stale provenance on the socket → CLI hits EPERM on connect.
    TAILSCALE_PLIST_DEST="/Library/LaunchDaemons/com.$USER.tailscaled.plist"
    TAILSCALE_PLIST_RENDERED="$(mktemp)"
    sed "s/__USERNAME__/$ESCAPED_USER/g" "$DOTFILES_DIR/launchagents/com.tailscaled.plist.template" \
        >"$TAILSCALE_PLIST_RENDERED"
    needs_bootstrap=false
    if [ ! -f "$TAILSCALE_PLIST_DEST" ] || ! cmp -s "$TAILSCALE_PLIST_RENDERED" "$TAILSCALE_PLIST_DEST"; then
        sudo install -o root -g wheel -m 0644 "$TAILSCALE_PLIST_RENDERED" "$TAILSCALE_PLIST_DEST"
        needs_bootstrap=true
    fi
    rm -f "$TAILSCALE_PLIST_RENDERED"

    HOMEBREW_TAILSCALED_PLIST="/Library/LaunchDaemons/homebrew.mxcl.tailscale.plist"
    if [ -f "$HOMEBREW_TAILSCALED_PLIST" ]; then
        status_msg "Removing homebrew.mxcl.tailscale (conflicts with com.$USER.tailscaled)"
        if sudo launchctl print system/homebrew.mxcl.tailscale &>/dev/null; then
            sudo launchctl bootout system/homebrew.mxcl.tailscale
        fi
        sudo rm -f "$HOMEBREW_TAILSCALED_PLIST"
        needs_bootstrap=true
    fi

    if $needs_bootstrap; then
        if sudo launchctl print "system/com.$USER.tailscaled" &>/dev/null; then
            sudo launchctl bootout "system/com.$USER.tailscaled"
        fi
        sudo launchctl bootstrap system "$TAILSCALE_PLIST_DEST"
    fi
    unset needs_bootstrap

    # claude-code-router (ccr): backs claude-{fast,private,think} wrappers.
    # Supervised by launchd so it's running before any wrapper invocation
    # and respawned if it crashes.
    CCR_PLIST_DEST="$HOME/Library/LaunchAgents/com.turntrout.ccr.plist"
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs/com.turntrout.ccr"
    safe_link "$DOTFILES_DIR/launchagents/com.turntrout.ccr.plist" "$CCR_PLIST_DEST"
    launchctl bootout "gui/$(id -u)" "$CCR_PLIST_DEST" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$CCR_PLIST_DEST" 2>/dev/null || true

    # Tailscale exit-node applier: reasserts the configured Mullvad exit node
    # at login, retrying while tailscaled finishes its handshake.
    TS_EXIT_PLIST_DEST="$HOME/Library/LaunchAgents/com.turntrout.tailscale-exit-node.plist"
    mkdir -p "$HOME/Library/Logs/com.turntrout.tailscale-exit-node"
    safe_link "$DOTFILES_DIR/launchagents/com.turntrout.tailscale-exit-node.plist" "$TS_EXIT_PLIST_DEST"
    launchctl bootout "gui/$(id -u)" "$TS_EXIT_PLIST_DEST" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$TS_EXIT_PLIST_DEST" 2>/dev/null || true

    # Install wally-cli for keyboard flashing
    if ! command_exists wally-cli; then
        go install github.com/zsa/wally-cli@latest >/dev/null
    fi

    # iTerm2 shell integration
    if [ ! -f "$HOME/.iterm2_shell_integration.bash" ]; then
        curl -fsSL https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh | bash >/dev/null
    fi

else # Assume linux
    status_msg "Installing Linux packages..."

    sudo apt-get update -qq
    # libsecret-tools provides `secret-tool`, the Linux equivalent of macOS
    # `security` used by bin/lib/secret-store.sh for caching bw credentials.
    sudo apt-get install -y -qq python3-pynvim pipx cron libsecret-tools
fi

# Install CLI tools via uv (not in Brewfile -- they're Python packages)
if ! command_exists trash-put; then
    uv tool install --quiet trash-cli
fi

if command_exists uv; then
    uv tool install --quiet pre-commit --with pre-commit-uv
fi

# Clear trash which is over 30 days old, monthly
if command_exists crontab && command_exists trash-empty; then
    CRON_ENTRY="@monthly $(command -v trash-empty) 30"
    if [ "$(crontab -l 2>/dev/null | grep "trash-empty" || true)" != "$CRON_ENTRY" ]; then
        (
            crontab -l 2>/dev/null | grep -v "trash-empty"
            echo "$CRON_ENTRY"
        ) | crontab -
    fi
fi

status_msg "Setting up tmux..."
# Tmux plugin manager setup (must come after tmux is installed)
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR/.git" ]; then
    rm -rf "$TPM_DIR"
    git clone --quiet https://github.com/tmux-plugins/tpm "$TPM_DIR" >/dev/null
fi
tmux source ~/.tmux.conf >/dev/null 2>&1 || true
~/.tmux/plugins/tpm/bin/install_plugins >/dev/null

if command_exists pnpm; then
    if [ "$(uname)" = "Darwin" ]; then
        export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
    else
        export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
    fi
    mkdir -p "$PNPM_HOME/bin"
    case ":$PATH:" in
    *":$PNPM_HOME/bin:"*) ;;
    *) export PATH="$PNPM_HOME/bin:$PATH" ;;
    esac
    case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
    esac
    pnpm install -g prettier
    # @bitwarden/cli (Node bw) is required for bin/bw-*.bash scripts — the
    # Rust bw 2026.x has scripting quirks the helpers can't work around.
    pnpm install -g @bitwarden/cli
fi

# Make sure mise has a Node 22 install available for bin/bw-node, which
# pins Node 22 to avoid the inquirer/readline crash on Node 26+. Doesn't
# change the user's per-project Node default.
if command_exists mise; then
    mise install node@22 2>/dev/null || status_msg "WARN: mise install node@22 failed; bin/bw-node will fall back to PATH's node."
fi

# devcontainer CLI — used by the host-side `claude` wrappers (bin/claude and
# apps/fish/functions/claude.fish) to bring up .devcontainer/ on demand.
# pnpm is configured above (PNPM_HOME + PATH), so this lands alongside the
# other globals (claude-code, ccr, prettier, @bitwarden/cli).
if command_exists pnpm; then
    pnpm add --global @devcontainers/cli >/dev/null 2>&1 ||
        status_msg "WARN: 'pnpm add -g @devcontainers/cli' failed. The claude wrapper will fall back to running on the host."
fi

# AI tooling: claude-code + ccr, aider, VSCodium + Roo, wut, llm
# commit-msg hook, Venice default_code resolver cache.
bash "$DOTFILES_DIR/bin/setup_llm.bash"

if [ "$(uname)" != "Darwin" ] && ! command_exists xmllint; then
    sudo apt-get install -y libxml2-utils
fi

# Backup existing neovim data
for directory in ~/.local/{share,state}/nvim ~/.cache/nvim; do
    cp -r "$directory"{,.bak} >/dev/null 2>&1 || true
done

status_msg "Setup complete. Running doctor.bash..."
bash "$DOTFILES_DIR/bin/doctor.bash" || true
