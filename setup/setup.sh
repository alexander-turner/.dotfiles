#!/bin/bash

# Check if the current directory is not ~/.dotfiles
if [ "$(pwd)" != "$HOME/.dotfiles" ]; then
  # If not, change directory to ~/.dotfiles
  cd "$HOME/.dotfiles" || exit  # Exit if the directory change fails
fi

# Install neovim
if [ "$(uname)" == "Darwin" ]; then
  brew install neovim pynvim
else
  sudo apt-get install neovim python3-pynvim
fi
# Install vim-plug for plugin management
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'


# Link .bashrc, .vimrc, and .gitconfig to the home directory, with warnings for existing files
for file in .bashrc .vimrc .gitconfig; do
  if [ -e "$HOME/$file" ]; then
    # Prompt the user to confirm overwriting the existing file
    read -p "$file already exists. Overwrite? (y/N) " choice
    case "$choice" in
      y|Y ) ln -f "$PWD/$file" "$HOME";;
      * ) echo "Skipping $file";;
    esac
  else
    ln -f "$PWD/$file" "$HOME"
  fi
done

# Create neovim settings which include current vimrc files
NEOVIM_CONFIG_DIR="$HOME/.config/nvim/"
mkdir -p "$NEOVIM_CONFIG_DIR"
# NOTE this just forces the hardlink
ln -f "$PWD"/init.vim "$NEOVIM_CONFIG_DIR" 

# Use brace expansion to ensure the extras files exist in the home directory
touch "$HOME"/.{bashrc,fish_config}_extras

# Run fish_config
# Assuming fish_config.sh is an executable script in the current directory
./setup/install_fish.sh
