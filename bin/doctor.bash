#!/bin/bash
# doctor.bash — health check for this dotfiles install.
#
# Runs a set of read-only assertions and prints PASS/FAIL/SKIP per check.
# Exits non-zero if any required check fails. Optional checks (Bitwarden,
# tmux/TPM, launchd agents) are SKIP rather than FAIL when their tooling
# isn't installed — `doctor.bash` is meant to be safe to run anywhere.
#
# Usage:
#   bash bin/doctor.bash             # only print failing/skipped checks + summary
#   bash bin/doctor.bash --verbose   # also print every passing check
#   bash bin/doctor.bash --quiet     # alias of the default (kept for compat)
#
# Maintenance invariant: every new feature added to setup.bash that creates a
# symlink, daemon, or external dependency MUST add a matching check here.
# See CLAUDE.md ("Doctor upkeep") for the rule.

set -uo pipefail

VERBOSE=false
case "${1:-}" in
--verbose) VERBOSE=true ;;
--quiet | "") ;;
*)
    printf "doctor.bash: unknown flag %q\n" "$1" >&2
    exit 2
    ;;
esac

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IS_MAC=false
[[ "$(uname)" == "Darwin" ]] && IS_MAC=true

# shellcheck source=lib/symlinks.sh disable=SC1091
source "$DOTFILES_DIR/bin/lib/symlinks.sh"

if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
else
    GREEN='' RED='' YELLOW='' NC=''
fi

PASS=0
FAIL=0
SKIP=0

pass() {
    PASS=$((PASS + 1))
    [[ "$VERBOSE" == true ]] && printf "  ${GREEN}PASS${NC} %s\n" "$1"
}
fail() {
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} %s\n" "$1"
    [[ -n "${2:-}" ]] && printf "       %s\n" "$2"
}
skip() {
    SKIP=$((SKIP + 1))
    printf "  ${YELLOW}SKIP${NC} %s (%s)\n" "$1" "$2"
}

section() {
    [[ "$VERBOSE" == true ]] && printf "\n${YELLOW}=== %s ===${NC}\n" "$1"
}

# ── Symlinks ────────────────────────────────────────────────────────────────
section "Symlinks"

check_symlink() {
    local target="$1"
    local expected_source="$2"
    local label="$3"
    if [[ ! -L "$target" ]]; then
        if [[ -e "$target" ]]; then
            fail "$label" "$target exists but is not a symlink"
        else
            fail "$label" "$target missing (run setup.bash --link-only)"
        fi
        return
    fi
    local actual
    actual="$(readlink "$target")"
    if [[ "$actual" != "$expected_source" ]]; then
        fail "$label" "$target -> $actual, expected $expected_source"
    else
        pass "$label"
    fi
}

# Iterate the shared list from bin/lib/symlinks.sh (sourced above).
while IFS='|' read -r target source label; do
    check_symlink "$target" "$source" "$label"
done < <(managed_symlinks)

# Pre-push hook is a relative symlink inside the repo.
if [[ -L "$DOTFILES_DIR/.hooks/pre-push" ]]; then
    target="$(readlink "$DOTFILES_DIR/.hooks/pre-push")"
    if [[ "$target" == "../bin/pre-push" ]]; then
        pass ".hooks/pre-push -> ../bin/pre-push"
    else
        fail ".hooks/pre-push" "points to $target, expected ../bin/pre-push"
    fi
else
    fail ".hooks/pre-push" "not a symlink"
fi

# ── Required commands ───────────────────────────────────────────────────────
section "Required commands"

check_command() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        pass "$cmd"
    else
        fail "$cmd" "not on PATH"
    fi
}

for cmd in git fish nvim tmux brew zoxide gh fzf rg fd bat eza delta tokei dust btm mise carapace shfmt mods; do
    check_command "$cmd"
done

# trash-put / trash-empty are installed via `uv tool install trash-cli`, which
# puts binaries in ~/.local/bin (not a brew prefix). Skip rather than fail so a
# partially-bootstrapped machine (PATH not yet fully configured) doesn't flood
# the output with spurious FAILs.
for cmd in trash-put trash-empty; do
    if command -v "$cmd" >/dev/null 2>&1; then
        pass "$cmd"
    else
        skip "$cmd" "not on PATH (run: uv tool install trash-cli)"
    fi
done

if $IS_MAC; then
    # Borders ships its binary as `borders`. Skip on Linux.
    check_command borders
    # wally-cli is installed on-demand (go install) and only needed for ZSA
    # keyboard flashing — skip rather than fail when it's absent.
    if command -v wally-cli >/dev/null 2>&1; then
        pass "wally-cli"
    else
        skip "wally-cli" "not on PATH (run setup.bash or: go install github.com/zsa/wally-cli@latest)"
    fi
fi

# ── Login shell ─────────────────────────────────────────────────────────────
section "Login shell"

fish_path="$(command -v fish 2>/dev/null || true)"
if [[ -z "$fish_path" ]]; then
    skip "login shell" "fish not installed"
else
    actual_shell=""
    if $IS_MAC && command -v dscl >/dev/null 2>&1; then
        actual_shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
    elif command -v getent >/dev/null 2>&1; then
        actual_shell="$(getent passwd "$USER" | cut -d: -f7)"
    fi
    if [[ -z "$actual_shell" ]]; then
        skip "login shell" "could not read passwd"
    elif [[ "$actual_shell" == "$fish_path" ]]; then
        pass "login shell is fish ($actual_shell)"
    else
        fail "login shell" "is $actual_shell, expected $fish_path (run: chsh -s $fish_path)"
    fi
fi

# ── Bitwarden / envchain ────────────────────────────────────────────────────
section "Secrets"

# Mirror bin/lib/bw-common.sh's BW_CMD resolution. No fallback to `bw`:
# Rust bw is intentionally never used from scripts.
bw_cmd="${BW_CMD:-bw-node}"
if command -v "$bw_cmd" >/dev/null 2>&1; then
    if "$bw_cmd" --version 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
        pass "bw-node usable ($bw_cmd)"
    else
        fail "bw-node" "$bw_cmd doesn't respond to --version (install: pnpm install -g @bitwarden/cli)"
    fi
    if "$bw_cmd" status --raw 2>/dev/null | grep -qE '"status":"(locked|unlocked)"'; then
        pass "bw is logged in ($bw_cmd)"
    else
        fail "bw login" "not logged in (run: bash bin/bw-login.bash)"
    fi
else
    skip "bw" "neither bw-node nor bw on PATH (run setup.bash)"
fi

if command -v envchain >/dev/null 2>&1; then
    pass "envchain installed"
else
    skip "envchain" "not installed"
fi

# ── Brewfile ────────────────────────────────────────────────────────────────
section "Brewfile"

if command -v brew >/dev/null 2>&1; then
    if (cd "$DOTFILES_DIR" && brew bundle check --no-upgrade --file=Brewfile >/dev/null 2>&1); then
        pass "all Brewfile entries installed"
    else
        # Surface the first missing entries so the user knows what to install.
        missing_summary="$(cd "$DOTFILES_DIR" && brew bundle check --no-upgrade --file=Brewfile 2>&1 | head -3 | tr '\n' '; ')"
        fail "Brewfile" "missing entries (${missing_summary%; }) — run 'brew bundle --file=$DOTFILES_DIR/Brewfile'"
    fi
else
    skip "Brewfile" "brew not installed"
fi

# ── tmux / TPM ──────────────────────────────────────────────────────────────
section "tmux"

TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ -d "$TPM_DIR/.git" ]]; then
    pass "tmux plugin manager (TPM) cloned"
else
    fail "TPM" "$TPM_DIR is not a git checkout (run setup.bash)"
fi

# ── cron jobs ───────────────────────────────────────────────────────────────
section "cron"

if command -v crontab >/dev/null 2>&1 && command -v trash-empty >/dev/null 2>&1; then
    if crontab -l 2>/dev/null | grep -q "trash-empty"; then
        pass "trash-empty cron job"
    else
        fail "trash-empty cron" "not scheduled (run setup.bash)"
    fi
else
    skip "trash-empty cron" "crontab or trash-empty not available"
fi

# ── macOS launchd agents ────────────────────────────────────────────────────
if $IS_MAC; then
    section "launchd agents"
    CCR_PLIST="$HOME/Library/LaunchAgents/com.turntrout.ccr.plist"
    if [[ -L "$CCR_PLIST" ]]; then
        if launchctl list 2>/dev/null | grep -q com.turntrout.ccr; then
            pass "ccr launch agent loaded"
        else
            fail "ccr launch agent" "plist symlinked but not loaded (run: launchctl bootstrap gui/$(id -u) $CCR_PLIST)"
        fi
    else
        skip "ccr launch agent" "$CCR_PLIST not present"
    fi

    TS_EXIT_PLIST="$HOME/Library/LaunchAgents/com.turntrout.tailscale-exit-node.plist"
    if [[ -L "$TS_EXIT_PLIST" ]]; then
        if launchctl list 2>/dev/null | grep -q com.turntrout.tailscale-exit-node; then
            pass "tailscale-exit-node launch agent loaded"
        else
            fail "tailscale-exit-node launch agent" "plist symlinked but not loaded (run: launchctl bootstrap gui/$(id -u) $TS_EXIT_PLIST)"
        fi
    else
        skip "tailscale-exit-node launch agent" "$TS_EXIT_PLIST not present"
    fi

    TAILSCALE_PLIST="/Library/LaunchDaemons/com.$USER.tailscaled.plist"
    if [[ -f "$TAILSCALE_PLIST" ]]; then
        pass "Tailscale daemon plist installed"
    else
        skip "Tailscale daemon" "plist not at $TAILSCALE_PLIST (run setup.bash to install)"
    fi
fi

# ── Summary ─────────────────────────────────────────────────────────────────
printf "\n%d passed, %d failed, %d skipped\n" "$PASS" "$FAIL" "$SKIP"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
