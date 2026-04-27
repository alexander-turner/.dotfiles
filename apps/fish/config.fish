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
    set -gx VISUAL nvim
    command crontab $argv
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

# Secret wrappers backed by Bitwarden via rbw.
#
# Each secret lives as a Login item named envchain/<ns>/<VAR>; rbw-agent
# caches the unlocked vault, so reads are ~10ms after first unlock. Values
# are captured into local exported variables in begin/end blocks, so they
# vanish when the block exits (including on early return). `set` is a fish
# builtin (no fork/exec), so values never appear in any process's argv.

# Fetch one item; abort with non-zero status if rbw is missing, fails, or
# the item is empty. The `--` guards against item names with leading dashes.
# Trust model: `$item` is always a hardcoded literal supplied by the wrapper
# functions below (e.g. "envchain/ai/OPENAI_API_KEY"); it is never derived
# from user input or the environment. fish's `echo` is a builtin and does
# not shell-expand interpolated values, so there is no injection surface.
function _rbw_get --argument-names item
    if not type -q rbw
        echo "rbw not installed; run 'brew install rbw'" >&2
        return 127
    end
    set -l value (rbw get -- $item 2>/dev/null)
    set -l rc $status
    if test $rc -ne 0
        echo "rbw: failed to fetch '$item' (rc=$rc) — try 'rbw unlock'" >&2
        return $rc
    end
    if test -z "$value"
        echo "rbw: '$item' is empty in the vault" >&2
        return 1
    end
    echo -- $value
end

function ai_secrets_wrap
    begin
        set -lx OPENAI_API_KEY (_rbw_get envchain/ai/OPENAI_API_KEY); or return 1
        set -lx ANTHROPIC_API_KEY (_rbw_get envchain/ai/ANTHROPIC_API_KEY); or return 1
        set -lx GEMINI_API_KEY (_rbw_get envchain/ai/GEMINI_API_KEY); or return 1
        set -lx REDPILL_API_KEY (_rbw_get envchain/ai/REDPILL_API_KEY); or return 1
        set -lx CODEGPT_API_KEY (_rbw_get envchain/ai/CODEGPT_API_KEY); or return 1
        set -lx VENICE_INFERENCE_KEY (_rbw_get envchain/ai/VENICE_INFERENCE_KEY); or return 1
        $argv
    end
end

function cloudflare_secrets_wrap
    begin
        set -lx CLOUDFLARE_API_TOKEN (_rbw_get envchain/cloudflare/CLOUDFLARE_API_TOKEN); or return 1
        set -lx CLOUDFLARE_ACCOUNT_ID (_rbw_get envchain/cloudflare/CLOUDFLARE_ACCOUNT_ID); or return 1
        set -lx CLOUDFLARE_ZONE_ID (_rbw_get envchain/cloudflare/CLOUDFLARE_ZONE_ID); or return 1
        set -lx CLOUDFLARE_TESTING_HEADER (_rbw_get envchain/cloudflare/CLOUDFLARE_TESTING_HEADER); or return 1
        set -lx S3_ENDPOINT_ID_TURNTROUT_MEDIA (_rbw_get envchain/cloudflare/S3_ENDPOINT_ID_TURNTROUT_MEDIA); or return 1
        set -lx ACCESS_KEY_ID_TURNTROUT_MEDIA (_rbw_get envchain/cloudflare/ACCESS_KEY_ID_TURNTROUT_MEDIA); or return 1
        set -lx SECRET_ACCESS_TURNTROUT_MEDIA (_rbw_get envchain/cloudflare/SECRET_ACCESS_TURNTROUT_MEDIA); or return 1
        set -lx TOKEN_VALUE_TURNTROUT_MEDIA (_rbw_get envchain/cloudflare/TOKEN_VALUE_TURNTROUT_MEDIA); or return 1
        set -lx RCLONE_CONFIG_R2_ACCESS_KEY_ID (_rbw_get envchain/cloudflare/RCLONE_CONFIG_R2_ACCESS_KEY_ID); or return 1
        set -lx RCLONE_CONFIG_R2_SECRET_ACCESS_KEY (_rbw_get envchain/cloudflare/RCLONE_CONFIG_R2_SECRET_ACCESS_KEY); or return 1
        set -lx RCLONE_CONFIG_B2_CRYPT_PASSWORD (_rbw_get envchain/cloudflare/RCLONE_CONFIG_B2_CRYPT_PASSWORD); or return 1
        $argv
    end
end

function services_secrets_wrap
    begin
        set -lx DEEPSOURCE_DSN (_rbw_get envchain/services/DEEPSOURCE_DSN); or return 1
        set -lx ORIGINSTAMP_API_KEY (_rbw_get envchain/services/ORIGINSTAMP_API_KEY); or return 1
        set -lx LOST_PIXEL_PROJECT_ID (_rbw_get envchain/services/LOST_PIXEL_PROJECT_ID); or return 1
        set -lx LOST_PIXEL_API_KEY (_rbw_get envchain/services/LOST_PIXEL_API_KEY); or return 1
        $argv
    end
end

# Wrap npm so the auth token is available for publishes.
# `command npm` invokes the real npm binary, bypassing this function.
function npm
    begin
        set -lx NPM_TOKEN (_rbw_get envchain/npm/NPM_TOKEN); or return 1
        command npm $argv
    end
end

# Wrap rclone so Cloudflare R2 / B2 crypt secrets are available.
function rclone
    cloudflare_secrets_wrap command rclone $argv
end

# Wrap twine so PyPI token is available.
function twine
    begin
        set -lx TWINE_USERNAME (_rbw_get envchain/pypi/TWINE_USERNAME); or return 1
        set -lx TWINE_PASSWORD (_rbw_get envchain/pypi/TWINE_PASSWORD); or return 1
        set -lx PYPI_TOKEN (_rbw_get envchain/pypi/PYPI_TOKEN); or return 1
        command twine $argv
    end
end

# Aider via Redpill only needs REDPILL_API_KEY (mapped to OPENAI_API_KEY),
# so we fetch just that one secret rather than calling ai_secrets_wrap and
# loading the full namespace.
function aider_redpill
    set -l aider_bin (type -p aider)
    set -l aider_flags --edit-format editor-diff
    begin
        # Redpill exposes an OpenAI-compatible API, so we feed Aider's OpenAI
        # client the Redpill key + base URL. The 'openai/' prefix on
        # AIDER_MODEL forces LiteLLM to dispatch through the OpenAI client.
        set -lx OPENAI_API_KEY (_rbw_get envchain/ai/REDPILL_API_KEY); or return 1
        set -lx OPENAI_API_BASE https://api.redpill.ai/v1
        set -lx AIDER_MODEL openai/anthropic/claude-sonnet-4.5
        $aider_bin $aider_flags $argv
    end
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

# Added by Jetski
fish_add_path $HOME/.jetski/jetski/bin
