#!/bin/bash
set -euo pipefail

LINK_ONLY=false
if [[ "${1:-}" == "--link-only" ]]; then
    LINK_ONLY=true
fi

safe_link() {
    local source_file="$1"
    local target_file="$2"
    # Already correct symlink — skip
    if [ -L "$target_file" ] && [ "$(readlink "$target_file")" = "$source_file" ]; then
        return
    fi
    # Target exists and is a real file (not a symlink) — prompt before clobbering
    if [ -e "$target_file" ] && [ ! -L "$target_file" ]; then
        read -rp "$(basename "$target_file") already exists (not a symlink). Overwrite? (y/N) " choice
        case "$choice" in
        y | Y) ln -sf "$source_file" "$target_file" ;;
        *) echo "Skipping $(basename "$target_file")" ;;
        esac
    else
        ln -sf "$source_file" "$target_file"
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

status_msg() {
    echo ":: $1"
}

# Resolve dotfiles directory from this script's location
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

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
    safe_link "$DOTFILES_DIR/.AutoRaise" ~/.AutoRaise
    safe_link "$DOTFILES_DIR/.aerospace.toml" ~/.aerospace.toml
    safe_link "$DOTFILES_DIR/apps/com.googlecode.iterm2.plist" ~/Library/com.googlecode.iterm2.plist
fi

# Claude Code
mkdir -p "$HOME/.claude"
safe_link "$DOTFILES_DIR/ai/prompting/skills" "$HOME/.claude/commands"
safe_link "$DOTFILES_DIR/ai/prompting/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# Vagrant templates
mkdir -p "$HOME/.config/vagrant-templates"
safe_link "$DOTFILES_DIR/ai/Vagrantfile" "$HOME/.config/vagrant-templates/Vagrantfile"

# Git hooks for this dotfiles repo
ln -sf "$DOTFILES_DIR/bin/pre-push" "$DOTFILES_DIR/.hooks/pre-push"

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
    if [ "$(uname)" = "Darwin" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>"$HOME/.profile"
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

brew_quiet_install() {
    brew install --quiet "$@"
}

# Install all brew packages from Brewfile
status_msg "Installing from Brewfile..."
brew bundle --quiet --file="$DOTFILES_DIR/Brewfile" || true

# rbw (Bitwarden CLI) bootstrap. Secrets live in Bitwarden; rbw-agent caches
# the unlocked vault locally. The fish wrappers in apps/fish/config.fish
# call `rbw get envchain/<ns>/<VAR>` and need rbw configured + unlocked.
if command_exists rbw; then
    if ! rbw config show 2>/dev/null | grep -q '"email"'; then
        if [ -t 0 ]; then
            read -rp "Bitwarden email for rbw: " bw_email
            if [ -n "$bw_email" ]; then
                rbw config set email "$bw_email"
                status_msg "Run 'rbw login' then 'rbw unlock' to populate the vault cache."
            fi
        else
            status_msg "rbw not configured. Run: rbw config set email <addr>; rbw login; rbw unlock"
        fi
    fi
fi

# GitHub CLI — install and authenticate on first login
if ! command_exists gh; then
    brew_quiet_install gh
fi
if ! gh auth status &>/dev/null; then
    if [ -t 0 ]; then
        status_msg "Authenticating GitHub CLI..."
        gh auth login || status_msg "gh auth skipped — run 'gh auth login' later."
    else
        status_msg "Skipping gh auth (non-interactive shell). Run 'gh auth login' manually."
    fi
fi

# Install fish and configure
"$DOTFILES_DIR"/bin/install_fish.sh

if [ "$(uname)" = "Darwin" ]; then
    status_msg "Configuring macOS packages..."

    # Automatically focus and raise windows under cursor
    brew tap dimentium/autoraise >/dev/null
    brew_quiet_install autoraise
    brew services restart autoraise >/dev/null

    # Aerospace window manager setup (requires custom tap)
    brew_quiet_install --cask nikitabobko/tap/aerospace

    # Brew autoupdate: update once a week (604800 seconds) with --sudo.
    # Uses a NOPASSWD sudoers fragment scoped to /opt/homebrew/bin/brew
    # so the background launchd job can run sudo without prompting.
    SUDOERS_TEMPLATE="$DOTFILES_DIR/etc/sudoers.d/brew-autoupdate.template"
    SUDOERS_DEST="/etc/sudoers.d/brew-autoupdate"
    if [ -f "$SUDOERS_TEMPLATE" ]; then
        SUDOERS_RENDERED="$(mktemp)"
        sed "s/__USERNAME__/$USER/g" "$SUDOERS_TEMPLATE" > "$SUDOERS_RENDERED"
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
    sed "s/__USERNAME__/$USER/g" "$DOTFILES_DIR/launchagents/com.tailscaled.plist.template" \
        | sudo tee "$TAILSCALE_PLIST_DEST" >/dev/null
    sudo launchctl load "$TAILSCALE_PLIST_DEST" 2>/dev/null || true

    # Install wally-cli for keyboard flashing
    go install github.com/zsa/wally-cli@latest >/dev/null

    # iTerm2 shell integration
    curl -fsSL https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh | bash >/dev/null

else # Assume linux
    status_msg "Installing Linux packages..."

    sudo apt-get update -qq
    sudo apt-get install -y -qq python3-pynvim pipx cron
fi

# Install pipx packages (not in Brewfile)
pipx install --quiet trash-cli

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
