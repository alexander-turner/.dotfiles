#!/bin/bash
# uninstall.sh — reverse the symlinks that setup.sh created in $HOME, then
# restore from the most recent ~/.dotfiles-backup/<UTC-stamp>/ when one
# exists.
#
# Safe by construction:
#   * Only touches a target if it is a symlink AND points into this dotfiles
#     repo. Real files at the target path are left alone.
#   * Restores from the lex-largest backup directory (UTC ISO 8601 ⇒ lex sort
#     equals chronological sort).
#   * Does not touch the in-repo .hooks/pre-push relative symlink.
#
# Usage:
#   bash bin/uninstall.sh           # prompts before each macOS launchd unload
#   bash bin/uninstall.sh --yes     # non-interactive; assume yes to prompts
#
# Maintenance invariant: every new safe_link in setup.sh whose target is in
# $HOME must get a matching `remove_dotfile_symlink` call here. See CLAUDE.md
# ("Uninstall upkeep") for the rule.

set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SAFE_LINK_BACKUP_ROOT="${SAFE_LINK_BACKUP_ROOT:-$HOME/.dotfiles-backup}"
IS_MAC=false
[[ "$(uname)" == "Darwin" ]] && IS_MAC=true

# shellcheck source=lib/symlinks.sh disable=SC1091
source "$DOTFILES_DIR/bin/lib/symlinks.sh"

ASSUME_YES=false
if [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
    ASSUME_YES=true
fi

# Most recent backup dir. Stamps are UTC ISO 8601 (e.g. 20260506T143022Z),
# so lexical sort == chronological sort. Filter to that pattern so a stray
# non-stamp directory under ~/.dotfiles-backup (e.g. user notes) can't get
# picked as "latest" just because it lex-sorts after the stamps.
latest_backup_root() {
    [[ -d "$SAFE_LINK_BACKUP_ROOT" ]] || return 1
    local latest
    latest="$(find "$SAFE_LINK_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
        sed 's|.*/||' |
        grep -E '^[0-9]{8}T[0-9]{6}Z$' |
        sort |
        tail -1)"
    [[ -n "$latest" ]] || return 1
    printf '%s\n' "$SAFE_LINK_BACKUP_ROOT/$latest"
}

remove_dotfile_symlink() {
    local target="$1"
    local expected_source="$2"
    if [[ ! -L "$target" ]]; then
        if [[ -e "$target" ]]; then
            echo "  skip $target (not a symlink — leaving alone)"
        fi
        return
    fi
    local actual
    actual="$(readlink "$target")"
    if [[ "$actual" != "$expected_source" ]]; then
        echo "  skip $target -> $actual (not pointing into this dotfiles repo)"
        return
    fi
    rm -f "$target"
    echo "  removed $target"
    # Try to restore from most recent backup.
    local backup_root rel src
    if ! backup_root="$(latest_backup_root)"; then
        return 0
    fi
    if [[ "$target" == "$HOME"/* ]]; then
        rel="${target#"$HOME"/}"
    else
        rel="${target#/}"
    fi
    src="$backup_root/$rel"
    if [[ -e "$src" ]]; then
        mv "$src" "$target"
        echo "  restored backup from $src"
    fi
}

echo ":: Uninstalling dotfiles symlinks from $HOME..."
echo "   (Backups, if any, will be restored from $SAFE_LINK_BACKUP_ROOT/<latest>/)"
echo

# Iterate the shared list from bin/lib/symlinks.sh (sourced above). Symlinked
# directories (e.g. nvim config) go through the same code path — readlink and
# `rm -f` work identically on file and directory symlinks.
while IFS='|' read -r target source _label; do
    remove_dotfile_symlink "$target" "$source"
done < <(managed_symlinks)

if $IS_MAC; then
    # Unload + remove the ccr launch agent. launchctl unload is safe on a
    # missing label; we still prompt because it touches a running service.
    CCR_PLIST="$HOME/Library/LaunchAgents/com.turntrout.ccr.plist"
    if [[ -L "$CCR_PLIST" ]]; then
        if $ASSUME_YES; then
            choice=y
        else
            read -rp "Unload + remove ccr launch agent? (y/N) " choice
        fi
        case "$choice" in
        y | Y)
            launchctl unload "$CCR_PLIST" 2>/dev/null || true
            remove_dotfile_symlink "$CCR_PLIST" "$DOTFILES_DIR/launchagents/com.turntrout.ccr.plist"
            ;;
        *) echo "  skip ccr launch agent" ;;
        esac
    fi
fi

# Remove trash-empty cron job if present
if command -v crontab >/dev/null 2>&1; then
    if crontab -l 2>/dev/null | grep -q "trash-empty"; then
        crontab -l 2>/dev/null | grep -v "trash-empty" | crontab -
        echo "  removed trash-empty cron job"
    fi
fi

echo
echo ":: Uninstall complete. The dotfiles repo at $DOTFILES_DIR is untouched."
echo "   Run 'bash $DOTFILES_DIR/setup.sh' to reinstall."
