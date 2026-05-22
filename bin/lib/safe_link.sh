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
    # One timestamp per shell session so all backups from a single setup.bash run
    # land in the same directory. uninstall.bash's "restore from latest" then finds
    # every file that was backed up together, not just the last one.
    if [[ -z "${SAFE_LINK_BACKUP_STAMP:-}" ]]; then
        SAFE_LINK_BACKUP_STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
        export SAFE_LINK_BACKUP_STAMP
    fi
    local rel
    if [[ "$target_file" == "$HOME"/* ]]; then
        rel="${target_file#"$HOME"/}"
    else
        rel="${target_file#/}"
    fi
    local backup_path="$SAFE_LINK_BACKUP_ROOT/$SAFE_LINK_BACKUP_STAMP/$rel"
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
        # Prompt via /dev/tty rather than stdin: setup.bash drives this loop
        # body with stdin tied to a pipe (`done < <(managed_symlinks)`), so a
        # `-t 0` check would always claim non-interactive. Open /dev/tty for
        # real (not `-r`/`-w`, which only stat the device node and pass even
        # without a controlling terminal) — open fails ENXIO under CI /
        # setsid / sandboxed children, and we skip silently then.
        if ! exec 3<>/dev/tty 2>/dev/null; then
            echo "Skipping $(basename "$target_file") (real file present, non-interactive)"
            return 0
        fi
        local choice=""
        printf '%s already exists (not a symlink). Overwrite? (y/N) ' "$(basename "$target_file")" >&3
        read -r choice <&3 || true
        exec 3<&-
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
