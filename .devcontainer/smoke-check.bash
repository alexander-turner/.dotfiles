#!/bin/bash
# In-container smoke check for the dotfiles devcontainer.
#
# Source of truth for the tool list is $DOTFILES_TOOLS, set by ENV in
# .devcontainer/Dockerfile. Invoked two ways:
#   * CI:    devcontainers/ci runCmd: bash .devcontainer/smoke-check.bash
#   * Local: bash bin/check-devcontainer.bash (which wraps the devcontainer CLI)

set -euo pipefail

: "${DOTFILES_TOOLS:?ENV DOTFILES_TOOLS not set — re-check .devcontainer/Dockerfile}"

echo "==> Asserting tools on PATH: $DOTFILES_TOOLS"
missing=0
for cmd in $DOTFILES_TOOLS; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "missing: $cmd" >&2
        missing=$((missing + 1))
    fi
done
[[ $missing -eq 0 ]]

# Also assert init-firewall.bash exists at the install path the
# devcontainer.json's postStartCommand references — guards against the
# COPY/CMD path drifting from the actual filename again.
test -x /usr/local/bin/init-firewall.bash

echo "==> Smoke check passed"
