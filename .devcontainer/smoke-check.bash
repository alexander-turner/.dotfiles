#!/bin/bash
# In-container smoke check for the dotfiles devcontainer.
#
# Source of truth for the tool list is $DOTFILES_TOOLS, set by ENV in
# .devcontainer/Dockerfile. Invoked two ways:
#   * CI:    devcontainers/ci runCmd: bash .devcontainer/smoke-check.bash
#   * Local: bash bin/check-devcontainer.bash (which wraps the devcontainer CLI)

set -uo pipefail

# Diagnostic preamble so a CI failure here is debuggable from the
# workflow log without re-running. devcontainers/ci surfaces stdout
# in its annotation, so we lean on echo (not stderr).
echo "==> whoami=$(id -un) cwd=$PWD"
echo "==> PATH=$PATH"
echo "==> DOTFILES_TOOLS='${DOTFILES_TOOLS:-<UNSET>}'"

if [[ -z "${DOTFILES_TOOLS:-}" ]]; then
    echo "FAIL: ENV DOTFILES_TOOLS not set — re-check .devcontainer/Dockerfile"
    exit 1
fi

missing=()
for cmd in $DOTFILES_TOOLS; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing+=("$cmd")
    fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "FAIL: missing on PATH: ${missing[*]}"
    exit 1
fi

# Assert init-firewall.bash exists at the install path the
# devcontainer.json's postStartCommand references — guards against the
# COPY/CMD path drifting from the actual filename.
if ! test -x /usr/local/bin/init-firewall.bash; then
    echo "FAIL: /usr/local/bin/init-firewall.bash not executable (path drift in Dockerfile COPY?)"
    ls -la /usr/local/bin/init-firewall* 2>&1 || true
    exit 1
fi

echo "==> Smoke check passed: ${#missing[@]} missing, init-firewall.bash present"
