#!/bin/bash

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

if ! command_exists fish; then
	brew install fish
fi

# Set the correct permissions for the Fish configuration directory
chown -R "$USER" "$HOME/.config"

# Set Fish as the default shell
if [ "$(grep "fish" /etc/shells)" = "" ]; then
	echo "/usr/bin/fish" >>/etc/shells
	echo "/opt/homebrew/bin/fish" >>/etc/shells
fi

if [ "$(grep "fish" "$SHELL")" = "" ]; then
	echo "Requesting sudo in order to make fish the default shell".
	sudo chsh -s /usr/bin/fish
	echo "Fish is now set as the default shell."
else
	echo "Fish is already the default shell."
fi

# Install themes using fish
fish <<FISH_SCRIPT
  curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
  fisher install jorgebucaran/fisher

  # Install the tide theme
  fisher install IlanCosman/tide@v6

# Configure the theme if not already configured
FISH_SCRIPT

DOTFILES_DIR="$HOME/.dotfiles"
bash "$DOTFILES_DIR"/bin/font_install.sh

# Create Fish configuration directory if it doesn't exist
FISH_CONFIG_DIR="$HOME/.config/fish"
ln -f "$DOTFILES_DIR"/apps/fish/config.fish "$FISH_CONFIG_DIR/config.fish"

# See if user wants preset settings
echo 'Do you want to accept preset tide settings? (Y/n)'
read answer

if echo "$answer" | grep -iq "^y"; then
	echo "You accepted the preset settings."
	# Copy if the directory doesnt exist already
	if [ ! -d "$FISH_CONFIG_DIR" ]; then
		cp -r "$DOTFILES_DIR"/fish "$FISH_CONFIG_DIR"
	fi
else
	echo "You declined preset settings."
	fish -c "tide configure"
	ln -f "$DOTFILES_DIR"/.config.fish "$FISH_CONFIG_DIR"/config.fish
fi
