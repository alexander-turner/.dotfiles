#!/bin/bash
set -euo pipefail

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
# Only chown if something inside is owned by another user (avoids a spurious
# sudo password prompt on every re-run when ownership is already correct).
if [ -d "$HOME/.config/fish" ] &&
    find "$HOME/.config/fish" ! -user "$REAL_USER" -print -quit 2>/dev/null | grep -q .; then
    sudo chown -R "$REAL_USER" "$HOME/.config/fish" || true
fi

# Set Fish as the default shell (skip if already set)
FISH_PATH=$(command -v fish)
grep -qxF "$FISH_PATH" /etc/shells || echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null

# Detect the user's actual login shell from the password DB rather than $SHELL
# ($SHELL reflects the parent process and can be misleading inside tmux/scripts).
if [ "$(uname)" = "Darwin" ]; then
    current_login_shell=$(dscl . -read "/Users/${REAL_USER}" UserShell | awk '{print $2}')
else
    current_login_shell=$(getent passwd "$REAL_USER" | cut -d: -f7)
fi

if [ "$current_login_shell" = "$FISH_PATH" ]; then
    echo ":: Login shell already set to $FISH_PATH; skipping chsh."
else
    # When running as root (via sudo), pass $REAL_USER so we change the right
    # user's shell. As a non-root user, passing a username argument causes PAM
    # to reject the call on many Linux distros, so omit it in that case.
    if [ "$(id -u)" -eq 0 ]; then
        chsh -s "$FISH_PATH" "$REAL_USER" || echo ":: chsh failed — set fish as login shell manually with 'chsh -s $FISH_PATH'." >&2
    else
        chsh -s "$FISH_PATH" || echo ":: chsh failed — set fish as login shell manually with 'chsh -s $FISH_PATH'." >&2
    fi
fi

# Skip fisher/tide install if tide is already present
if fish -c 'functions -q tide' 2>/dev/null; then
    echo ":: tide already installed; skipping fisher/tide setup."
    tide_already_configured=1
else
    tide_already_configured=0
    # Remove conflicting fish_prompt.fish before tide install (tide provides its own)
    rm -f "$HOME/.config/fish/functions/fish_prompt.fish"

    echo ":: Installing fish plugins..."
    fish <<FISH_SCRIPT
      curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
      fisher install jorgebucaran/fisher >/dev/null

      fisher install IlanCosman/tide@v6 >/dev/null
FISH_SCRIPT
fi

# Drop `jobs` from tide's right prompt: the bundled _tide_item_jobs trips on
# non-numeric values from background daemons (e.g. tailscaled). Strip from
# both the canonical config (tide_right_prompt_items) and the runtime list
# (_tide_right_items) — otherwise _tide_remove_unusable_items rebuilds the
# runtime list from the canonical one on the next prompt and reintroduces it.
fish -c '_tide_find_and_remove jobs tide_right_prompt_items; _tide_find_and_remove jobs _tide_right_items' 2>/dev/null || true

# Resolve DOTFILES_DIR from this script's location (bin/ is one level down)
DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
bash "$DOTFILES_DIR"/bin/font_install.bash

# Create Fish configuration directory if it doesn't exist
FISH_CONFIG_DIR="$HOME/.config/fish"
mkdir -p "$FISH_CONFIG_DIR/functions"

if [ "$tide_already_configured" = "1" ]; then
    echo ":: tide already configured; leaving existing settings untouched."
else
    # See if user wants preset settings
    read -rp "Accept preset tide settings? (Y/n) " answer || true

    if [ -z "$answer" ] || echo "$answer" | grep -iq "^y"; then
        # Copy preset config files into existing fish config directory
        # Use -f to remove destination files that can't be opened (e.g. root-owned from prior sudo runs)
        cp -rf "$DOTFILES_DIR"/apps/fish/* "$FISH_CONFIG_DIR/"
    else
        fish -c "tide configure"
    fi
fi

# Always symlink key config files so changes in dotfiles repo are reflected.
# Done after the copy so cp doesn't try to write through symlinks back to the source.
# ln -sf is used directly (not safe_link) because cp -rf above just populated these
# as plain files copied verbatim from the repo — prompting to overwrite would be wrong
# here, and there is no user data at risk.
ln -sf "$DOTFILES_DIR"/apps/fish/config.fish "$FISH_CONFIG_DIR/config.fish"
ln -sf "$DOTFILES_DIR"/apps/fish/functions/fish_prompt.fish "$FISH_CONFIG_DIR/functions/fish_prompt.fish"
mkdir -p "$FISH_CONFIG_DIR/completions"
ln -sf "$DOTFILES_DIR"/apps/fish/completions/dotfiles.fish "$FISH_CONFIG_DIR/completions/dotfiles.fish"
# Clear any stale dangling symlink left by older versions of this script.
if [ -L "$FISH_CONFIG_DIR/functions/_tide_item_jobs.fish" ] &&
    [ ! -e "$FISH_CONFIG_DIR/functions/_tide_item_jobs.fish" ]; then
    rm -f "$FISH_CONFIG_DIR/functions/_tide_item_jobs.fish"
fi

fish "$DOTFILES_DIR"/bin/install_fish_plugins.fish >/dev/null
