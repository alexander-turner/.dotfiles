#!/bin/bash

# Function to check if a command exists
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

if [ "$(uname)" == "Darwin" ]; then
	brew install neovim pyvim      # neovim
	brew install libusb pkg-config # wally-cli
	brew install coreutils         # For aliasing ls to gls
else                            # Assume linux
	if ! command_exists brew; then
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>$HOME/.profile
		eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
	fi
	brew install neovim

	# sudo apt-get update
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
		y | Y) ln -f "$HOME/.dotfiles/$file" "$HOME" ;;
		*) echo "Skipping $file" ;;
		esac
	else
		ln -f "$HOME/.dotfiles/$file" "$HOME"
	fi
done

# Create neovim settings which include current vimrc files
# Backup existing configs
for directory in ~/.config/nvim ~.local/{share,state}/nvim ~/cache/nvim; do
	echo "Backing up $directory into $directory.bak."
	# rm -rf "$directory.bak" 2>/dev/null
	mv "$directory"{,.bak} 2>/dev/null
done

# Remove directory if not a symlink
NEOVIM_CONFIG_DIR="$HOME/.config/nvim/"
if [ ! -L "$NEOVIM_CONFIG_DIR" ]; then
	rm -rf "$NEOVIM_CONFIG_DIR"
fi
ln -s nvim $NEOVIM_CONFIG_DIR # symlink to this repo's nvim config folder

# git clone https://github.com/LazyVim/starter ~/.config/nvim
# rm -rf ~/.config/nvim/.git
# ln -f "$HOME"/.dotfiles/nvim_config_lazy.lua "$NEOVIM_CONFIG_DIR"/lua/config/lazy.lua
# ln -f "$HOME"/.dotfiles/lazyvim.json "$NEOVIM_CONFIG_DIR"/lazyvim.json
#
# EXTRAS_FILE="$HOME"/.nvim.extras.lua
# touch "$EXTRAS_FILE"
# ln -f "$EXTRAS_FILE" "$NEOVIM_CONFIG_DIR"/extras.lua
#
# # Sync baseline plugins
# ln -f "$HOME"/.dotfiles/init.lua "$NEOVIM_CONFIG_DIR"/init.lua

# Use brace expansion to ensure the extras files exist in the home directory
touch "$HOME"/.extras.{bashrc,fish}

# Install fish and configure
SCRIPT_DIR="$(dirname "$0")"/bin # Get the directory of the current script
"$SCRIPT_DIR"/install_fish.sh    # Execute install_fish.sh from that directory
