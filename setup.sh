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

# ── Symlinks (always run) ────────────────────────────────────────────────────
status_msg "Linking dotfiles..."
safe_link "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
safe_link "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"
safe_link "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
safe_link "$DOTFILES_DIR/.npmrc" "$HOME/.npmrc"
safe_link "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"

mkdir -p "$HOME/.config/fish"
safe_link "$DOTFILES_DIR/apps/fish/config.fish" "$HOME/.config/fish/config.fish"

for aider_file in "$DOTFILES_DIR"/.aider*; do
    if [ -f "$aider_file" ]; then
        safe_link "$aider_file" "$HOME/$(basename "$aider_file")"
    fi
done

# Neovim config
NEOVIM_CONFIG_DIR="$HOME/.config/nvim"
if [ -L "$NEOVIM_CONFIG_DIR" ] && [ "$(readlink "$NEOVIM_CONFIG_DIR")" = "$DOTFILES_DIR/apps/nvim" ]; then
    : # already correct
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

# macOS-only config links
if [ "$(uname)" = "Darwin" ]; then
    safe_link "$DOTFILES_DIR/.aerospace.toml" ~/.aerospace.toml
    safe_link "$DOTFILES_DIR/apps/com.googlecode.iterm2.plist" ~/Library/com.googlecode.iterm2.plist
fi

# Vagrant templates
mkdir -p "$HOME/.config/vagrant-templates"
safe_link "$DOTFILES_DIR/ai/Vagrantfile" "$HOME/.config/vagrant-templates/Vagrantfile"

# Git hooks for this dotfiles repo (relative symlink so the repo is portable)
safe_link "../bin/pre-push" "$DOTFILES_DIR/.hooks/pre-push"

touch "$HOME"/.extras.{bash,fish}
touch "$HOME"/.hushlogin
touch "$HOME"/.vimextras

if [ "$LINK_ONLY" = true ]; then
    status_msg "Symlinks refreshed."
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
        BREW_EVAL_LINE='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
        if ! grep -qxF "$BREW_EVAL_LINE" "$HOME/.profile" 2>/dev/null; then
            echo "$BREW_EVAL_LINE" >>"$HOME/.profile"
        fi
    fi
fi

brew_quiet_install() {
    brew install --quiet "$@"
}

# Install all brew packages from Brewfile
status_msg "Installing from Brewfile..."
brew bundle --quiet --file="$DOTFILES_DIR/Brewfile" || true

# Bitwarden CLI bootstrap. Bitwarden is the cross-machine source of truth
# for secrets; envchain is the local runtime cache. We use the personal
# API key flow (so WebAuthn-only accounts work) and stash both the API
# credentials and the master password in macOS Keychain so the seeder
# can run unattended at shell startup.
#
# All prompts inside bw-login.sh are skippable (empty input).
if command_exists bw && [ -t 0 ]; then
    # `bw status` exits 0 with JSON containing status: "unauthenticated" |
    # "locked" | "unlocked". We grep for the logged-in markers; absence ==
    # not logged in (the safe default that triggers the bootstrap prompt).
    if ! bw status --raw 2>/dev/null | grep -qE '"status":"(locked|unlocked)"'; then
        status_msg "Bitwarden CLI not logged in."
        read -rp "Run bw login bootstrap now? (y/N) " choice
        case "$choice" in
        y | Y) bash "$DOTFILES_DIR/bin/bw-login.sh" || status_msg "bw bootstrap skipped/failed; rerun bin/bw-login.sh later." ;;
        *) status_msg "Skipping. Rerun later with: bash $DOTFILES_DIR/bin/bw-login.sh" ;;
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
    if bash "$DOTFILES_DIR/bin/gh-auth-from-bw.sh" 2>/dev/null; then
        status_msg "gh authenticated from Bitwarden."
    elif [ -t 0 ]; then
        status_msg "Falling back to interactive gh auth (scopes needed: repo, read:org)."
        gh auth login --git-protocol ssh || status_msg "gh auth skipped — run 'gh auth login' later."
    else
        status_msg "Skipping gh auth (non-interactive, no Bitwarden PAT). Run 'gh auth login' manually."
    fi
fi

# Install fish and configure
"$DOTFILES_DIR"/bin/install_fish.sh

if [ "$(uname)" = "Darwin" ]; then
    status_msg "Configuring macOS packages..."

    # Aerospace window manager setup (requires custom tap)
    brew_quiet_install --cask nikitabobko/tap/aerospace

    # Brew autoupdate: update once a week (604800 seconds) with --sudo.
    # Uses a NOPASSWD sudoers fragment scoped to /opt/homebrew/bin/brew
    # so the background launchd job can run sudo without prompting.
    SUDOERS_TEMPLATE="$DOTFILES_DIR/etc/sudoers.d/brew-autoupdate.template"
    SUDOERS_DEST="/etc/sudoers.d/brew-autoupdate"
    if [ -f "$SUDOERS_TEMPLATE" ]; then
        SUDOERS_RENDERED="$(mktemp)"
        sed "s/__USERNAME__/$USER/g" "$SUDOERS_TEMPLATE" >"$SUDOERS_RENDERED"
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

    # Tailscale VPN daemon
    TAILSCALE_PLIST_DEST="/Library/LaunchDaemons/com.$USER.tailscaled.plist"
    sed "s/__USERNAME__/$USER/g" "$DOTFILES_DIR/launchagents/com.tailscaled.plist.template" |
        sudo tee "$TAILSCALE_PLIST_DEST" >/dev/null
    sudo launchctl load "$TAILSCALE_PLIST_DEST" 2>/dev/null || true

    # claude-code-router (ccr): backs claude-{fast,private,think} wrappers.
    # Supervised by launchd so it's running before any wrapper invocation
    # and respawned if it crashes.
    CCR_PLIST_DEST="$HOME/Library/LaunchAgents/com.turntrout.ccr.plist"
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs/com.turntrout.ccr"
    safe_link "$DOTFILES_DIR/launchagents/com.turntrout.ccr.plist" "$CCR_PLIST_DEST"
    launchctl unload "$CCR_PLIST_DEST" 2>/dev/null || true
    launchctl load "$CCR_PLIST_DEST" 2>/dev/null || true

    # Install wally-cli for keyboard flashing
    if command_exists go; then
        go install github.com/zsa/wally-cli@latest >/dev/null
    else
        status_msg "WARN: Go not found, skipping wally-cli install. Install Go first."
    fi

    # iTerm2 shell integration
    curl -fsSL https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh | bash >/dev/null

else # Assume linux
    status_msg "Installing Linux packages..."

    sudo apt-get update -qq
    # libsecret-tools provides `secret-tool`, the Linux equivalent of macOS
    # `security` used by bin/lib/secret-store.sh for caching bw credentials.
    sudo apt-get install -y -qq python3-pynvim pipx cron libsecret-tools
fi

# Install CLI tools via uv (not in Brewfile -- they're Python packages)
uv tool install --quiet trash-cli

# Clear trash which is over 30 days old, daily
if command_exists crontab && command_exists trash-empty; then
    if ! crontab -l 2>/dev/null | grep -q "trash-empty"; then
        (
            crontab -l 2>/dev/null
            echo "@daily $(which trash-empty) 30"
        ) | crontab -
    fi
fi

status_msg "Setting up tmux..."
# Tmux plugin manager setup (must come after tmux is installed)
TPM_DIR=~/.tmux/plugins/tpm
if [ ! -d "$TPM_DIR/.git" ]; then
    rm -rf "$TPM_DIR"
    git clone --quiet https://github.com/tmux-plugins/tpm "$TPM_DIR" >/dev/null
fi
tmux source ~/.tmux.conf >/dev/null 2>&1 || true
~/.tmux/plugins/tpm/bin/install_plugins >/dev/null

if command_exists pnpm; then
    pnpm setup >/dev/null
    pnpm install -g prettier
fi
if [ "$(uname)" != "Darwin" ]; then
    sudo apt-get install -y libxml2-utils
fi

# Backup existing neovim data
for directory in ~/.local/{share,state}/nvim ~/.cache/nvim; do
    cp -r "$directory"{,.bak} >/dev/null 2>&1 || true
done

status_msg "Setting up AI integrations..."
fish "$DOTFILES_DIR/bin/setup_llm.fish"

status_msg "Setup complete."
