#!/bin/bash

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if ! command_exists fish; then
    echo ":: Installing fish shell..."
    brew install --quiet fish
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
# Use SUDO_USER when running under sudo so we don't chown everything to root
REAL_USER="${SUDO_USER:-$USER}"
# Use sudo if available so we can fix root-owned files from prior sudo runs
if command_exists sudo; then
    sudo chown -R "$REAL_USER" "$HOME/.config/fish" 2>/dev/null || true
else
    chown -R "$REAL_USER" "$HOME/.config/fish" 2>/dev/null || true
fi

# Set Fish as the default shell (skip if already set)
FISH_PATH=$(which fish)
grep -qxF "$FISH_PATH" /etc/shells || echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
if [ "$SHELL" != "$FISH_PATH" ]; then
    chsh -s "$FISH_PATH"
fi

# Configure tide's right-prompt items (must run inside fish; set -U is fish syntax)
fish -c "set -U _tide_right_items status cmd_duration context node python java ruby go time" 2>/dev/null || true

# Remove conflicting fish_prompt.fish before tide install (tide provides its own)
rm -f "$HOME/.config/fish/functions/fish_prompt.fish"

echo ":: Installing fish plugins..."
fish <<FISH_SCRIPT
  curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
  fisher install jorgebucaran/fisher >/dev/null

  fisher install IlanCosman/tide@v6 >/dev/null
FISH_SCRIPT

# Resolve DOTFILES_DIR from this script's location (bin/ is one level down)
DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
bash "$DOTFILES_DIR"/bin/font_install.sh

# Create Fish configuration directory if it doesn't exist
FISH_CONFIG_DIR="$HOME/.config/fish"
mkdir -p "$FISH_CONFIG_DIR/functions"

# See if user wants preset settings
read -rp "Accept preset tide settings? (Y/n) " answer

if [ -z "$answer" ] || echo "$answer" | grep -iq "^y"; then
    # Copy preset config files into existing fish config directory
    # Use -f to remove destination files that can't be opened (e.g. root-owned from prior sudo runs)
    cp -rf "$DOTFILES_DIR"/apps/fish/* "$FISH_CONFIG_DIR/"
else
    fish -c "tide configure"
fi

# Always symlink key config files so changes in dotfiles repo are reflected.
# Done after the copy so cp doesn't try to write through symlinks back to the source.
ln -sf "$DOTFILES_DIR"/apps/fish/config.fish "$FISH_CONFIG_DIR/config.fish"
ln -sf "$DOTFILES_DIR"/apps/fish/functions/fish_prompt.fish "$FISH_CONFIG_DIR/functions/fish_prompt.fish"
ln -sf "$DOTFILES_DIR"/apps/fish/functions/_tide_item_jobs.fish "$FISH_CONFIG_DIR/functions/_tide_item_jobs.fish"

fish "$DOTFILES_DIR"/bin/install_fish_plugins.fish >/dev/null
