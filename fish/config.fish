# No default greeting
set fish_greeting ''

# Check if the operating system is macOS and set IS_MAC flag
set IS_MAC false
if uname | grep -q Darwin
    set IS_MAC true
end

# Use a rainbow talking cow to say something random on non-macOS systems
if status is-interactive; and not $IS_MAC; and type -q fortune
    fortune -s | cowsay -y
end

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f ~/miniconda3/bin/conda
    eval ~/miniconda3/bin/conda "shell.fish" hook $argv | source
end
# <<< conda initialize <<<

# Autojump setup
if not $IS_MAC
    if test -f ~/.autojump/share/autojump/autojump.fish
        . ~/.autojump/share/autojump/autojump.fish
    else
        . /usr/share/autojump/autojump.fish
    end
else
    [ -f /opt/homebrew/share/autojump/autojump.fish ]; and source /opt/homebrew/share/autojump/autojump.fish
end

# Custom settings
fish_vi_key_bindings

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
    find / -type f 2>/dev/null | grep $argv
end

function editbashrc
    nvim ~/.bashrc
end

function editfishrc
    nvim ~/.config/fish/config.fish
end

function crontab
    set -gx VISUAL nvim
    command crontab $argv
end

function blowitaway
    command rm -rf $argv
end

# Handle ls across OS's
function ls_alias
    if $IS_MAC
        command gls $argv
    else
        command ls $argv
    end
end

function ls
    ls_alias --color="always" --ignore="*~" $argv
end

function cdls
    cd $argv
    ls
end

function flash
    sh ~/bin/keyboard_flash.sh
end

function python --description 'Alias for python3'
    python3 $argv
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
    gitk --all &
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

set -gx PATH $PATH ~/bin ~/.local/bin
set -gx EDITOR nvim
set PATH $PATH /usr/local/go/bin

function n
    nvim $argv
end

# Path homebrew
if $IS_MAC
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    set -gx PATH /home/linuxbrew/.linuxbrew/bin $PATH
    set -gx PATH /home/linuxbrew/.linuxbrew/sbin $PATH
end
set -U HOMEBREW_NO_ANALYTICS 1

# Google Cloud SDK path update
if [ -f '~/Downloads/google-cloud-sdk/path.fish.inc' ]
    . ~/Downloads/google-cloud-sdk/path.fish.inc
end

# Run extra commands
set CONFIG_PATH ~/.extras.fish
touch $CONFIG_PATH
source $CONFIG_PATH

function editfishextras
    nvim $CONFIG_PATH
end
