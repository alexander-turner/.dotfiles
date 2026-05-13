# shellcheck shell=bash
# Defines safe_link(). Source this file, or run directly:
#   bash safe_link.sh <source> <target>
#
# Real files that are about to be overwritten are first moved to
# ~/.dotfiles-backup/<UTC-timestamp>/ — preserving directory structure under
# $HOME — so a misclick on the y/N prompt is recoverable.
SAFE_LINK_BACKUP_ROOT="${SAFE_LINK_BACKUP_ROOT:-$HOME/.dotfiles-backup}"

_safe_link_backup() {
    local target_file="$1"
    local stamp
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    local rel
    if [[ "$target_file" == "$HOME"/* ]]; then
        rel="${target_file#"$HOME"/}"
    else
        rel="${target_file#/}"
    fi
    local backup_path="$SAFE_LINK_BACKUP_ROOT/$stamp/$rel"
    mkdir -p "$(dirname "$backup_path")"
    mv "$target_file" "$backup_path"
    echo "  backed up to $backup_path"
}

safe_link() {
    local source_file="$1"
    local target_file="$2"
    # Already correct symlink — skip
    if [ -L "$target_file" ] && [ "$(readlink "$target_file")" = "$source_file" ]; then
        return
    fi
    # Target exists and is a real file (not a symlink) — prompt before clobbering
    if [ -e "$target_file" ] && [ ! -L "$target_file" ]; then
        read -rp "$(basename "$target_file") already exists (not a symlink). Overwrite? (y/N) " choice
        case "$choice" in
        y | Y)
            _safe_link_backup "$target_file"
            ln -sf "$source_file" "$target_file"
            ;;
        *) echo "Skipping $(basename "$target_file")" ;;
        esac
    else
        # Stale symlink (or no target) — ln -sf handles atomically
        ln -sf "$source_file" "$target_file"
    fi
}

# When executed directly, dispatch args to the function
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    set -euo pipefail
    safe_link "$@"
fi
