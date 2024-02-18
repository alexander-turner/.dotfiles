# .dotfiles
To install:
```bash
git clone https://github.com/alexander-turner/.dotfiles ~/.dotfiles && cd ~/.dotfiles && bash setup.sh
```

This will (with warning) **overwrite** your existing `.bashrc`, `.vimrc`, `.gitconfig`, `tmux.config`, `.config/nvim`, and `fish` configurations, so back them up first if you want to retain their contents. The new files will be hard-linked to the files in the repository, so you can edit either location and propagate the changes.

Features:
1. Installs `fish` shell and sets it as the default shell. `fish` has autocomplete, syntax highlighting, and indicates when a command is invalid. 
![](https://fishshell.com/assets/img/screenshots/autosuggestion.png)
Also installs a cool `fish` theme, [`tide`](https://github.com/IlanCosman/tide): 
![](https://github.com/IlanCosman/tide/raw/assets/images/header.png)
2. Installs [`autojump`](https://github.com/wting/autojump) for quick directory navigation. Once you've been to directory `dir`, just hit `j dir` to go back there. 
3. Installs `neovim` and sets it as default editor. Furthermore, sets up `Lazynvim`, which is basically a full-fledged IDE. It even has Copilot support. (But don't use this for confidential information!)
![](https://user-images.githubusercontent.com/292349/213447056-92290767-ea16-430c-8727-ce994c93e9cc.png)
4. Installs a bunch of nice shortcuts, including `git` aliases (e.g. `git add` -> `ga`). 
5. Overrides `rm` in favor of the reversible `tp` (`trash-put`) command. No more accidentally permanently deleting crucial files!
6. Installs `tmux` with the `tmux-restore` and `tmux-continuum` plugins. Basically, this means that your `tmux` sessions will be saved and restored automatically. No more losing your work when your computer crashes!


This script also creates `~/.extras.fish` and `~/.extras.bash` which are automatically sourced by `config.fish` and `.bashrc`. These files are not tracked by the repository. Thus, these files are perfect for storing API keys and other information which shouldn't be shown to Github.

Furthermore, `mac_brew.txt` contains a list of programs which I like using on my personal Mac. To install these, use `cat mac_brew.txt | xargs brew install`.
