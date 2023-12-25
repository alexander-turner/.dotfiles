#!/bin/bash

if [ "$(uname)" == "Darwin" ]; then
  brew install neovim pyvim # neovim
  brew install libusb pkg-config # wally-cli
else # Assume linux
  sudo apt-get install neovim python3-pynvim
fi
# Install vim-plug for plugin management
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# Install wally-cli for keyboard flashing
go install github.com/zsa/wally-cli@latest

# Link .bashrc, .vimrc, and .gitconfig to the home directory, with warnings for existing files
for file in .bashrc .vimrc .gitconfig; do
  if [ -e "$HOME/$file" ]; then
    # Prompt the user to confirm overwriting the existing file
    read -rp "$file already exists. Overwrite? (y/N) " choice
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
touch "$HOME"/.extras.{bashrc,fish}

# Install fish and configure
SCRIPT_DIR="$(dirname "$0")"/bin      # Get the directory of the current script
"$SCRIPT_DIR"/install_fish.sh     # Execute install_fish.sh from that directory

