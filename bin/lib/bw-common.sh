# Shared helpers for the bw-* scripts in this directory. Source from a
# script via:
#
#     DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
#     source "$DOTFILES_DIR/bin/lib/bw-common.sh"
#
# All functions return non-zero on failure. Callers should `|| exit` after
# each call (or rely on `set -e`).

# shellcheck source=bin/lib/secret-store.sh disable=SC1091
source "${BASH_SOURCE[0]%/*}/secret-store.sh"

# Verify the required external commands are on PATH. Usage:
#   bw_require_cmds bw jq envchain security
# Empty arguments are skipped — callers can splice in
# `$(secret_store_required_cmd)`, which is empty when the file backend is
# in use (no external command needed).
bw_require_cmds() {
    local missing=()
    local cmd
    for cmd in "$@"; do
        [ -z "$cmd" ] && continue
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Missing required commands: ${missing[*]}" >&2
        return 1
    fi
}

# Return 0 if bw has any session at all (locked or unlocked), 1 otherwise.
bw_is_logged_in() {
    bw status --raw 2>/dev/null | grep -qE '"status":"(locked|unlocked)"'
}

# Exit-style guard: errors out if not logged in.
bw_require_logged_in() {
    if ! bw_is_logged_in; then
        echo "bw: not logged in. Run bin/bw-login.sh first." >&2
        return 1
    fi
}

# Ensure $BW_SESSION is exported, unlocking via the master password cached
# in the OS secret store (service `bw-master-password`, see
# bin/lib/secret-store.sh) if needed. We use `--passwordenv` rather than
# stdin to dodge a bw/inquirer bug on newer Node versions. The env var is
# scoped to the bw subprocess only.
bw_ensure_session() {
    if [ -n "${BW_SESSION:-}" ]; then
        export BW_SESSION
        return 0
    fi
    local mp
    mp=$(secret_get bw-master-password)
    if [ -z "${mp:-}" ]; then
        echo "bw: locked and no cached master password. Run bin/bw-login.sh." >&2
        return 1
    fi
    BW_SESSION=$(BW_PASSWORD="$mp" bw unlock --raw --passwordenv BW_PASSWORD 2>/dev/null) || {
        echo "bw unlock: cached master password rejected. Re-run bin/bw-login.sh." >&2
        unset mp
        return 1
    }
    unset mp
    export BW_SESSION
}

# Echo the id of the `envchain` folder. If $1 == "--create", create it
# when missing; otherwise return 1 with a message if missing.
bw_envchain_folder_id() {
    local fid
    fid=$(bw list folders --session "$BW_SESSION" \
        | jq -r '.[] | select(.name=="envchain") | .id' | head -n1)
    if [ -n "$fid" ]; then
        printf '%s\n' "$fid"
        return 0
    fi
    if [ "${1:-}" != "--create" ]; then
        echo "No 'envchain' folder in vault." >&2
        return 1
    fi
    bw get template folder \
        | jq '.name="envchain"' \
        | bw encode \
        | bw create folder --session "$BW_SESSION" \
        | jq -r '.id'
}

# Return 0 if an item with the given name exists in the given folder.
bw_item_exists() {
    local folder_id="$1" name="$2"
    bw list items --folderid "$folder_id" --session "$BW_SESSION" \
        | jq -e --arg n "$name" '.[] | select(.name==$n)' >/dev/null
}
