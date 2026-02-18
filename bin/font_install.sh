#!/bin/bash

echo ":: Installing fonts..."

# Fira Code is the terminal font, has nice ligatures
brew tap homebrew/cask-font >/dev/null
brew install --quiet --cask font-fira-code

# Download Meslo Nerd Font for non-ASCII Tide theme characters
PREFIX="https://github.com/IlanCosman/tide/blob/assets/fonts/mesloLGS_NF_"
SUFFIX=".ttf?raw=true"
fonts=("regular" "bold" "italic" "bold_italic")

# Determine font directory by platform
if [ "$(uname)" = "Darwin" ]; then
    FONT_DIR="$HOME/Library/Fonts"
else
    FONT_DIR="$HOME/.local/share/fonts"
fi
mkdir -p "$FONT_DIR"

for font in "${fonts[@]}"; do
	url="$PREFIX$font$SUFFIX"
	if ! wget -q "$url" -O "$FONT_DIR/$font.ttf"; then
		echo "Warning: failed to download $font font" >&2
	fi
done

echo -e "\033[1;31m Be sure to install the fira-code and Meslo fonts for your terminal of choice!\033[0m"

# Install Garamond for Obsidian
brew install --quiet --cask font-eb-garamond
