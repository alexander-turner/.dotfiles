#!/bin/bash

# Check if conda is installed
if command -v conda >/dev/null; then
    echo "Conda is already installed."
else
    echo "Conda not found. Installing Miniconda..."

    # Determine the appropriate Miniconda installer based on the system
    if [ "$(uname)" == "Darwin" ]; then
        miniconda_installer="Miniconda3-latest-MacOSX-x86_64.sh"
    elif [ "$(uname)" == "Linux" ]; then
        miniconda_installer="Miniconda3-latest-Linux-x86_64.sh"
    else
        echo "Unsupported platform. Exiting."
        exit 1
    fi

    # Download and run the Miniconda installer
    wget "https://repo.anaconda.com/miniconda/$miniconda_installer"
    chmod +x "$miniconda_installer"
    ./"$miniconda_installer" -b

    # Remove the Miniconda installer
    rm "$miniconda_installer"

    # Add conda to the system's PATH
    if [ "$(uname)" == "Darwin" ]; then
        export PATH="$HOME/miniconda3/bin:$PATH"
        echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.bash_profile
    elif [ "$(uname)" == "Linux" ]; then
        export PATH="$HOME/miniconda3/bin:$PATH"
        echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.bashrc
    fi

    # Initialize conda
    conda init

    echo "Miniconda installation is complete."
fi
