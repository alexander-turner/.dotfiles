# Defines safe_link(). Source this file, or run directly:
#   bash safe_link.sh <source> <target>
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
        y | Y) ln -sf "$source_file" "$target_file" ;;
        *) echo "Skipping $(basename "$target_file")" ;;
        esac
    else
        ln -sf "$source_file" "$target_file"
    fi
}

# When executed directly, dispatch args to the function
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    set -euo pipefail
    safe_link "$@"
fi
