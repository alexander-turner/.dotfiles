#!/bin/bash

link_with_overwrite_check() {
    local source_file="$1"
    local target_file="$2"
    if [ -e "$target_file" ]; then
        # Prompt the user to confirm overwriting the existing file
        read -rp "$(basename "$target_file") already exists. Overwrite? (y/N) " choice
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

# Resolve dotfiles directory from this script's location
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Install Homebrew first -- many subsequent steps depend on it
if ! command_exists brew; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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

# Link .bashrc, .vimrc, .gitconfig, and .tmux.conf to the home directory, with warnings for existing files
link_with_overwrite_check "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
link_with_overwrite_check "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"
link_with_overwrite_check "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
link_with_overwrite_check "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"

# Ensure fish config directory exists
mkdir -p "$HOME/.config/fish"
link_with_overwrite_check "$DOTFILES_DIR/apps/fish/config.fish" "$HOME/.config/fish/config.fish"

# Link aider config files
for aider_file in "$DOTFILES_DIR"/.aider*; do
    if [ -f "$aider_file" ]; then
        link_with_overwrite_check "$aider_file" "$HOME/$(basename "$aider_file")"
    fi
done

# Use brace expansion to ensure the extras files exist in the home directory
touch "$HOME"/.extras.{bash,fish}
touch "$HOME"/.hushlogin # Disable the "Last login" message

# Install fish and configure (brew is now available)
"$DOTFILES_DIR"/bin/install_fish.sh
if [ "$(uname)" = "Darwin" ]; then
    brew_quiet_install neovim pyvim      # neovim
    brew_quiet_install libusb pkg-config # wally-cli
    brew_quiet_install coreutils         # For aliasing ls to gls
    brew_quiet_install pipx              # In case can't use systemwide pip
    brew_quiet_install wget              # Download files

    # Automatically focus and raise windows under cursor
    brew tap dimentium/autoraise
    brew_quiet_install autoraise
    brew services restart autoraise
    link_with_overwrite_check "$DOTFILES_DIR/.AutoRaise" ~/.AutoRaise

    # Aerospace window manager setup
    brew_quiet_install aerospace
    link_with_overwrite_check "$DOTFILES_DIR/.aerospace.toml" ~/.aerospace.toml

    # mac-pinentry needed for --sudo
    brew_quiet_install pinentry-mac
    # Update once a week (given in seconds)
    brew tap homebrew/autoupdate 2>/dev/null || true
    brew autoupdate start 604800 --upgrade --cleanup --sudo
    brew_quiet_install git-credential-manager

    # OrbStack: lightweight Docker alternative for macOS
    brew install --cask orbstack

    # Tailscale VPN daemon (runs as a LaunchDaemon on macOS)
    brew_quiet_install tailscale
    TAILSCALE_PLIST_DEST="/Library/LaunchDaemons/com.$USER.tailscaled.plist"
    sed "s/__USERNAME__/$USER/g" "$DOTFILES_DIR/launchagents/com.tailscaled.plist.template" \
        | sudo tee "$TAILSCALE_PLIST_DEST" >/dev/null
    sudo launchctl load "$TAILSCALE_PLIST_DEST"

    # Install wally-cli for keyboard flashing (macOS only due to dependencies)
    brew_quiet_install go
    go install github.com/zsa/wally-cli@latest >/dev/null

else # Assume linux
    brew_quiet_install neovim

    # Install python3-pynvim, pipx, and cron
    sudo apt-get update
    sudo apt-get install -y python3-pynvim pipx cron
fi

brew_quiet_install mosh # Lower-latency mobile shell

# Install envchain for secure secret management via OS keychain
brew_quiet_install envchain

brew_quiet_install xclip

# Install reversible trash option
brew_quiet_install python
if ! command_exists pipx; then
    brew_quiet_install pipx
fi
pipx install --quiet trash-cli
# Prevent accidental deletion of files which should never be deleted
brew_quiet_install safe-rm

# Clear trash which is over 30 days old, daily
if command_exists crontab && command_exists trash-empty; then
    if ! crontab -l 2>/dev/null | grep -q "trash-empty"; then
        (
            crontab -l 2>/dev/null
            echo "@daily $(which trash-empty) 30"
        ) | crontab -
    fi
fi

brew_quiet_install tmux

# Tmux plugin manager setup (must come after tmux is installed)
TPM_BACKUP_DIR=~/.tmux/plugins/.tpm-backup
mkdir -p "$TPM_BACKUP_DIR"
TPM_DIR=~/.tmux/plugins/tpm
mkdir -p "$TPM_DIR"
mv "$TPM_DIR" "$TPM_BACKUP_DIR" >/dev/null 2>&1 || true
git clone https://github.com/tmux-plugins/tpm "$TPM_DIR" >/dev/null # Tmux plugin manager
tmux source ~/.tmux.conf >/dev/null 2>&1 || true
~/.tmux/plugins/tpm/bin/install_plugins >/dev/null

brew_quiet_install node pnpm
pnpm setup
brew_quiet_install gcc

# Backup iTerm2 settings
mv ~/Library/com.googlecode.iterm2.plist{,.bak} >/dev/null 2>&1 || true
# Sync settings
ln -sf "$DOTFILES_DIR/apps/com.googlecode.iterm2.plist" ~/Library/com.googlecode.iterm2.plist >/dev/null 2>&1 || true
# Set up shell integration for iterm2
curl -fsSL https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh | bash >/dev/null

# Create neovim settings which include current vimrc files
# Backup existing configs
for directory in ~/.config/nvim ~/.local/{share,state}/nvim ~/.cache/nvim; do
    cp "$directory"{,.bak} >/dev/null 2>&1 || true
done

# Remove directory if not a symlink
NEOVIM_CONFIG_DIR="$HOME/.config/nvim"
if [ ! -L "$NEOVIM_CONFIG_DIR" ]; then
    rm -rf "$NEOVIM_CONFIG_DIR"
    ln -s "$DOTFILES_DIR/apps/nvim" "$NEOVIM_CONFIG_DIR" # symlink to this repo's nvim config folder
fi

# Use brace expansion to ensure the extras files exist in the home directory
touch "$HOME"/.extras.{bash,fish}
touch "$HOME"/.vimextras

# Link envchain secrets integration for Fish
if [ -f "$DOTFILES_DIR/apps/fish/envchain_secrets.fish" ]; then
    link_with_overwrite_check "$DOTFILES_DIR/apps/fish/envchain_secrets.fish" "$HOME/.config/fish/envchain_secrets.fish"
fi

# Claude Code configuration
mkdir -p "$HOME/.claude"
# Symlink skills directory and CLAUDE.md
rm -rf "$HOME/.claude/commands"
ln -s "$DOTFILES_DIR/ai/prompting/skills" "$HOME/.claude/commands"
ln -sf "$DOTFILES_DIR/ai/prompting/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# Vagrant templates
mkdir -p "$HOME/.config/vagrant-templates"
ln -sf "$DOTFILES_DIR/ai/Vagrantfile" "$HOME/.config/vagrant-templates/Vagrantfile"

# Install git hooks for this repo
# NOTE: When core.hooksPath is set (e.g. to .hooks/), .git/hooks/ is ignored.
# Link pre-push into .hooks/ so it fires regardless of hooksPath setting.
ln -sf "$DOTFILES_DIR/bin/pre-push" "$DOTFILES_DIR/.hooks/pre-push"

# Install AI integrations
fish "$DOTFILES_DIR/bin/setup_llm.fish"
