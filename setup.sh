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

# Install reversible trash option
pip install trash-cli
# Clear trash which is over 30 days old, daily
(
	crontab -l
	echo "@daily $(which trash-empty) 30"
) | crontab -

# Link .bashrc, .vimrc, and .gitconfig to the home directory, with warnings for existing files
for file in .bashrc .vimrc .gitconfig .tmux.conf; do
	if [ -e "$HOME/$file" ]; then
		# Prompt the user to confirm overwriting the existing file
		read -rp "$file already exists. Overwrite? (y/N) " choice
		case "$choice" in
		y | Y) ln -f "$HOME/.dotfiles/$file" "$HOME/$file" ;;
		*) echo "Skipping $file" ;;
		esac
	else
		ln -f "$HOME/.dotfiles/$file" "$HOME/$file"
	fi
done

# Tmux configuration
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm # Tmux plugin manager
tmux source ~/.tmux.conf
~/.tmux/plugins/tpm/bin/install_plugins

# Create neovim settings which include current vimrc files
# Backup existing configs
for directory in ~/.config/nvim ~.local/{share,state}/nvim ~/cache/nvim; do
	echo "Backing up $directory into $directory.bak."
	cp "$directory"{,.bak} 2>/dev/null
done

# Remove directory if not a symlink
NEOVIM_CONFIG_DIR="$HOME/.config/nvim"
if [ ! -L "$NEOVIM_CONFIG_DIR" ]; then
	rm -rf "$NEOVIM_CONFIG_DIR"
	ln -s "$HOME/.dotfiles/nvim" "$NEOVIM_CONFIG_DIR" # symlink to this repo's nvim config folder
fi

# Use brace expansion to ensure the extras files exist in the home directory
touch "$HOME"/.extras.{bashrc,fish}

# Install fish and configure
SCRIPT_DIR="$(dirname "$0")"/bin # Get the directory of the current script
"$SCRIPT_DIR"/install_fish.sh    # Execute install_fish.sh from that directory
