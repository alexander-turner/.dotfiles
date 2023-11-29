#!/bin/bash

# Setup wandb API key (maybe auto-scp it after ssh'ing into a new server? and then read from that file)
#  NOTE Check ~/.netrc

DOTFILES_REPO_URL="git@github.com:alexander-turner/.dotfiles.git"

# Clone your dotfiles repository to the home directory
if [ ! -d ~/.dotfiles ]; then 
  git clone "$DOTFILES_REPO_URL" ~/.dotfiles
else
  echo "$HOME/.dotfiles already exists. Not cloning the repo."
fi

bash ~/.dotfiles/setup/setup.sh 
