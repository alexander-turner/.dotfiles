#!/bin/bash

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

if ! command_exists fish; then
	if [ "$(uname)" == "Darwin" ]; then
		brew install fish
	else
		sudo apt-get update
		sudo apt-get install -y fish
	fi
fi

# Set the correct permissions for the Fish configuration directory
chown -R "$USER" "$HOME/.config"

# Set Fish as the default shell
if [ "$(grep "/usr/bin/fish" /etc/shells)" = "" ]; then
	echo "/usr/bin/fish" >>/etc/shells
fi

if [ "$SHELL" != "/usr/bin/fish" ]; then
	chsh -s /usr/bin/fish
	echo "Fish is now set as the default shell. Please log out and log back in for the changes to take effect."
else
	echo "Fish is already the default shell."
fi

# Install themes using fish
fish <<FISH_SCRIPT
  curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
  fisher install jorgebucaran/fisher

  # Download a nerd font and install it
  read -p $(Please install FiraCode from https://github.com/tonsky/FiraCode) placeholder

  # Install the tide theme
  fisher install IlanCosman/tide@v6

# Configure the theme if not already configured
FISH_SCRIPT

# Create Fish configuration directory if it doesn't exist
FISH_CONFIG_DIR="$HOME/.config/fish"
DOTFILES_DIR="$HOME/.dotfiles"
ln -f "$DOTFILES_DIR"/.config.fish "$DOTFILES_DIR"/fish/config.fish

# See if user wants preset settings
echo "Do you want to accept preset tide settings? (Y/n)"
read answer

if echo "$answer" | grep -iq "^y"; then
	echo "You accepted the preset settings."
	# Copy if the directory doesn't exist already
	if [ ! -d "$FISH_CONFIG_DIR" ]; then
		cp -r "$DOTFILES_DIR"/fish "$FISH_CONFIG_DIR"
	fi
else
	echo "You declined preset settings."
	fish -c "tide configure"
	ln -f "$DOTFILES_DIR"/.config.fish "$FISH_CONFIG_DIR"/config.fish
fi
