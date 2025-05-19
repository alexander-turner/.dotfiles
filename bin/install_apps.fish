#!/usr/bin/env fish

if test (uname -s) != Darwin
    echo "Error: This script requires macOS." >&2
    exit 1
end

# Check for brew and install if missing
if not type -q brew
    echo "Homebrew not found. Installing..."
    set -l BREW_INSTALL_URL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
    /bin/bash -c "$(curl -fsSL $BREW_INSTALL_URL)" || exit 2
    echo "Homebrew installation attempted. You might need to restart your shell or add brew to your PATH."
else
    echo "Homebrew is already installed."
end

# Tap necessary sources
brew tap yakitrak/yakitrak

# Install apps apps 
set -l GIT_ROOT (git rev-parse --show-toplevel 2>/dev/null)
cd $GIT_ROOT
cat ./apps/mac_brew.txt | xargs brew install

# Install pip apps
pipx install gsutil # google cloud bucket backups

exit 0
