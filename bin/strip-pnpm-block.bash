#!/usr/bin/env bash
set -euo pipefail

fixed=false
for f in "$@"; do
    if grep -q '^# pnpm$' "$f"; then
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' '/^# pnpm$/,/^# pnpm end$/d' "$f"
        else
            sed -i '/^# pnpm$/,/^# pnpm end$/d' "$f"
        fi
        printf 'stripped pnpm block from %s\n' "$f" >&2
        fixed=true
    fi
done
if $fixed; then
    exit 1
fi
