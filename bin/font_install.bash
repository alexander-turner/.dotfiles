#!/bin/bash
set -euo pipefail

echo ":: Installing fonts..."

if [ "$(uname)" = "Darwin" ]; then
    # All three fonts ship as casks in the main homebrew/cask tap
    # (homebrew/cask-font is deprecated). font-meslo-lg-nerd-font provides
    # the MesloLGS NF glyphs Tide uses for non-ASCII prompt characters.
    brew install --quiet --cask font-fira-code font-meslo-lg-nerd-font font-eb-garamond
else
    # Linux: only MesloLGS NF is needed (Fira Code / Garamond aren't bundled
    # for Linux dev boxes). Pull from the Tide assets branch.
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    PREFIX="https://github.com/IlanCosman/tide/blob/assets/fonts/mesloLGS_NF_"
    SUFFIX=".ttf?raw=true"
    for variant in regular bold italic bold_italic; do
        if ! wget -q "$PREFIX$variant$SUFFIX" -O "$FONT_DIR/$variant.ttf"; then
            echo "Warning: failed to download $variant font" >&2
        fi
    done
fi

echo -e "\033[1;31m Be sure to install the fira-code and Meslo fonts for your terminal of choice!\033[0m"
