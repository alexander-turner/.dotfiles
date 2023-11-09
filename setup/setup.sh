#!/bin/bash

# Check if the current directory is not ~/.dotfiles
if [ "$(pwd)" != "$HOME/.dotfiles" ]; then
  # If not, change directory to ~/.dotfiles
  cd "$HOME/.dotfiles" || exit  # Exit if the directory change fails
fi

# Use brace expansion to create links to .bashrc, .vimrc, and .netrc in the home directory
ln "$PWD"/.{bash,vim}rc "$HOME"
ln "$PWD"/.gitconfig "$HOME"

# Use brace expansion to ensure the extras files exist in the home directory
touch "$HOME"/.{bashrc,fish_config}_extras

# Run fish_config
# Assuming fish_config.sh is an executable script in the current directory
./setup/install_fish.sh
