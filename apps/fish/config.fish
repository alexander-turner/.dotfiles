#!/usr/bin/env fish
# No default greeting
set fish_greeting ''

# These elements don't scale with font size
set --universal tide_right_prompt_prefix ''
set --universal tide_left_prompt_suffix ''

abbr -a goosesay 'cowsay -f ~/.dotfiles/apps/goose.cow'

# Check if the operating system is macOS and set IS_MAC flag
set IS_MAC false
if uname | grep -q Darwin
    set IS_MAC true
end

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /opt/homebrew/anaconda3/bin/conda
    . "/opt/homebrew/anaconda3/etc/fish/conf.d/conda.fish"
else
    if test -f "/opt/homebrew/anaconda3/etc/fish/conf.d/conda.fish"
        . "/opt/homebrew/anaconda3/etc/fish/conf.d/conda.fish"
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

abbr -a e exit

function findfile
    find / -type f 2>/dev/null | grep $argv
end

abbr -a editbashrc 'nvim ~/.bashrc'
abbr -a editfishrc 'nvim ~/.config/fish/config.fish'

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

function pytest
    python -m pytest $argv
end

# Ensure current python env's pip is used
function pip
    python -m pip $argv
end

# Clipboard function differs between macOS and others
function yank # Copy to clipboard
    if $IS_MAC
        pbcopy
    else
        xclip -sel c
    end
end

# Disable automatic paste bracketing in fish
set fish_clipboard_copy_cmd pbcopy
set fish_clipboard_paste_cmd pbpaste

function get_ps
    echo (whoami)'@'(hostname)': '(pwd)
end

# Git aliases
abbr -a gac 'git add -A && git commit -m'
abbr -a gs 'git status'
abbr -a ga 'git add'
abbr -a gb 'git branch'
abbr -a gc 'git commit'
abbr -a gca 'git commit --amend --no-edit'
abbr -a gr 'git restore'
abbr -a grs 'git restore --staged'
abbr -a gd 'git diff'
abbr -a gco 'git checkout'
abbr -a uncommit 'git reset --soft HEAD^'

function gk
    gitk --all &
end

# Merge changes onto main and push
function merge_and_push
    git switch main
    and git pull
    and git merge -
    and git push
    and git switch -
end

# Run post-push hook after git push
function push
    # Store the original exit status after git push
    git push $argv
    set -l push_status $status

    # Find git root directory
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -eq 0
        set -l post_push_hook "$git_root/.git/hooks/post-push"

        # Check if post-push hook exists and is executable
        if test -x "$post_push_hook"
            echo "Running post-push hook..."
            $post_push_hook
        end
    end

    # Return the original push status
    return $push_status
end

set -gx PATH $PATH ~/bin ~/.local/bin /usr/local/go/bin
set -gx EDITOR nvim

abbr -a n nvim

# Trash-cli aliases 
abbr -a tp trash-put
abbr -a tl trash-list

# No unsafe rm by default; to override use "\rm"
function rm
    echo "rm is disabled; using the reversible 'trash-put' instead (aliased to 'tp'). To force rm, use 'command rm'."
    trash-put $argv
end

function grep
    command grep $argv --exclude="*~" --color=always
end

abbr pytest_diff 'pytest -vv --tb=short'

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

abbr -a fxtra editfishextras

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

set -xg NODE_NO_WARNINGS 1
