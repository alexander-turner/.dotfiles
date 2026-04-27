# Want the directory this file is in
set -l BIN_DIR (dirname (status -f))

# Local models
brew install --quiet ollama
if command -q docker
    docker pull ghcr.io/open-webui/open-webui:main 1>/dev/null
    # Run on startup (unless-stopped) -- skip if container already exists
    if not docker ps -a --format '{{.Names}}' | string match -q open-webui
        docker run -d -p 3000:8080 --restart unless-stopped -v open-webui:/app/backend/data --name open-webui ghcr.io/open-webui/open-webui:main 1>/dev/null
    end
else
    echo "Warning: docker not found, skipping open-webui setup."
end

# Set up aider
brew install --quiet aider
aider --analytics-disable --yes --exit 2>/dev/null; or true

# Set up Claude Code. pnpm is the chosen package manager for this dotfiles
# setup (user preference); install.cjs wires up the native binary shim.
if command -q pnpm
    pnpm add --global @anthropic-ai/claude-code
    set -l CLAUDE_INSTALLER (pnpm root -g)/@anthropic-ai/claude-code/install.cjs
    test -f "$CLAUDE_INSTALLER"; and node "$CLAUDE_INSTALLER"
else
    echo "Warning: pnpm not found, skipping Claude Code setup"
end

# Link Claude Code global config from this dotfiles repo
set -l DOTFILES_DIR (dirname (dirname (status -f)))
set -l SAFE_LINK $BIN_DIR/lib/safe_link.sh
mkdir -p $HOME/.claude
bash $SAFE_LINK $DOTFILES_DIR/ai/prompting/skills $HOME/.claude/commands
bash $SAFE_LINK $DOTFILES_DIR/ai/prompting/CLAUDE.md $HOME/.claude/CLAUDE.md
bash $SAFE_LINK $DOTFILES_DIR/ai/prompting/settings.json $HOME/.claude/settings.json

# Set up vscodium + roo code
brew install --quiet --cask vscodium

# Refresh PATH so the newly installed codium binary is visible
source ~/.config/fish/config.fish 2>/dev/null

set -l GIT_ROOT (git rev-parse --show-toplevel)
if command -q codium
    while read -l ext
        codium --install-extension $ext 1>/dev/null 2>&1
    end <$GIT_ROOT/apps/vscodium/extensions.txt
else
    echo "Warning: codium not found on PATH, skipping extension install"
end

switch (uname)
    case Darwin
        set CODIUM_USER "$HOME/Library/Application Support/VSCodium/User"
    case Linux
        set CODIUM_USER "$HOME/.config/VSCodium/User"
    case '*'
        echo "Warning: unsupported OS for VSCodium config, skipping"
        set CODIUM_USER ""
end

if test -n "$CODIUM_USER"
    mkdir -p "$CODIUM_USER"

    set GIT_ROOT (git rev-parse --show-toplevel)

    # Force link settings.json and keybindings.json
    ln -sf "$GIT_ROOT/apps/vscodium/settings.json" "$CODIUM_USER/settings.json"
    ln -sf "$GIT_ROOT/apps/vscodium/keybindings.json" "$CODIUM_USER/keybindings.json"
end

# Start local indexing for semantic search
if command -q docker
    if not docker ps -a --format '{{.Names}}' | string match -q qdrant
        docker run -d \
            --name qdrant \
            --restart unless-stopped \
            -p 6333:6333 \
            -v qdrant_data:/qdrant/storage \
            qdrant/qdrant 1>/dev/null
    end
end

# Automatic commit messages
# https://harper.blog/2024/03/11/use-an-llm-to-automagically-generate-meaningful-git-commit-messages/
pipx install --quiet llm 1>/dev/null
# Configure Redpill API with Sonnet for commit messages
set -l LLM_DIR (dirname (llm logs path))
mkdir -p "$LLM_DIR"
printf '- model_id: redpill-sonnet\n  model_name: anthropic/claude-sonnet-4.5\n  api_base: "https://api.redpill.ai/v1"\n' >"$LLM_DIR/extra-openai-models.yaml"
llm models default redpill-sonnet 1>/dev/null

mkdir -p $HOME/.config/prompts
cp $BIN_DIR/.system-prompt $HOME/.config/prompts/commit-system-prompt.txt

# Install prepare-commit-msg as a git template hook.
# Using init.templateDir (not core.hooksPath) so repo-local hooks still work.
# NOTE: init.templateDir is already set in the tracked .gitconfig; these commands
# only set up the hook file itself.
mkdir -p $HOME/.git_templates/hooks
cp $BIN_DIR/.prepare-commit-msg $HOME/.git_templates/hooks/prepare-commit-msg
chmod +x $HOME/.git_templates/hooks/prepare-commit-msg

# Remove core.hooksPath if previously set (it hijacks hooks for all repos)
git config --global --unset core.hooksPath 2>/dev/null; or true

pipx install --quiet wut 1>/dev/null # explains last output of shell command
