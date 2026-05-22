#!/bin/bash
# Flag .sh files whose shebang requires bash — the convention is .bash for
# bash-specific scripts so /bin/sh on macOS (POSIX-mode bash 3.2) doesn't
# silently get handed a script that uses arrays, [[, etc. Pure-POSIX .sh
# files (#!/bin/sh) and sourced libs in bin/lib/ (no shebang) are fine.
#
# Invoked as a pre-commit local hook (.pre-commit-config.yaml); files to
# check come in via "$@".
set -euo pipefail

offenders=()
for f in "$@"; do
    IFS= read -r first <"$f" || true
    if [[ "$first" == "#!/bin/bash"* || "$first" == "#!/usr/bin/env bash"* ]]; then
        offenders+=("$f")
    fi
done

if [ "${#offenders[@]}" -ne 0 ]; then
    for o in "${offenders[@]}"; do
        echo "  $o uses a bash shebang — rename to .bash" >&2
    done
    exit 1
fi
