#/bin/bash

# Fira Code is the terminal font, has nice ligatures
brew tap homebrew/cask-font
brew install --cask font-fira-code

# Download Meslo Nerd Font for non-ASCII Tide theme characters
PREFIX="https://github.com/IlanCosman/tide/blob/assets/fonts/mesloLGS_NF_"
SUFFIX=".ttf?raw=true"
fonts=("regular" "bold" "italic" "bold_italic")

for font in "${fonts[@]}"; do
	url="$PREFIX$font$SUFFIX"
	wget "$url" -O ~/Library/Fonts/"$font".ttf
done

echo -e "\033[1;31m Be sure to install the fira-code and Meslo fonts for your terminal of choice!\033[0m"

# Install Garamond for Obsidian
brew install --cask font-eb-garamond

echo "Font installation complete."
