#!/bin/bash

if [ "$(uname)" == "Darwin" ]; then
	brew install neovim pyvim     # neovim
	brew install libusb pkg-config # wally-cli
	brew install coreutils # For aliasing ls to gls
else                            # Assume linux
	# First install brew (so that we can get up-to-date neovim)
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	sudo brew install neovim

	sudo apt-get install python3-pynvim
fi

# Install wally-cli for keyboard flashing
go install github.com/zsa/wally-cli@latest

# Link .bashrc, .vimrc, and .gitconfig to the home directory, with warnings for existing files
for file in .bashrc .vimrc .gitconfig .tmux.conf; do
	if [ -e "$HOME/$file" ]; then
		# Prompt the user to confirm overwriting the existing file
		read -rp "$file already exists. Overwrite? (y/N) " choice
		case "$choice" in
		y | Y) ln -f "$PWD/$file" "$HOME" ;;
		*) echo "Skipping $file" ;;
		esac
	else
		ln -f "$PWD/$file" "$HOME"
	fi
done

# Create neovim settings which include current vimrc files
NEOVIM_CONFIG_DIR="$HOME/.config/nvim/"
mkdir -p "$NEOVIM_CONFIG_DIR"
ln -sf "$PWD"/nvim "$HOME"/.config/nvim

# Use brace expansion to ensure the extras files exist in the home directory
touch "$HOME"/.extras.{bashrc,fish}

# Install fish and configure
SCRIPT_DIR="$(dirname "$0")"/bin      # Get the directory of the current script
"$SCRIPT_DIR"/install_fish.sh     # Execute install_fish.sh from that directory

