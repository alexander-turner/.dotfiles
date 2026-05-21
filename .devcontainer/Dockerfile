# Devcontainer image for hacking on this dotfiles repo with Claude Code.
# Mirrors what bin/lint.sh and bin/test-claude-hooks.sh expect locally:
# shellcheck, shfmt, gitleaks, ruff/pytest, yamllint, fish, jq, node, gh,
# stylua. Egress is restricted at first boot by init-firewall.sh.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

ARG TZ=UTC
ENV TZ="$TZ"

# System packages. iptables/ipset/dnsutils are for init-firewall.sh.
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
        nodejs \
        npm \
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

# Python tooling used by bin/lint.sh and tests/.
RUN pip3 install --no-cache-dir ruff==0.6.9 pytest==8.3.3

# gitleaks — pinned so devcontainer rebuilds are reproducible.
ARG GITLEAKS_VERSION=8.21.2
RUN curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
        | tar -xz -C /usr/local/bin gitleaks \
    && chmod +x /usr/local/bin/gitleaks

# StyLua — same source as the CI install step in .github/workflows/lint.yml.
ARG STYLUA_VERSION=2.0.2
RUN curl -fsSL -o /tmp/stylua.zip "https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/stylua-linux-x86_64.zip" \
    && unzip -q /tmp/stylua.zip -d /usr/local/bin \
    && rm /tmp/stylua.zip \
    && chmod +x /usr/local/bin/stylua

# GitHub CLI — used by setup.sh and pr-creation skill.
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod a+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Claude Code CLI + pinned MCP filesystem server (matches .mcp.json pin).
ARG MCP_FS_VERSION=2026.1.14
RUN npm install -g \
        @anthropic-ai/claude-code \
        "@modelcontextprotocol/server-filesystem@${MCP_FS_VERSION}" \
    && npm cache clean --force

# Let the firewall init script run unattended at postCreateCommand time.
RUN echo "vscode ALL=(root) NOPASSWD: /workspaces/.dotfiles/.devcontainer/init-firewall.sh" \
        > /etc/sudoers.d/init-firewall \
    && chmod 0440 /etc/sudoers.d/init-firewall

# Single source of truth for the CLI binaries this image is expected to
# provide. .devcontainer/smoke-check.sh (invoked via devcontainers/ci on
# every change under .devcontainer/) reads $DOTFILES_TOOLS and asserts
# every entry is on PATH — adding an install step above without listing
# the binary here means the smoke test passes by accident; listing one
# here without an install step means it fails loudly. Whitespace-separated;
# alphabetised for diff sanity.
ENV DOTFILES_TOOLS="bash claude fish git gh gitleaks jq npm pytest python3 ruff shellcheck shfmt stylua yamllint"

USER vscode
ENV SHELL=/usr/bin/fish
WORKDIR /workspaces
