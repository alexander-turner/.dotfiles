# Want the directory this file is in
set -l BIN_DIR (dirname (status -f))

# Local models
brew install --quiet ollama
if command -q docker
    docker pull ghcr.io/open-webui/open-webui:main 1>/dev/null
    # Run on startup (unless-stopped) -- skip if container already exists
    if not docker ps -a --format '{{.Names}}' | string match -q 'open-webui'
        docker run -d -p 3000:8080 --restart unless-stopped -v open-webui:/app/backend/data --name open-webui ghcr.io/open-webui/open-webui:main 1>/dev/null
    end
else
    echo "Warning: docker not found, skipping open-webui setup. Install OrbStack or Docker first."
end

# Set up aider
brew install --quiet aider
aider --analytics-disable --yes --exit 2>/dev/null; or true

# Set up vscodium + roo code
brew install --quiet --cask vscodium

# Refresh PATH so the newly installed codium binary is visible
source ~/.config/fish/config.fish 2>/dev/null

set -l GIT_ROOT (git rev-parse --show-toplevel)
if command -q codium
    while read -l ext
        codium --install-extension $ext 1>/dev/null 2>&1
    end < $GIT_ROOT/apps/vscodium/extensions.txt
else
    echo "Warning: codium not found on PATH, skipping extension install"
end

set CODIUM_USER "$HOME/Library/Application Support/VSCodium/User"
mkdir -p "$CODIUM_USER"

set GIT_ROOT (git rev-parse --show-toplevel)

# Force link settings.json and keybindings.json
ln -sf "$GIT_ROOT/apps/vscodium/settings.json" "$CODIUM_USER/settings.json"
ln -sf "$GIT_ROOT/apps/vscodium/keybindings.json" "$CODIUM_USER/keybindings.json"

# Start local indexing for semantic search
if command -q docker
    if not docker ps -a --format '{{.Names}}' | string match -q 'qdrant'
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
printf '- model_id: redpill-sonnet\n  model_name: anthropic/claude-sonnet-4.5\n  api_base: "https://api.redpill.ai/v1"\n' > "$LLM_DIR/extra-openai-models.yaml"
llm models default redpill-sonnet 1>/dev/null

mkdir -p $HOME/.config/prompts
cp $BIN_DIR/.system-prompt $HOME/.config/prompts/commit-system-prompt.txt

mkdir -p $HOME/.git_hooks
cp $BIN_DIR/.prepare-commit-msg $HOME/.git_hooks/prepare-commit-msg

chmod +x $HOME/.git_hooks/prepare-commit-msg
git config --global core.hooksPath ~/.git_hooks

pipx install --quiet wut 1>/dev/null # explains last output of shell command
