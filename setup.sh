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

# Link .bashrc, .vimrc, .gitconfig, and .tmux.conf to the home directory, with warnings for existing files
link_with_overwrite_check "$HOME/.dotfiles/.bashrc" "$HOME/.bashrc"
link_with_overwrite_check "$HOME/.dotfiles/.vimrc" "$HOME/.vimrc"
link_with_overwrite_check "$HOME/.dotfiles/.gitconfig" "$HOME/.gitconfig"
link_with_overwrite_check "$HOME/.dotfiles/.tmux.conf" "$HOME/.tmux.conf"

# Ensure fish config directory exists
mkdir -p "$HOME/.config/fish"
link_with_overwrite_check "$HOME/.dotfiles/apps/fish/config.fish" "$HOME/.config/fish/config.fish"

# Link aider config files
for aider_file in "$HOME/.dotfiles"/.aider*; do
    if [ -f "$aider_file" ]; then
        link_with_overwrite_check "$aider_file" "$HOME/$(basename "$aider_file")"
    fi
done

# Tmux configuration
TPM_BACKUP_DIR=~/.tmux/plugins/.tpm-backup
mkdir -p "$TPM_BACKUP_DIR"
TPM_DIR=~/.tmux/plugins/tpm
mkdir -p "$TPM_DIR"
mv "$TPM_DIR" "$TPM_BACKUP_DIR" >/dev/null 2>&1 || true
git clone https://github.com/tmux-plugins/tpm "$TPM_DIR" >/dev/null # Tmux plugin manager
tmux source ~/.tmux.conf >/dev/null || true
~/.tmux/plugins/tpm/bin/install_plugins >/dev/null

# Use brace expansion to ensure the extras files exist in the home directory
touch "$HOME"/.extras.{bashrc,fish}
touch "$HOME"/.hushlogin # Disable the "Last login" message

# Install fish and configure
SCRIPT_DIR="$(dirname "$0")"/bin # Get the directory of the current script
"$SCRIPT_DIR"/install_fish.sh    # Execute install_fish.sh from that directory

brew_quiet_install() {
    brew install --quiet "$@"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if ! command_exists brew; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>$HOME/.profile
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
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
    link_with_overwrite_check .AutoRaise ~/.AutoRaise

    # Aerospace window manager setup
    brew_quiet_install aerospace
    link_with_overwrite_check .aerospace.toml ~/.aerospace.toml

    # mac-pinentry needed for --sudo
    brew_quiet_install pinentry-mac
    # Update once a week (given in seconds)
    brew autoupdate start 604800 --upgrade --cleanup --sudo
    brew_quiet_install git-credential-manager

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

brew_quiet_install node pnpm
pnpm setup
brew_quiet_install gcc

# Backup iTerm2 settings
mv ~/Library/com.googlecode.iterm2.plist{,.bak} >/dev/null 2>&1 || true
# Sync settings
ln -sf ~/.dotfiles/apps/com.googlecode.iterm2.plist ~/Library/com.googlecode.iterm2.plist >/dev/null 2>&1 || true
# Set up shell integration for iterm2
curl -fsSL https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh | bash >/dev/null

# Create neovim settings which include current vimrc files
# Backup existing configs
for directory in ~/.config/nvim ~.local/{share,state}/nvim ~/cache/nvim; do
    cp "$directory"{,.bak} >/dev/null 2>&1 || true
done

# Remove directory if not a symlink
NEOVIM_CONFIG_DIR="$HOME/.config/nvim"
if [ ! -L "$NEOVIM_CONFIG_DIR" ]; then
    rm -rf "$NEOVIM_CONFIG_DIR"
    ln -s "$HOME/.dotfiles/apps/nvim" "$NEOVIM_CONFIG_DIR" # symlink to this repo's nvim config folder
fi

# Link envchain secrets integration for Fish
if [ -f "$HOME/.dotfiles/apps/fish/envchain_secrets.fish" ]; then
    link_with_overwrite_check "$HOME/.dotfiles/apps/fish/envchain_secrets.fish" "$HOME/.config/fish/envchain_secrets.fish"
fi

# Install AI integrations
fish bin/setup_llm.fish
