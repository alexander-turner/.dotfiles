#!/bin/bash

# Install Fish 
sudo apt-get update
sudo apt-get install -y fish

# Clone your dotfiles repository to the home directory
if [ ! -d ~/.dotfiles ]; then # TODO is this needed?
  git clone "$DOTFILES_REPO_URL" ~/.dotfiles
fi

# Create a symbolic link for Fish configuration
mkdir -p ~/.config
if [ ! -L ~/.config/fish ]; then
  ln -s ~/.dotfiles/fish ~/.config/fish
fi

# Set Fish as the default shell
if [ "$(grep "/usr/bin/fish" /etc/shells)" == "" ]; then
  echo "/usr/bin/fish" >> /etc/shells # TODO set this only for my user?
fi

if [ "$SHELL" != "/usr/bin/fish" ]; then
  chsh -s /usr/bin/fish
  echo "Fish is now set as the default shell. Please log out and log back in for the changes to take effect."
else
  echo "Fish is already the default shell."
fi

# # Install themes 
# curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source 
# fisher install jorgebucaran/fisher
#
# # Download a nerd font and install it
# # TODO install
#
# # Install the tide theme
# fisher install IlanCosman/tide@v5
#
# # Configure the theme if not already configured
