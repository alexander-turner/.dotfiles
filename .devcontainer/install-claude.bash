#!/bin/bash
# Install claude-code globally via pnpm.
#
# Unsets NPM_CONFIG_IGNORE_SCRIPTS (set by the Dockerfile for general
# safety) so the postinstall that fetches the arch-specific native
# binary can run.  Uses --allow-build (pnpm ≥10) with a fallback for
# pnpm 9 where that flag doesn't exist.
set -euo pipefail

echo "==> pnpm $(pnpm --version), node $(node --version), user=$(id -un)"
echo "==> PNPM_HOME=${PNPM_HOME:-<unset>}"
echo "==> CLAUDE_CODE_VERSION=${CLAUDE_CODE_VERSION:-<unset>}"

unset NPM_CONFIG_IGNORE_SCRIPTS

version="${CLAUDE_CODE_VERSION:-latest}"

if pnpm add -g --allow-build=@anthropic-ai/claude-code "@anthropic-ai/claude-code@${version}"; then
    echo "==> Installed with --allow-build"
else
    echo "==> --allow-build failed (pnpm <10?), retrying without it"
    pnpm add -g "@anthropic-ai/claude-code@${version}"
fi
