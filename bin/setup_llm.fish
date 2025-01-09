# Want the directory this file is in
set -l BIN_DIR (dirname (status -f))

# Install AI coding assistant
echo "Installing AI coding assistant"
python3 -m pip install --quiet aider-chat

# Automatic commit messages
# https://harper.blog/2024/03/11/use-an-llm-to-automagically-generate-meaningful-git-commit-messages/
pipx install --quiet llm
llm install llm-gemini # must run `llm keys set gemini` before use
llm models default gemini-1.5-pro-latest

mkdir -p $HOME/.config/prompts
cp $BIN_DIR/.system-prompt.txt $HOME/.config/prompts/commit-system-prompt.txt

mkdir -p $HOME/.git_hooks
cp $BIN_DIR/.prepare-commit-msg $HOME/.git_hooks/prepare-commit-msg

chmod +x $HOME/.git_hooks/prepare-commit-msg
git config --global core.hooksPath ~/.git_hooks

pipx install wut # explains last output of shell command
