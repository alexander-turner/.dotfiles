#!/bin/bash
# In-container smoke check for the dotfiles devcontainer.
#
# Source of truth for the tool list is $DOTFILES_TOOLS, set by ENV in
# .devcontainer/Dockerfile. The MCP filesystem server version is read
# from .mcp.json — the runtime config is canonical, the Dockerfile pin
# is checked against it.
#
# Invoked two ways:
#   * CI:    devcontainers/ci@v0.3 runCmd: bash .devcontainer/smoke-check.sh
#   * Local: bash bin/check-devcontainer.sh (which wraps the devcontainer CLI)

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

# The MCP filesystem server is a node package, not a $PATH binary. Read the
# canonical version from .mcp.json and assert npm has it installed globally
# — the Dockerfile's MCP_FS_VERSION ARG should match this.
mcp_pin="$(jq -r '.mcpServers.filesystem.args[] | select(startswith("@modelcontextprotocol/server-filesystem@"))' .mcp.json)"
echo "==> Asserting MCP filesystem server == $mcp_pin"
npm ls --global --depth=0 2>/dev/null | grep -F "$mcp_pin"

echo "==> Smoke check passed"
