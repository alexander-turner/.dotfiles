#!/bin/bash

if [ "$(uname)" == "Darwin" ]; then
	brew install neovim pynvim     # neovim
	brew install libusb pkg-config # wally-cli
else                            # Assume linux
	# First install brew (so that we can get up-to-date neovim)
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	sudo brew install neovim

	sudo apt-get install python3-pynvim
fi
# Install vim-plug for plugin management
# sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
# https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

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

# Link neovim settings to those included in the repo
mkdir -p "$NEOVIM_CONFIG_DIR"
ln -s "$PWD"/nvim "$HOME"/.config/nvim

# Use brace expansion to ensure the extras files exist in the home directory
touch "$HOME"/.extras.{bashrc,fish}

# Install fish and configure
SCRIPT_DIR="$(dirname "$0")"  # Get the directory of the current script
"$SCRIPT_DIR"/install_fish.sh # Execute install_fish.sh from that directory
