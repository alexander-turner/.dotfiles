#!/usr/bin/env fish
# No default greeting
set fish_greeting ''

# These elements don't scale with font size
set --universal tide_right_prompt_prefix ''
set --universal tide_left_prompt_suffix ''

function goosesay
    cowsay -f ~/.dotfiles/apps/goose.cow $argv
end

# Check if the operating system is macOS and set IS_MAC flag
set IS_MAC false
if uname | grep -q Darwin
    set IS_MAC true
end

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /opt/homebrew/anaconda3/bin/conda
    eval /opt/homebrew/anaconda3/bin/conda "shell.fish" hook $argv | source
else
    if test -f "/opt/homebrew/anaconda3/etc/fish/conf.d/conda.fish"
        fish "/opt/homebrew/anaconda3/etc/fish/conf.d/conda.fish"
    else
        set -x PATH /opt/homebrew/anaconda3/bin $PATH
    end
end
# <<< conda initialize <<<

# Custom settings
fish_vi_key_bindings

# Autojump setup
if $IS_MAC
    [ -f /opt/homebrew/share/autojump/autojump.fish ]; and source /opt/homebrew/share/autojump/autojump.fish
else
    if test -f ~/.autojump/share/autojump/autojump.fish
        . ~/.autojump/share/autojump/autojump.fish
    else
        . /usr/share/autojump/autojump.fish
    end
end

if $IS_MAC
    if command -q cheatsheet
        cheatsheet &
    end

    if command -q AeroSpace
        # Custom goodness for my workflow https://nikitabobko.github.io/AeroSpace/goodness
        defaults write -g NSWindowShouldDragOnGesture YES

        # Disable windows opening animations
        defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
    end
end

# Custom functions
function compress # TODO pull compress
    ~/bin/media_upload/compress.sh
end

function e
    exit
end

# # PCRE is nicer
# function sed
#     perl -pe $argv
# end
#
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

function ls
    /opt/homebrew/opt/coreutils/libexec/gnubin/ls --color="always" --ignore-backups --hide="*.bak" $argv
end


set USE_MOSH true
function ssh
    if $USE_MOSH and (type -q mosh)
        echo "Using mosh instead. To disable, set \$USE_MOSH in shell config."
        mosh $argv
    else if $IS_MAC
        command /usr/bin/ssh $argv
    else
        command ssh $argv
    end
end

if $IS_MAC
    function finder
        open $argv
    end
end

function flash
    sh ~/bin/keyboard_flash.sh
end

# function python --description 'Alias for python3'
#     python3 $argv
# end

function pytest
    python -m pytest $argv
end

# function pip
#     python3 -m pip $argv
# end

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

function uncommit
    git reset --soft HEAD^
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

# Merge changes onto main and push
function merge_and_push
    git switch main
    git pull
    git merge -
    git push
    git switch -
end

set -gx PATH $PATH ~/bin ~/.local/bin /usr/local/go/bin
set -gx EDITOR nvim

function n
    nvim $argv
end

# Trash-cli aliases 
function tp
    trash-put $argv
end

function tl
    trash-list $argv
end

# No unsafe rm by default; to override use "\rm"
function rm
    echo "rm is disabled; using the reversible 'trash-put' instead (aliased to 'tp'). To force rm, use 'command rm'."
    trash-put $argv
end

function grep
    command grep $argv --exclude="*~" --color=always | cut -c1-100
end

function grp # Recursively grep
    grep $argv ** 2>/dev/null
end

# Printing helpers 
function echo_color
    echo (set_color $argv[1])$argv[2](set_color normal)
end

# Path homebrew
if $IS_MAC
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    set -gx PATH /home/linuxbrew/.linuxbrew/bin $PATH
    set -gx PATH /home/linuxbrew/.linuxbrew/sbin $PATH
end

# Google Cloud SDK path update
if [ -f '~/Downloads/google-cloud-sdk/path.fish.inc' ]
    . ~/Downloads/google-cloud-sdk/path.fish.inc
end

# Run extra commands
set CONFIG_PATH ~/.extras.fish
touch $CONFIG_PATH
source $CONFIG_PATH

function editfishextras
    nvim $CONFIG_PATH $argv
end

function fxtra
    editfishextras $argv
end

test -e {$HOME}/.iterm2_shell_integration.fish; and source {$HOME}/.iterm2_shell_integration.fish

if status is-interactive
    and not set -q TMUX
    # Create session 'main' or attach to 'main' if already exists.
    if $TERM_PROGRAM = "iTerm.app"
        tmux -CC new-session -A -s main
    else
        tmux new-session -A -s main
    end
end

alias aider="aider --commit-prompt (cat ~/.config/prompts/commit-system-prompt.txt)"
