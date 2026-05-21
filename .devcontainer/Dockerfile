# Devcontainer for hacking on this dotfiles repo with Claude Code.
# Layer 1 of the three-layer sandbox (container isolation); Layers 2-3
# (OS-level sandbox + permission rules) come from ai/prompting/settings.json.
#
# Base image is pinned by digest so a silent retag of node:20 upstream
# doesn't change the build out from under us. Dependabot's docker
# ecosystem keeps the digest fresh; see .github/dependabot.yml.
FROM node:20@sha256:8f693eaa7e0a8e71560c9a82b55fd54c2ae920a2ba5d2cde28bac7d1c01c9ba5

# BuildKit auto-populates TARGETARCH per --platform target. Used below
# for the git-delta install so cross-arch builds pick the right binary.
ARG TARGETARCH

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest

RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  fzf \
  zsh \
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
  && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/share/npm-global && \
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

# git-delta — use TARGETARCH so multi-arch builds pull the right .deb.
# TARGETARCH ("amd64"/"arm64") happens to align with delta's release naming.
ARG GIT_DELTA_VERSION=0.18.2
RUN wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${TARGETARCH}.deb" \
  && sudo dpkg -i "git-delta_${GIT_DELTA_VERSION}_${TARGETARCH}.deb" \
  && rm "git-delta_${GIT_DELTA_VERSION}_${TARGETARCH}.deb"

RUN corepack enable && corepack prepare pnpm@latest --activate

USER node

ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin
ENV NPM_CONFIG_IGNORE_SCRIPTS=true

ENV SHELL=/bin/zsh
ENV EDITOR=nano
ENV VISUAL=nano

ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
  -p git \
  -p fzf \
  -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
  -a "source /usr/share/doc/fzf/examples/completion.zsh" \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  -x

RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Firewall init script. Filename was renamed .sh→.bash in #65 (script-extension
# convention); both the COPY source and the sudoers entry must match the
# actual filename, otherwise `docker build` fails at COPY.
COPY init-firewall.bash /usr/local/bin/
USER root
RUN chmod +x /usr/local/bin/init-firewall.bash && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.bash" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall
USER node

# Single source of truth for the CLI binaries this image is expected to
# provide. .devcontainer/smoke-check.bash (invoked from the smoke
# workflow on every .devcontainer/** change) reads $DOTFILES_TOOLS and
# asserts every entry is on PATH — so adding an install step above
# without listing the binary here means the smoke test passes by
# accident; listing one here without an install step means it fails
# loudly. Whitespace-separated; alphabetised for diff sanity.
ENV DOTFILES_TOOLS="bash claude fish fzf gh git iptables ipset jq node npm pnpm python3 ripgrep zsh"
