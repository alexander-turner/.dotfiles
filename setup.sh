#!/bin/bash

# Function to check if a command exists
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

link_with_overwrite_check() {
    local source_file="$1"
    local target_file="$2"
    if [ -e "$target_file" ]; then
        # Prompt the user to confirm overwriting the existing file
        read -rp "$(basename "$target_file") already exists. Overwrite? (y/N) " choice
        case "$choice" in
        y | Y) ln -sf "$source_file" "$target_file" ;;
        *) echo "Skipping $(basename "$target_file")" ;;
        esac
    else
        ln -sf "$source_file" "$target_file"
    fi
}


echo "Installing brew packages..."
if [ "$(uname)" == "Darwin" ]; then
	brew install --quiet neovim pyvim      # neovim
	brew install --quiet libusb pkg-config # wally-cli
	brew install --quiet coreutils         # For aliasing ls to gls
	brew install --quiet pipx              # In case can't use systemwide pip
	brew install --quiet wget              # Download files

	# Automatically focus and raise windows under cursor
	brew tap dimentium/autoraise
	brew install --quiet autoraise
	brew services restart autoraise

	# Aerospace window manager setup
	brew install --quiet aerospace
	link_with_overwrite_check .aerospace.toml

	ln -f ~/.AutoRaise .AutoRaise
else # Assume linux
	if ! command_exists brew; then
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>$HOME/.profile
		eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
	fi
	brew install --quiet neovim

	# sudo apt-get update
	sudo apt-get install python3-pynvim pipx
fi

brew install --quiet git-credential-manager node

brew install --quiet mosh # Lower-latency mobile shell

# Install reversible trash option
brew install --quiet python
python3 -m pip install --quiet trash-cli
# Prevent accidental deletion of files which should never be deleted
brew install --quiet safe-rm 

# Jump to a previously visited directory via a substring of its path
brew install --quiet autojump

# Install wally-cli for keyboard flashing
# brew install --quiet go
go install github.com/zsa/wally-cli@latest

# Clear trash which is over 30 days old, daily
if ! crontab -l | grep -q "trash-empty"; then
	(
		crontab -l
		echo "@daily $(which trash-empty) 30"
	) | crontab -
fi

# Link .bashrc, .vimrc, .gitconfig, and .tmux.conf to the home directory, with warnings for existing files
link_with_overwrite_check "$HOME/.dotfiles/.bashrc" "$HOME/.bashrc"
link_with_overwrite_check "$HOME/.dotfiles/.vimrc" "$HOME/.vimrc"
link_with_overwrite_check "$HOME/.dotfiles/.gitconfig" "$HOME/.gitconfig"
link_with_overwrite_check "$HOME/.dotfiles/.tmux.conf" "$HOME/.tmux.conf"

# Tmux configuration
mv ~/.tmux/plugins/{tpm,.tpm-backup}
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm # Tmux plugin manager
tmux source ~/.tmux.conf
~/.tmux/plugins/tpm/bin/install_plugins

# Backup iTerm2 settings
mv ~/Library/com.googlecode.iterm2.plist{,.bak}
# Sync settings
ln ~/.dotfiles/apps/com.googlecode.iterm2.plist ~/Library/com.googlecode.iterm2.plist
# Set up shell integration for iterm2
curl -L https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh | bash

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
	ln -s "$HOME/.dotfiles/apps/nvim" "$NEOVIM_CONFIG_DIR" # symlink to this repo's nvim config folder
fi

# Use brace expansion to ensure the extras files exist in the home directory
touch "$HOME"/.extras.{bashrc,fish}
touch "$HOME"/.hushlogin # Disable the "Last login" message

# Install fish and configure
SCRIPT_DIR="$(dirname "$0")"/bin # Get the directory of the current script
"$SCRIPT_DIR"/install_fish.sh    # Execute install_fish.sh from that directory
link_with_overwrite_check "$HOME/.dotfiles/apps/fish/config.fish" "$HOME/.config/fish/config.fish"

# Install AI integrations 
fish bin/setup_llm.fish
