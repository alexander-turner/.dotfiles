# .dotfiles
To install:
```bash
git clone https://github.com/alexander-turner/.dotfiles ~/.dotfiles && cd ~/.dotfiles && bash setup.sh
```

This will (with warning) **overwrite** your existing `.bashrc`, `.vimrc`, `.gitconfig`, `tmux.config`, `.config/nvim`, and `fish` configurations, so back them up first if you want to retain their contents.

Features:
1. Installs `fish` shell and gives it a cool theme (`tide`). Sets `fish` as default shell. `fish` has autocomplete, syntax highlighting, and indicates when a command is invalid. 
2. Installs `[autojump]()` for quick directory navigation. Once you've been to directory `dir`, just hit `j dir` to go back there. 
3. Installs `neovim` and sets it as default editor. Furthermore, sets up `Lazynvim`, which is basically a full-fledged IDE. It even has Copilot support.
4. 
