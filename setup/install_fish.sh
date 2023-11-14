#!/bin/bash

if [ "$(uname)" == "Darwin" ]; then
 brew install fish
else
 sudo apt-get update
 sudo apt-get install -y fish
fi

# Create Fish configuration directory if it doesn't exist
FISH_CONFIG_DIR="$HOME/.config/fish"
if [ ! -d "$FISH_CONFIG_DIR" ]; then
  mkdir -p "$FISH_CONFIG_DIR"
fi

# Set the correct permissions for the Fish configuration directory
chown -R "$USER" "$HOME/.config"

# Create a symbolic link for Fish configuration
mkdir -p ~/.config
if [ ! -L ~/.config/fish ]; then
  ln -sf ~/.dotfiles/fish ~/.config/fish
fi

# Set Fish as the default shell
if [ "$(grep "/usr/bin/fish" /etc/shells)" = "" ]; then
  echo "/usr/bin/fish" >> /etc/shells 
fi

if [ "$SHELL" != "/usr/bin/fish" ]; then
  chsh -s /usr/bin/fish
  echo "Fish is now set as the default shell. Please log out and log back in for the changes to take effect."
else
  echo "Fish is already the default shell."
fi

# Install themes using fish 
fish << FISH_SCRIPT
  curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
  fisher install jorgebucaran/fisher

  # Download a nerd font and install it
  read -p `Please install FiraCode from https://github.com/tonsky/FiraCode` placeholder

  # Install the tide theme
  fisher install IlanCosman/tide@v6

# Configure the theme if not already configured
FISH_SCRIPT
