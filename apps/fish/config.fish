#!/usr/bin/env fish

if set -q ANTIGRAVITY_AGENT
  exec bash -c "$argv"
end

# Auto-launch tmux if not already inside a tmux session
if status is-interactive; and not set -q TMUX; and command -q tmux
    exec tmux new-session -A -s main
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
    else if test -f /usr/share/autojump/autojump.fish
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

function findfile --description 'Find files by name pattern'
    find . -type f -iname "*$argv*" 2>/dev/null
end

abbr -a editbashrc 'nvim ~/.bashrc'
abbr -a brc editbashrc

abbr -a fconf 'nvim ~/.config/fish/config.fish'
abbr -a editfishconfig 'nvim ~/.config/fish/config.fish'

function crontab
    env VISUAL=nvim command crontab $argv
end

function ls
    if command -q gls
        gls --color="always" --ignore-backups --hide="*.bak" $argv
    else if $IS_MAC
        command ls $argv
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
function yank
    if set -q SSH_TTY
        set -l tmp (mktemp)
        cat >$tmp
        set -l data (base64 < $tmp | tr -d '\n')
        rm $tmp &>/dev/null
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

fish_add_path ~/bin ~/.local/bin /usr/local/go/bin
set -gx EDITOR nvim
set -gx SHELL (status fish-path)

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
    command grep $argv --exclude="*~" --color=auto
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
    fish_add_path /home/linuxbrew/.linuxbrew/bin /home/linuxbrew/.linuxbrew/sbin
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

# Secret wrappers: envchain reads secrets from the macOS Keychain, which is
# auto-unlocked at GUI login (zero-prompt runtime). Bitwarden is the
# cross-machine source of truth; values are pulled into envchain by
# bin/bw-seed-envchain.sh (run on demand via `bwseed` and as a throttled
# shell-startup background job below). See README for the data flow.

function ai_secrets_wrap
    envchain ai -- $argv
end

function cloudflare_secrets_wrap
    envchain cloudflare -- $argv
end

function services_secrets_wrap
    envchain services -- $argv
end

# `command npm` invokes the real npm binary, bypassing this same-named
# fish function. It is fish syntax, not an envchain flag.
function npm
    envchain npm -- command npm $argv
end

function rclone
    envchain cloudflare -- command rclone $argv
end

function twine
    envchain pypi -- command twine $argv
end

# Aider via Redpill: envchain populates REDPILL_API_KEY into the child
# process; the shim script remaps it onto OPENAI_API_KEY and execs aider.
function aider_redpill
    envchain ai -- $HOME/.dotfiles/bin/aider-redpill-shim.sh (type -p aider) --edit-format editor-diff $argv
end

# ── Bitwarden sync helpers ────────────────────────────────────────────────
# bw is the source of truth across machines; envchain is the runtime cache.
# `bwseed` pulls vault → envchain. `bwadd` adds a new secret to both at once.
# Auto-sync on shell startup is throttled by ~/.cache/bw-envchain-sync.stamp.

function bwseed --description 'Refresh envchain from Bitwarden vault'
    bash $HOME/.dotfiles/bin/bw-seed-envchain.sh $argv
end

function bwadd --description 'Add a new secret to Bitwarden + envchain'
    bash $HOME/.dotfiles/bin/bw-add-secret.sh $argv
end

function _bw_envchain_autosync
    # Throttle: skip if last successful run was within the past 6h.
    # stat syntax differs across platforms; try GNU (-c %Y) then BSD (-f %m).
    # Either errors when the stamp doesn't exist; the `or echo 0` forces
    # mtime=0 in that case so the throttle fails through to a sync.
    set -l stamp $HOME/.cache/bw-envchain-sync.stamp
    set -l interval 21600
    mkdir -p (path dirname $stamp) 2>/dev/null
    set -l mtime (stat -c %Y $stamp 2>/dev/null; or stat -f %m $stamp 2>/dev/null; or echo 0)
    if test (math (date +%s) - $mtime) -lt $interval
        return 0
    end
    fish -c "if bash $HOME/.dotfiles/bin/bw-seed-envchain.sh --quiet >/dev/null 2>&1; touch $stamp; end" &
    disown
end

if status is-interactive; and type -q bw
    _bw_envchain_autosync 2>/dev/null
end

# set -x OLLAMA_ORIGINS *

set -x tide_jobs_number_threshold 0
fish_add_path $HOME/go/bin

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
