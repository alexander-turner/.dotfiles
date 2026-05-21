# Devcontainer image for hacking on this dotfiles repo with Claude Code.
# Mirrors what bin/lint.bash and tests/test_claude_hooks.py expect locally:
# shellcheck, shfmt, gitleaks, ruff/pytest, yamllint, fish, jq, node,
# stylua. The gh CLI is installed by the devcontainer feature
# `github-cli` declared in devcontainer.json — not by this Dockerfile.
# Egress is restricted at first boot by init-firewall.bash.
#
# Base image is pinned by digest (multi-arch index) so the build is
# reproducible across rebuilds even when MS retags ubuntu-22.04 upstream.
# Dependabot's docker ecosystem can keep the digest fresh — see
# .github/dependabot.yml.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04@sha256:81380e4c9c14e8a629ff39029639e4b7893e67400246fa7782a0fe7dc193a02a

# BuildKit auto-populates TARGETARCH ("amd64" or "arm64") per target
# platform when building with `docker buildx build --platform=...`. The
# devcontainers/ci action wires this through automatically.
ARG TARGETARCH

ARG TZ=UTC
ENV TZ="$TZ"

# System packages. iptables/ipset/dnsutils are for init-firewall.bash.
# Node.js is NOT here — Ubuntu 22.04's apt nodejs is 12.x which can't
# parse Claude Code's install script (optional-chaining is Node 14+).
# See the NodeSource step further down.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        dnsutils \
        fish \
        git \
        gnupg \
        iproute2 \
        ipset \
        iptables \
        jq \
        less \
        make \
        python3 \
        python3-pip \
        python3-venv \
        shellcheck \
        shfmt \
        sudo \
        tmux \
        unzip \
        vim \
        yamllint \
    && rm -rf /var/lib/apt/lists/*

# Python tooling used by bin/lint.bash and tests/.
RUN pip3 install --no-cache-dir ruff==0.6.9 pytest==8.3.3

# gitleaks + stylua — pinned versions, multi-arch. Arch mapping (amd64 →
# x64/x86_64, arm64 → arm64/aarch64) lives in install-vendor-binaries.bash
# so a new target arch only needs editing one file.
ARG GITLEAKS_VERSION=8.21.2
ARG STYLUA_VERSION=2.0.2
COPY install-vendor-binaries.bash /tmp/install-vendor-binaries.bash
RUN GITLEAKS_VERSION="$GITLEAKS_VERSION" STYLUA_VERSION="$STYLUA_VERSION" \
    TARGETARCH="$TARGETARCH" \
    bash /tmp/install-vendor-binaries.bash \
    && rm /tmp/install-vendor-binaries.bash

# Node.js via NodeSource. apt's default `nodejs` package on 22.04 is 12.x,
# which can't parse Claude Code's install.cjs (uses `?.`). Pinning the
# major here so the install is reproducible across rebuilds.
ARG NODE_MAJOR=20
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Claude Code CLI. The MCP filesystem server is NOT pre-installed:
# `.mcp.json` is the single source of truth for the MCP package + version,
# and `npx --yes` fetches it on first MCP use (the firewall allowlist
# permits registry.npmjs.org, so the cold-start fetch works after lockdown).
RUN npm install -g @anthropic-ai/claude-code \
    && npm cache clean --force

# Let the firewall init script run unattended at postCreateCommand time.
RUN echo "vscode ALL=(root) NOPASSWD: /workspaces/.dotfiles/.devcontainer/init-firewall.bash" \
        > /etc/sudoers.d/init-firewall \
    && chmod 0440 /etc/sudoers.d/init-firewall

# Single source of truth for the CLI binaries this image is expected to
# provide. .devcontainer/smoke-check.bash (invoked via devcontainers/ci on
# every change under .devcontainer/) reads $DOTFILES_TOOLS and asserts
# every entry is on PATH — adding an install step above without listing
# the binary here means the smoke test passes by accident; listing one
# here without an install step means it fails loudly. Whitespace-separated;
# alphabetised for diff sanity. `gh` comes from the github-cli devcontainer
# feature, not this Dockerfile — features apply on top of this image.
ENV DOTFILES_TOOLS="bash claude fish git gh gitleaks jq npm pytest python3 ruff shellcheck shfmt stylua yamllint"

USER vscode
ENV SHELL=/usr/bin/fish
WORKDIR /workspaces
