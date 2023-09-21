# No default greeting
set fish_greeting ''
# Instead have a rainbow talking cow say something random
if status is-interactive
		fortune -s | cowsay -y 
end

# Instead have fortune!

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /home/turn/miniconda3/bin/conda
    eval /home/turn/miniconda3/bin/conda "shell.fish" "hook" $argv | source
end
# <<< conda initialize <<<

. /usr/share/autojump/autojump.fish

# Custom settings
fish_vi_key_bindings

# Disable flow control
stty -ixon

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

function rm
    command rm -I --preserve-root=all $argv
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
    command ls --hide="*~" --color="always" $argv
end

function cdls
    cd $argv
    ls
end

function flash
    sh /home/turn/bin/keyboard_flash.sh
end

function yank # Copy to clipboard
    xclip -sel c
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
set -gx PATH $PATH "/home/turn/bin" "/home/turn/.local/bin"
set -gx EDITOR "/usr/bin/vim"
set -gx GCM_CREDENTIAL_STORE "cache"
set PATH $PATH /usr/local/go/bin

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/turn/Downloads/google-cloud-sdk/path.fish.inc' ]; . '/home/turn/Downloads/google-cloud-sdk/path.fish.inc'; end
