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

ASSUME_YES=false
if [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
    ASSUME_YES=true
fi

# Most recent backup dir. Stamps are UTC ISO 8601 (e.g. 20260506T143022Z),
# so lexical sort == chronological sort.
latest_backup_root() {
    [[ -d "$SAFE_LINK_BACKUP_ROOT" ]] || return 1
    local latest
    latest="$(find "$SAFE_LINK_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's|.*/||' | sort | tail -1)"
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

# Same shape as remove_dotfile_symlink but for directory targets (nvim
# config). Symlinked dirs need -d on the readlink test, but readlink works
# the same — handle as a normal symlink path.
remove_dotfile_symlink_dir() {
    remove_dotfile_symlink "$@"
}

echo ":: Uninstalling dotfiles symlinks from $HOME..."
echo "   (Backups, if any, will be restored from $SAFE_LINK_BACKUP_ROOT/<latest>/)"
echo

remove_dotfile_symlink "$HOME/.bashrc"      "$DOTFILES_DIR/.bashrc"
remove_dotfile_symlink "$HOME/.vimrc"       "$DOTFILES_DIR/.vimrc"
remove_dotfile_symlink "$HOME/.gitconfig"   "$DOTFILES_DIR/.gitconfig"
remove_dotfile_symlink "$HOME/.npmrc"       "$DOTFILES_DIR/.npmrc"
remove_dotfile_symlink "$HOME/.tmux.conf"   "$DOTFILES_DIR/.tmux.conf"
remove_dotfile_symlink "$HOME/.config/fish/config.fish" "$DOTFILES_DIR/apps/fish/config.fish"
remove_dotfile_symlink_dir "$HOME/.config/nvim" "$DOTFILES_DIR/apps/nvim"
remove_dotfile_symlink "$HOME/.config/vagrant-templates/Vagrantfile" "$DOTFILES_DIR/ai/Vagrantfile"

# Aider files match the same loop as setup.sh — iterate the source list to
# stay in sync without hard-coding names.
for aider_file in "$DOTFILES_DIR"/.aider*; do
    if [ -f "$aider_file" ]; then
        remove_dotfile_symlink "$HOME/$(basename "$aider_file")" "$aider_file"
    fi
done

if $IS_MAC; then
    remove_dotfile_symlink "$HOME/.aerospace.toml" "$DOTFILES_DIR/.aerospace.toml"
    remove_dotfile_symlink "$HOME/Library/com.googlecode.iterm2.plist" \
        "$DOTFILES_DIR/apps/com.googlecode.iterm2.plist"

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
