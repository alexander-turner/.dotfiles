#!/bin/bash
# setup_llm.bash — install + configure the AI/LLM tooling layer.
#
# Restored from the deleted bin/setup_llm.fish (commit c69b7bb removed it
# alongside the Ollama/Open-WebUI stack but also took out claude-code, ccr,
# aider, VSCodium+Roo, wut, and the llm-based commit-message hook — none of
# which were meant to be deleted).
#
# Idempotent: each install step checks for the binary or installs via a
# package manager that no-ops on already-installed.
#
# Scope:
#   * claude-code + claude-code-router (ccr) via pnpm
#   * aider (uv)
#   * VSCodium + extensions from apps/vscodium/extensions.txt
#   * wut-cli (uv)
#   * llm + commit-message git template hook (uv + cp)
#
# Out of scope (intentionally not restored):
#   * Ollama / Open-WebUI — moved off-device to the home server
#   * qdrant docker container — Roo semantic-search infra, only restore
#     if you actually use it

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
# Both via pnpm so they live under $PNPM_HOME (matches the path baked into
# launchagents/com.turntrout.ccr.plist). install.cjs wires up the native
# binary shim that the host-side bin/claude wrapper expects to exec.
if command_exists pnpm; then
    status_msg "Installing claude-code + claude-code-router via pnpm..."
    pnpm add --global @anthropic-ai/claude-code @musistudio/claude-code-router >/dev/null

    CLAUDE_INSTALLER="$(pnpm root -g)/@anthropic-ai/claude-code/install.cjs"
    if [[ -f "$CLAUDE_INSTALLER" ]] && command_exists node; then
        node "$CLAUDE_INSTALLER" >/dev/null 2>&1 || true
    fi
else
    status_msg "WARN: pnpm not found — skipping claude-code + ccr install"
fi

# ── aider ───────────────────────────────────────────────────────────────────
# Routed through Redpill at runtime via apps/fish/config.fish's
# aider_redpill function + bin/aider-redpill-shim.sh.
if command_exists uv; then
    if ! command_exists aider; then
        status_msg "Installing aider-chat via uv..."
        uv tool install --quiet aider-chat
    fi
    # First-run housekeeping: silently disable analytics so aider doesn't
    # prompt on the first real invocation. The exit-after-init is intentional.
    aider --analytics-disable --yes --exit >/dev/null 2>&1 || true
fi

# ── VSCodium + extensions ───────────────────────────────────────────────────
# Roo Cline (rooveterinaryinc.roo-cline) is the privacy-first AI pair
# programmer that complements the Venice-routed ccr setup. extensions.txt
# is the source of truth — add/remove there.
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
# Explains the last shell output — referenced from README #10.
if command_exists uv && ! command_exists wut; then
    status_msg "Installing wut-cli via uv..."
    uv tool install --quiet wut-cli
fi

# ── llm + auto commit-message hook ──────────────────────────────────────────
# Auto-generated commit messages via Simon Willison's `llm`, configured
# against Redpill's OpenAI-compatible endpoint (sonnet model).
# bin/.prepare-commit-msg pipes `git diff --cached` through llm with the
# system prompt in bin/.system-prompt. Installed as a *template* hook
# (init.templateDir) rather than core.hooksPath so repo-local hooks still
# work. Note: this predates the Venice-only policy in CLAUDE.md — it's
# existing tooling, not a new wrapper.
if command_exists uv; then
    if ! command_exists llm; then
        status_msg "Installing llm via uv..."
        uv tool install --quiet llm
    fi

    # llm reads model defs from <logs path>/extra-openai-models.yaml. Write
    # only if missing or different so re-runs don't churn the file mtime.
    if command_exists llm; then
        LLM_DIR="$(dirname "$(llm logs path)")"
        mkdir -p "$LLM_DIR"
        LLM_MODELS_YAML="$LLM_DIR/extra-openai-models.yaml"
        EXPECTED_MODELS_YAML='- model_id: redpill-sonnet
  model_name: anthropic/claude-sonnet-4.5
  api_base: "https://api.redpill.ai/v1"'
        if [[ ! -f "$LLM_MODELS_YAML" ]] || ! diff -q <(printf '%s\n' "$EXPECTED_MODELS_YAML") "$LLM_MODELS_YAML" >/dev/null 2>&1; then
            printf '%s\n' "$EXPECTED_MODELS_YAML" >"$LLM_MODELS_YAML"
        fi
        llm models default redpill-sonnet >/dev/null 2>&1 || true
    fi

    # Commit-message template hook + system prompt. Template hooks live in
    # init.templateDir (set in .gitconfig); we just drop the files into place.
    mkdir -p "$HOME/.config/prompts" "$HOME/.git_templates/hooks"
    install -m 0644 "$DOTFILES_DIR/bin/.system-prompt" \
        "$HOME/.config/prompts/commit-system-prompt.txt"
    install -m 0755 "$DOTFILES_DIR/bin/.prepare-commit-msg" \
        "$HOME/.git_templates/hooks/prepare-commit-msg"

    # core.hooksPath hijacks hooks for *all* repos, fighting the per-repo
    # hook story. Unset if a previous install set it. `|| true` because the
    # config key may not be set (which is the desired state).
    git config --global --unset core.hooksPath 2>/dev/null || true
fi
