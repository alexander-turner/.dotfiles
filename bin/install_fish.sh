#!/bin/bash

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if ! command_exists fish; then
    brew install fish
fi

# Ensure fish is in PATH (brew may install to /opt/homebrew/bin on Apple Silicon)
if ! command_exists fish; then
    for brew_prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
        if [ -x "$brew_prefix/bin/fish" ]; then
            export PATH="$brew_prefix/bin:$PATH"
            break
        fi
    done
fi

if ! command_exists fish; then
    echo "Error: fish shell not found after installation." >&2
    exit 1
fi

# Set the correct permissions for the Fish configuration directory
chown -R "$USER" "$HOME/.config"

# Set Fish as the default shell
FISH_PATH=$(which fish)
grep -qxF "$FISH_PATH" /etc/shells || echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
chsh -s "$FISH_PATH"

# Remove conflicting fish_prompt.fish before tide install (tide provides its own)
rm -f "$HOME/.config/fish/functions/fish_prompt.fish"

# Install themes using fish
fish <<FISH_SCRIPT
  curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
  fisher install jorgebucaran/fisher

  # Install the tide theme
  fisher install IlanCosman/tide@v6

# Configure the theme if not already configured
FISH_SCRIPT

# Resolve DOTFILES_DIR from this script's location (bin/ is one level down)
DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
bash "$DOTFILES_DIR"/bin/font_install.sh

# Create Fish configuration directory if it doesn't exist
FISH_CONFIG_DIR="$HOME/.config/fish"
mkdir -p "$FISH_CONFIG_DIR/functions"
ln -sf "$DOTFILES_DIR"/apps/fish/config.fish "$FISH_CONFIG_DIR/config.fish"
ln -sf "$DOTFILES_DIR"/apps/fish/functions/fish_prompt.fish "$FISH_CONFIG_DIR/functions/fish_prompt.fish"

# See if user wants preset settings
echo 'Do you want to accept preset tide settings? (Y/n)'
read -r answer

if [ -z "$answer" ] || echo "$answer" | grep -iq "^y"; then
    echo "You accepted the preset settings."
    # Copy if the directory doesnt exist already
    if [ ! -d "$FISH_CONFIG_DIR" ]; then
        cp -r "$DOTFILES_DIR"/fish "$FISH_CONFIG_DIR"
    fi
else
    echo "You declined preset settings."
    fish -c "tide configure"
    ln -sf "$DOTFILES_DIR"/apps/fish/config.fish "$FISH_CONFIG_DIR"/config.fish
fi

fish "$DOTFILES_DIR"/bin/install_fish_plugins.fish
