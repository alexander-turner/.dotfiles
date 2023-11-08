# No default greeting
set fish_greeting ''

# Check if the operating system is macOS and set IS_MAC flag
set IS_MAC 'false'
if uname | grep -q "Darwin"
    set IS_MAC 'true'
end

# Use a rainbow talking cow to say something random on non-macOS systems
if status is-interactive; and not $IS_MAC
    fortune -s | cowsay -y
end

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f ~/miniconda3/bin/conda
    eval ~/miniconda3/bin/conda "shell.fish" "hook" $argv | source
end
# <<< conda initialize <<<

# Autojump setup
if not $IS_MAC
    . /usr/share/autojump/autojump.fish
else
    [ -f /opt/homebrew/share/autojump/autojump.fish ]; and source /opt/homebrew/share/autojump/autojump.fish
end

# Set PROMPT_COMMAND for history appending
set -gx PROMPT_COMMAND "$PROMPT_COMMAND; history -a"

# Custom settings
fish_vi_key_bindings

# Disable flow control
if not $IS_MAC
	stty -ixon
end

# Custom functions
function compress
    ~/bin/media_upload/compress.sh
end

function obsidian
    ~/bin/obsidian-launch.sh
end

function e
    exit
end

# macOS does not need --preserve-root=all for rm
if not $IS_MAC
	function rm
		command rm -I --preserve-root=all $argv
	end
end

function findfile
    find / -type f 2> /dev/null | grep $argv
end

function editbashrc
    vim ~/.bashrc
end

function editfishrc
    vim ~/.config/fish/config.fish
end

function crontab
    set -gx VISUAL vim
    command crontab $argv
end

function blowitaway
    command rm -rf $argv
end

function ls
    command ls --color="always" $argv
end

function cdls
    cd $argv
    ls
end

function flash
    sh ~/bin/keyboard_flash.sh
end

# Clipboard function differs between macOS and others
function yank # Copy to clipboard
	if $IS_MAC
		pbcopy
	else
		xclip -sel c
	end
end

function get_ps
    echo (whoami)'@'(hostname)': '(pwd)
end

# Git aliases
function gac
    git add :/
    git commit -m $argv
end

function gs
    git status $argv
end

function ga
    git add $argv
end

function gb
    git branch $argv
end

function gc
    git commit $argv
end

function gd
    git diff $argv
end

function gco
    git checkout $argv
end

function gk
    gitk --all&
end

function gx
    gitx --all
end

function got
    git $argv
end

function get
    git $argv
end

# Add to PATH
set -gx PATH $PATH ~/bin ~/.local/bin
set -gx EDITOR "/usr/bin/vim"
set -gx GCM_CREDENTIAL_STORE "cache"
set PATH $PATH /usr/local/go/bin

# Run homebrew on macOS
if $IS_MAC 
	eval "$(/opt/homebrew/bin/brew shellenv)"
end

# Google Cloud SDK path update
if [ -f '~/Downloads/google-cloud-sdk/path.fish.inc' ]; . '~/Downloads/google-cloud-sdk/path.fish.inc'; end

# Run extra commands if the file exists
set CONFIG_PATH "~/.fish_config_extras"
if [ -f "$CONFIG_PATH" ]; 
  source "$CONFIG_PATH"
end
