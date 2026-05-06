#!/bin/bash
# doctor.sh — health check for this dotfiles install.
#
# Runs a set of read-only assertions and prints PASS/FAIL/SKIP per check.
# Exits non-zero if any required check fails. Optional checks (Bitwarden,
# tmux/TPM, launchd agents) are SKIP rather than FAIL when their tooling
# isn't installed — `doctor.sh` is meant to be safe to run anywhere.
#
# Usage:
#   bash bin/doctor.sh           # run all checks, exit 1 on failure
#   bash bin/doctor.sh --quiet   # only print failing/skipped checks
#
# Maintenance invariant: every new feature added to setup.sh that creates a
# symlink, daemon, or external dependency MUST add a matching check here.
# See CLAUDE.md ("Doctor upkeep") for the rule.

set -uo pipefail

QUIET=false
if [[ "${1:-}" == "--quiet" ]]; then
    QUIET=true
fi

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IS_MAC=false
[[ "$(uname)" == "Darwin" ]] && IS_MAC=true

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
    [[ "$QUIET" == true ]] || printf "  ${GREEN}PASS${NC} %s\n" "$1"
}
fail() {
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} %s\n" "$1"
    [[ -n "${2:-}" ]] && printf "       %s\n" "$2"
}
skip() {
    SKIP=$((SKIP + 1))
    [[ "$QUIET" == true ]] || printf "  ${YELLOW}SKIP${NC} %s (%s)\n" "$1" "$2"
}

section() {
    [[ "$QUIET" == true ]] || printf "\n${YELLOW}=== %s ===${NC}\n" "$1"
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
            fail "$label" "$target missing (run setup.sh --link-only)"
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

check_symlink "$HOME/.bashrc" "$DOTFILES_DIR/.bashrc" ".bashrc"
check_symlink "$HOME/.vimrc" "$DOTFILES_DIR/.vimrc" ".vimrc"
check_symlink "$HOME/.gitconfig" "$DOTFILES_DIR/.gitconfig" ".gitconfig"
check_symlink "$HOME/.tmux.conf" "$DOTFILES_DIR/.tmux.conf" ".tmux.conf"
check_symlink "$HOME/.npmrc" "$DOTFILES_DIR/.npmrc" ".npmrc"
check_symlink "$HOME/.config/fish/config.fish" "$DOTFILES_DIR/apps/fish/config.fish" "fish config"
check_symlink "$HOME/.config/nvim" "$DOTFILES_DIR/apps/nvim" "nvim config"

if $IS_MAC; then
    check_symlink "$HOME/.aerospace.toml" "$DOTFILES_DIR/.aerospace.toml" ".aerospace.toml"
fi

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

for cmd in git fish nvim tmux brew zoxide; do
    check_command "$cmd"
done

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

if command -v bw >/dev/null 2>&1; then
    if bw status --raw 2>/dev/null | grep -qE '"status":"(locked|unlocked)"'; then
        pass "bw is logged in"
    else
        fail "bw login" "not logged in (run: bash bin/bw-login.sh)"
    fi
else
    skip "bw" "bitwarden-cli not installed"
fi

if command -v envchain >/dev/null 2>&1; then
    pass "envchain installed"
else
    skip "envchain" "not installed"
fi

# ── tmux / TPM ──────────────────────────────────────────────────────────────
section "tmux"

TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ -d "$TPM_DIR/.git" ]]; then
    pass "tmux plugin manager (TPM) cloned"
else
    fail "TPM" "$TPM_DIR is not a git checkout (run setup.sh)"
fi

# ── macOS launchd agents ────────────────────────────────────────────────────
if $IS_MAC; then
    section "launchd agents"
    CCR_PLIST="$HOME/Library/LaunchAgents/com.turntrout.ccr.plist"
    if [[ -L "$CCR_PLIST" ]]; then
        if launchctl list 2>/dev/null | grep -q com.turntrout.ccr; then
            pass "ccr launch agent loaded"
        else
            fail "ccr launch agent" "plist symlinked but not loaded (launchctl load $CCR_PLIST)"
        fi
    else
        skip "ccr launch agent" "$CCR_PLIST not present"
    fi
fi

# ── Summary ─────────────────────────────────────────────────────────────────
printf "\n%d passed, %d failed, %d skipped\n" "$PASS" "$FAIL" "$SKIP"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
