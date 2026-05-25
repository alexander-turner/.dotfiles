#!/bin/bash
# setup_llm.bash — installer for the AI/LLM tooling layer: claude-code +
# ccr (pnpm), aider (uv), VSCodium + extensions, wut-cli (uv), llm +
# commit-message git template hook. Idempotent.

set -euo pipefail

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

status_msg() {
    echo ":: $1"
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IS_MAC=false
[[ "$(uname)" == "Darwin" ]] && IS_MAC=true

# ── claude-code + claude-code-router (ccr) ──────────────────────────────────
# pnpm keeps both under $PNPM_HOME, matching the path baked into
# secure-claude-code-defaults/launchagents/com.turntrout.ccr.plist.
if command_exists pnpm; then
    status_msg "Installing claude-code + claude-code-router via pnpm..."
    pnpm add --global --reporter=append-only @anthropic-ai/claude-code @musistudio/claude-code-router

    CLAUDE_INSTALLER="$(pnpm root -g)/@anthropic-ai/claude-code/install.cjs"
    if [[ -f "$CLAUDE_INSTALLER" ]] && command_exists node; then
        node "$CLAUDE_INSTALLER" || true
    fi
else
    status_msg "WARN: pnpm not found — skipping claude-code + ccr install"
fi

# ── aider ───────────────────────────────────────────────────────────────────
if command_exists uv; then
    if ! command_exists aider; then
        status_msg "Installing aider-chat via uv..."
        uv tool install --quiet aider-chat
    fi
    # Disable analytics before first interactive invocation prompts for it.
    aider --analytics-disable --yes --exit >/dev/null 2>&1 || true
fi

# ── VSCodium + extensions ───────────────────────────────────────────────────
# extensions.txt is the source of truth — add/remove there.
if $IS_MAC && command_exists brew; then
    brew install --quiet --cask vscodium 2>/dev/null || true
fi

if command_exists codium; then
    status_msg "Installing VSCodium extensions..."
    while IFS= read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        codium --install-extension "$ext" >/dev/null 2>&1 || true
    done <"$DOTFILES_DIR/apps/vscodium/extensions.txt"
fi

# ── wut-cli ─────────────────────────────────────────────────────────────────
if command_exists uv && ! command_exists wut; then
    status_msg "Installing wut-cli via uv..."
    uv tool install --quiet wut-cli
fi

# ── Venice default_code resolver cache ──────────────────────────────────────
# Refresh the cached model id that claude-private / claude-paranoid read
# from. Falls back internally if the API is unreachable.
# shellcheck source=../secure-claude-code-defaults/bin/lib/venice-resolve.bash disable=SC1091
source "$DOTFILES_DIR/secure-claude-code-defaults/bin/lib/venice-resolve.bash"
status_msg "Resolving Venice default_code model..."
cache_venice_trait default_code "$VENICE_DEFAULT_CODE_FALLBACK"

# ── llm CLI (ad-hoc shell prompts; unrelated to the commit-msg hook) ────────
if command_exists uv && ! command_exists llm; then
    status_msg "Installing llm via uv..."
    uv tool install --quiet llm
fi

if command_exists llm; then
    LLM_DIR="$(dirname "$(llm logs path)")"
    mkdir -p "$LLM_DIR"
    cat >"$LLM_DIR/extra-openai-models.yaml" <<'YAML'
- model_id: redpill-sonnet
  model_name: anthropic/claude-sonnet-4.5
  api_base: "https://api.redpill.ai/v1"
YAML
    llm models default redpill-sonnet >/dev/null 2>&1 || true
fi

# ── prepare-commit-msg template hook (Venice/qwen3-coder-480b via `mods`) ──
# Installed as a template hook (init.templateDir) so new repos pick it up at
# clone/init time. Repos that override core.hooksPath (e.g. this dotfiles
# repo's .hooks/) need a per-repo symlink — see setup.bash.
mkdir -p "$HOME/.config/prompts" "$HOME/.git_templates/hooks"
install -m 0644 "$DOTFILES_DIR/bin/.system-prompt" \
    "$HOME/.config/prompts/commit-system-prompt.txt"
install -m 0755 "$DOTFILES_DIR/bin/.prepare-commit-msg" \
    "$HOME/.git_templates/hooks/prepare-commit-msg"

git config --global --unset core.hooksPath 2>/dev/null || true
