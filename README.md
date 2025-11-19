# .dotfiles

To install:

```bash
git clone https://github.com/alexander-turner/.dotfiles ~/.dotfiles && cd ~/.dotfiles && bash setup.sh
```

`setup.sh` will (with warning) **overwrite** your existing `.bashrc`, `.vimrc`, `.gitconfig`, `tmux.config`, `.config/nvim`, and `fish` configurations, so back them up first if you want to retain their contents. The new files will be hard-linked to the files in the repository, so you can edit either location and propagate the changes.

Features (configurable by changing `setup.sh`):

1. Installs `fish` shell and sets it as the default shell. `fish` has autocomplete, syntax highlighting, and indicates when a command is invalid.
   ![fish suggests command completions.](https://fishshell.com/assets/img/screenshots/autosuggestion.webp)

2. Also installs a cool `fish` theme, [`tide`](https://github.com/IlanCosman/tide):
![Compares tide theme configurations for the fish shell.](https://github.com/IlanCosman/tide/raw/assets/images/header.png)

3. Installs [`autojump`](https://github.com/wting/autojump) for quick directory navigation. Once you've been to directory `dir`, just hit `j dir` to go back there.
4. Installs `neovim` and sets it as default editor. Furthermore, sets up `Lazynvim`, which is basically a full-fledged IDE.
   ![Showing off the Lazynvim CLI IDE.](https://user-images.githubusercontent.com/292349/213447056-92290767-ea16-430c-8727-ce994c93e9cc.png)

5. Installs a bunch of nice shortcuts, including `git` aliases (e.g. `git add` -> `ga`).
6. Overrides `rm` in favor of the reversible `tp` (`trash-put`) command. No more accidentally permanently deleting crucial files!
7. Installs `tmux` with the `tmux-restore` and `tmux-continuum` plugins. Basically, this means that your `tmux` sessions will be saved and restored automatically. No more losing your work when your computer crashes!
8. Installs `AutoRaise`, which automatically focuses the window under the cursor (after a delay).
9. Automatically uses `mosh` instead of `ssh`. `mosh` is a more robust version of `ssh` which can handle network changes and disconnections more gracefully. It generally presents a lower-latency user experience.
10. Installs `envchain` for secure secret management via OS keychain. Store API keys and credentials hardware-encrypted instead of in plaintext config files.
11. Configures open source AI-powered development tools:
    - Automatic commit message generation,
    - Local LLM support with Ollama and Open WebUI,
    - Aider for CLI coding,
    - VSCodium with Roo Cline extension for privacy-first AI pair programming (use also with confidential cloud computing, like via [`redpill.ai`](https://redpill.ai)),
    - `wut` command to explain shell output.
12. Most importantly, the `goosesay` command. A variant on the classic `cowsay` (which renders text inside a cow's speech bubble), `goosesay` goosens up your terminal just the right amount. For example:

```plaintext
echo "Never gonna give you up" | goosesay
 _________________________
< Never gonna give you up >
 -------------------------
    \
     \
      \     ___
          .´   ""-⹁
      _.-´)  e  _  '⹁
     '-===.<_.-´ '⹁  \
                   \  \
                    ;  \
                    ;   \          _
                    |    '⹁__..--"" ""-._    _.´)
                   /                     ""-´  _>
                  :                          -´/
                  ;                  .__<   __)
                   \    '._      .__.-'   .-´
                    '⹁_    '-⹁__.-´      /
                       '-⹁__/    ⹁    _.´
                      ____< /'⹁__/_.""
                    .´.----´  | |
                  .´ /        | |
                 ´´-/      ___| ;
                          <_    /
                            `.'´
```

This script creates `~/.extras.fish` and `~/.extras.bash`, which are automatically sourced by `config.fish` and `.bashrc`. These files are not tracked by version control --- include commands you only want for the current machine, but use `envchain` for secret management.

## Secure secret management with [`envchain`](https://github.com/sorah/envchain)

- Hardware-encrypted via MacOS Secure Enclave or Linux gnome-keyring
- No plaintext secrets in config files or git repositories
- Auto-unlocks with your OS (low friction)

### How to set secrets

```fish
envchain --set ai OPENAI_API_KEY
envchain --set ai ANTHROPIC_API_KEY
envchain --set cloudflare CLOUDFLARE_API_TOKEN
```

### How to grant access to secrets

You'll need to wrap commands with the keys you want to grant access to.

```fish
# Granular access to specific keys
function run_push_checks
    set -l service_keys DEEPSOURCE_DSN LOST_PIXEL_PROJECT_ID LOST_PIXEL_API_KEY
    envchain services $service_keys -- python ~/Downloads/TurnTrout.com/scripts/run_push_checks.py $argv
end
```

## Reinstalling programs using `brew`

`mac_brew.txt` contains a list of programs which I like using on my personal Mac. To install these, use `fish bin/install_apps.fish`.

## Other notes

- To disable parenthesis matching in `nvim`, delete the `mini.pairs` plugin from `~/.local/share/nvim/lazy/LazyVim/lua/azyvim/plugins/coding.lua`.
