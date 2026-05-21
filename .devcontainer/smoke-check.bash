#!/bin/bash
# In-container smoke check for the dotfiles devcontainer.
#
# Source of truth for the tool list is $DOTFILES_TOOLS, set by ENV in
# .devcontainer/Dockerfile. The MCP filesystem server is NOT pre-installed
# (it's `npx --yes`'d from .mcp.json on first use), so the only MCP pin
# lives in .mcp.json — nothing to assert here.
#
# Invoked two ways:
#   * CI:    devcontainers/ci@v0.3 runCmd: bash .devcontainer/smoke-check.bash
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

echo "==> Smoke check passed"
