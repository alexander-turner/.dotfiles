#!/bin/bash
# Multi-arch installer for vendored binaries (gitleaks, stylua).
# Called once from the Dockerfile with TARGETARCH supplied by BuildKit
# and pinned versions in env — keeps the arch mapping in one place so a
# new arch only needs editing here, and the Dockerfile stays short.

set -euo pipefail

: "${TARGETARCH:?must be set by Dockerfile build}"
: "${GITLEAKS_VERSION:?must be set by Dockerfile build}"
: "${STYLUA_VERSION:?must be set by Dockerfile build}"

case "$TARGETARCH" in
amd64) gl_arch=x64 st_arch=x86_64 ;;
arm64) gl_arch=arm64 st_arch=aarch64 ;;
*) echo "Unsupported TARGETARCH: $TARGETARCH" >&2 && exit 1 ;;
esac

curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${gl_arch}.tar.gz" |
    tar -xz -C /usr/local/bin gitleaks
chmod +x /usr/local/bin/gitleaks

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
curl -fsSL -o "$tmpdir/stylua.zip" \
    "https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/stylua-linux-${st_arch}.zip"
unzip -q "$tmpdir/stylua.zip" -d /usr/local/bin
chmod +x /usr/local/bin/stylua
