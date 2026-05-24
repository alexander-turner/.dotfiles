# Devcontainer for hacking on this dotfiles repo with Claude Code.
# Layer 1 of the three-layer sandbox (container isolation); Layers 2-3
# (OS-level sandbox + permission rules) come from ai/prompting/settings.json.
#
# Base image is pinned by digest so a silent retag of node:20 upstream
# doesn't change the build out from under us. Dependabot's docker
# ecosystem keeps the digest fresh; see .github/dependabot.yml.
FROM node:20@sha256:8f693eaa7e0a8e71560c9a82b55fd54c2ae920a2ba5d2cde28bac7d1c01c9ba5

ARG TZ
ENV TZ="$TZ"

RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  fzf \
  fish \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq \
  nano \
  vim \
  python3 \
  python3-pip \
  python3-venv \
  pipx \
  ripgrep \
  libcap2-bin \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/share/pnpm-global && \
  chown -R node:node /usr/local/share

ARG USERNAME=node

RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

ENV DEVCONTAINER=true

RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

WORKDIR /workspace

ARG GIT_DELTA_VERSION=0.18.2
RUN arch=$(dpkg --print-architecture) \
  && wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${arch}.deb" \
  && sudo dpkg -i "git-delta_${GIT_DELTA_VERSION}_${arch}.deb" \
  && rm "git-delta_${GIT_DELTA_VERSION}_${arch}.deb"

ENV COREPACK_HOME=/usr/local/share/corepack
RUN mkdir -p "$COREPACK_HOME" && \
  corepack enable && \
  corepack prepare pnpm@latest --activate && \
  chmod -R a+rX "$COREPACK_HOME"

USER node

ENV PNPM_HOME=/usr/local/share/pnpm-global
ENV PATH=$PATH:$PNPM_HOME
ENV NPM_CONFIG_IGNORE_SCRIPTS=true

ENV EDITOR=nano
ENV VISUAL=nano

# Install claude-code at build time.  Each CI matrix leg builds natively
# on its target arch, so the postinstall fetches the correct binary.
# Rebuild (or `pnpm add -g ...` inside the container) to change versions.
ARG CLAUDE_CODE_VERSION=latest
RUN env -u NPM_CONFIG_IGNORE_SCRIPTS pnpm add -g \
    --allow-build=@anthropic-ai/claude-code \
    "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" || \
    env -u NPM_CONFIG_IGNORE_SCRIPTS pnpm add -g \
    "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"

COPY init-firewall.bash entrypoint.bash install-claude.bash /usr/local/bin/
USER root
RUN chmod +x /usr/local/bin/init-firewall.bash /usr/local/bin/entrypoint.bash /usr/local/bin/install-claude.bash && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/entrypoint.bash" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall
USER node

# Single source of truth for the CLI binaries this image is expected to
# provide. .devcontainer/smoke-check.bash (invoked from the smoke
# workflow on every .devcontainer/** change) reads $DOTFILES_TOOLS and
# asserts every entry is on PATH — so adding an install step above
# without listing the binary here means the smoke test passes by
# accident; listing one here without an install step means it fails
# loudly. Whitespace-separated; alphabetised for diff sanity.
ENV DOTFILES_TOOLS="bash capsh claude fish fzf gh git iptables ipset jq node npm pnpm python3 rg"
