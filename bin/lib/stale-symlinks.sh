# shellcheck shell=bash
# Emits "<entry>|<broken-target>" lines for symlinks in a managed parent dir
# that point into $DOTFILES_DIR with a missing target — the rename-leftover
# signature.
#
# Caller contract: $DOTFILES_DIR is set, and bin/lib/symlinks.sh has been
# sourced (managed_symlinks is callable).

stale_symlinks() {
    local managed_targets="" managed_parents=""
    while IFS='|' read -r target _ _; do
        managed_targets+="$target"$'\n'
        managed_parents+="$(dirname "$target")"$'\n'
    done < <(managed_symlinks)
    local unique_parents
    unique_parents="$(printf '%s' "$managed_parents" | sort -u)"

    while IFS= read -r parent; do
        [[ -z "$parent" || ! -d "$parent" ]] && continue
        while IFS= read -r -d '' entry; do
            if printf '%s' "$managed_targets" | grep -Fxq "$entry"; then
                continue
            fi
            local link_target
            link_target="$(readlink "$entry")"
            [[ "$link_target" == "$DOTFILES_DIR"/* ]] || continue
            [[ -e "$link_target" ]] && continue
            printf '%s|%s\n' "$entry" "$link_target"
        done < <(find "$parent" -maxdepth 1 -type l -print0 2>/dev/null)
    done < <(printf '%s' "$unique_parents")
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    set -euo pipefail
    : "${DOTFILES_DIR:=$(cd "$(dirname "$0")/../.." && pwd)}"
    # shellcheck source=symlinks.sh disable=SC1091
    source "$DOTFILES_DIR/bin/lib/symlinks.sh"
    stale_symlinks
fi
