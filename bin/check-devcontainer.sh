#!/bin/bash
# Smoke test for .devcontainer/. Builds the image and asserts that the
# tools the Dockerfile claims to install are actually on PATH and
# executable. Catches "I edited the Dockerfile and forgot a step"
# regressions without paying for a full lint-inside-container run.
#
# Invoked from .github/workflows/devcontainer-smoke.yml on changes under
# .devcontainer/. Runnable locally with: bash bin/check-devcontainer.sh
#
# IMAGE_TAG can be overridden so CI can build once and reuse the cache.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE_TAG="${IMAGE_TAG:-dotfiles-devcontainer-smoke:${GITHUB_SHA:-local}}"

if ! command -v docker >/dev/null 2>&1; then
    echo "check-devcontainer: docker not found on PATH" >&2
    exit 1
fi

echo "==> Building .devcontainer/Dockerfile as $IMAGE_TAG"
docker build \
    --tag "$IMAGE_TAG" \
    --file "$REPO_ROOT/.devcontainer/Dockerfile" \
    "$REPO_ROOT/.devcontainer"

# Tools the Dockerfile promises. Keep this list in lockstep with the apt /
# pip / curl install steps — if the Dockerfile drops a tool, the smoke
# test should fail until this list is updated too.
EXPECTED_TOOLS=(
    bash
    fish
    git
    gh
    jq
    npm
    python3
    pytest
    ruff
    shellcheck
    shfmt
    stylua
    yamllint
    gitleaks
    claude
)

echo "==> Asserting tools on PATH"
docker run --rm \
    --entrypoint /bin/bash \
    "$IMAGE_TAG" \
    -c "$(
        printf 'set -euo pipefail\nfor cmd in %s; do\n  if ! command -v "$cmd" >/dev/null 2>&1; then\n    echo "missing: $cmd" >&2; exit 1\n  fi\ndone\necho "all %d tools present"\n' \
            "${EXPECTED_TOOLS[*]}" "${#EXPECTED_TOOLS[@]}"
    )"

# The MCP filesystem server is a node package, not a $PATH binary — assert
# it's installed at the version .mcp.json pins. Keeps the Dockerfile's
# MCP_FS_VERSION ARG honest.
PINNED_MCP="$(jq -r '.mcpServers.filesystem.args[] | select(startswith("@modelcontextprotocol/server-filesystem@"))' "$REPO_ROOT/.mcp.json")"
echo "==> Asserting MCP filesystem server == $PINNED_MCP"
docker run --rm \
    --entrypoint /bin/bash \
    "$IMAGE_TAG" \
    -c "npm ls --global --depth=0 2>/dev/null | grep -F '$PINNED_MCP'"

echo "==> Smoke test passed"
