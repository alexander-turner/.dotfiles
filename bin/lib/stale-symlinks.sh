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

# Remove every rename-leftover symlink stale_symlinks() reports, printing one
# line per removal. setup.bash calls this (via `--prune` below) so a full
# reconcile — create managed links + prune leftovers — happens in one pass,
# instead of leaving the cleanup to doctor.bash's interactive prompt.
#
# Safe-by-construction: stale_symlinks() only ever emits *symlinks whose target
# is missing*, so there is no user data to back up the way safe_link does — the
# link is already broken. Idempotent: a second run finds nothing to remove.
prune_stale_symlinks() {
    while IFS='|' read -r entry _; do
        if rm -f "$entry"; then
            printf "  removed stale symlink %s\n" "$entry"
        else
            printf "  WARN: could not remove stale symlink %s\n" "$entry" >&2
        fi
    done < <(stale_symlinks)
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    set -euo pipefail
    : "${DOTFILES_DIR:=$(cd "$(dirname "$0")/../.." && pwd)}"
    # shellcheck source=symlinks.sh disable=SC1091
    source "$DOTFILES_DIR/bin/lib/symlinks.sh"
    case "${1:-}" in
    --prune) prune_stale_symlinks ;;
    "") stale_symlinks ;;
    *)
        printf "usage: %s [--prune]\n" "$(basename "$0")" >&2
        exit 2
        ;;
    esac
fi
