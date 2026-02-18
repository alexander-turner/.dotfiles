#!/usr/bin/env fish

if set -q ANTIGRAVITY_AGENT
  exec bash -c "$argv"
end

# No default greeting
set fish_greeting ''

# These elements don't scale with font size
set --universal tide_right_prompt_prefix ''
set --universal tide_left_prompt_suffix ''

abbr -a goosesay 'cowsay -f ~/.dotfiles/apps/goose.cow'

# Check if the operating system is macOS and set IS_MAC flag
if test (uname) = Darwin
    set IS_MAC true
else
    set IS_MAC false
end

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
    if command -q AeroSpace
        # Custom goodness for my workflow https://nikitabobko.github.io/AeroSpace/goodness
        defaults write -g NSWindowShouldDragOnGesture YES

        # Disable windows opening animations
        defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
    end
end

abbr -a e exit

function findfile
    find / -type f 2>/dev/null | grep $argv
end

abbr -a editbashrc 'nvim ~/.bashrc'
abbr -a brc editbashrc

abbr -a fconf 'nvim ~/.config/fish/config.fish'
abbr -a editfishconfig 'nvim ~/.config/fish/config.fish'

function crontab
    set -gx VISUAL nvim
    command crontab $argv
end

function ls
    if $IS_MAC
        /opt/homebrew/opt/coreutils/libexec/gnubin/ls --color="always" --ignore-backups --hide="*.bak" $argv
    else
        command ls --color="always" --ignore-backups --hide="*.bak" $argv
    end
end

set USE_MOSH false
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
    sh ~/.dotfiles/bin/keyboard_flash.sh
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
    if set -q SSH_TTY
        # OSC 52 escape sequence for clipboard passthrough over SSH/mosh
        set -l data (cat | base64 | tr -d '\n')
        printf '\033]52;c;%s\a' $data
    else if $IS_MAC
        pbcopy
    else
        clip
    end
end

# Disable automatic paste bracketing in fish
if $IS_MAC
    set fish_clipboard_copy_cmd pbcopy
    set fish_clipboard_paste_cmd pbpaste
else
    set fish_clipboard_copy_cmd 'xclip -selection clipboard'
    set fish_clipboard_paste_cmd 'xclip -selection clipboard -o'
end

function get_ps
    echo (whoami)'@'(hostname)': '(pwd)
end

# Git aliases
abbr -a gac 'git add -A && git commit -m'
abbr -a gs 'git status'
abbr -a ga 'git add'
abbr -a gb 'git branch'
abbr -a gc 'git commit'
abbr -a gcm 'git commit -m'
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
set -gx SHELL (which fish)

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

# Run extra commands
set CONFIG_PATH ~/.extras.fish
touch $CONFIG_PATH
source $CONFIG_PATH

# Do NOT put API keys in here 
function editfishextras
    nvim $CONFIG_PATH $argv
end

abbr -a fxtra editfishextras

# Only load iTerm2 integration when already inside tmux, not during tmux startup
if test -e {$HOME}/.iterm2_shell_integration.fish
    # Only load if TMUX variable is already set (we're inside a running tmux session)
    if set -q TMUX
        source {$HOME}/.iterm2_shell_integration.fish
    end
end

set -xg NODE_NO_WARNINGS 1

# When you need to expose AI API keys
# WARNING: Exposes the whole namespace, which may change in the future
function ai_secrets_wrap
    envchain ai -- $argv
end

function cloudflare_secrets_wrap
    envchain cloudflare -- $argv
end

function services_secrets_wrap
    envchain services -- $argv
end

function aider_redpill
    set -l aider_bin (type -p aider)
    set -l aider_flags --edit-format editor-diff

    # We export AIDER_MODEL with the 'openai/' prefix. 
    # This forces LiteLLM to use the OpenAI client for the Redpill endpoint.
    envchain ai /bin/sh -c 'export OPENAI_API_KEY=$REDPILL_API_KEY; export OPENAI_API_BASE=https://api.redpill.ai/v1; export AIDER_MODEL=openai/anthropic/claude-sonnet-4.5; exec "$0" "$@"' "$aider_bin" $aider_flags $argv
end

# set -x OLLAMA_ORIGINS *

set -x tide_jobs_number_threshold 0
set -gx PATH $PATH $HOME/go/bin

# pnpm
if $IS_MAC
    set -gx PNPM_HOME "$HOME/Library/pnpm"
else
    set -gx PNPM_HOME "$HOME/.local/share/pnpm"
end
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end
