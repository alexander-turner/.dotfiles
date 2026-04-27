# .dotfiles

To install:

```bash
git clone https://github.com/alexander-turner/.dotfiles ~/.dotfiles && cd ~/.dotfiles && bash setup.sh
```

`setup.sh` will (with warning) **overwrite** your existing `.bashrc`, `.vimrc`, `.gitconfig`, `tmux.config`, `.config/nvim`, and `fish` configurations, so back them up first if you want to retain their contents. The new files will be symlinked to the files in the repository, so edits to the originals are reflected immediately.

You can also run `bash setup.sh --link-only` to refresh symlinks without reinstalling packages.

Features (configurable by changing `setup.sh`):

1. Installs `fish` shell and sets it as the default shell. `fish` has autocomplete, syntax highlighting, and indicates when a command is invalid.
   ![fish suggests command completions.](https://fishshell.com/assets/img/screenshots/autosuggestion.webp)

2. Also installs a cool `fish` theme, [`tide`](https://github.com/IlanCosman/tide):
![Compares tide theme configurations for the fish shell.](https://github.com/IlanCosman/tide/raw/assets/images/header.png)

3. Installs [`autojump`](https://github.com/wting/autojump) for quick directory navigation. Once you've been to directory `dir`, just hit `j dir` to go back there.
4. Installs `neovim` and sets it as default editor. Furthermore, sets up `LazyVim`, which is basically a full-fledged IDE.
   ![Showing off the LazyVim CLI IDE.](https://user-images.githubusercontent.com/292349/213447056-92290767-ea16-430c-8727-ce994c93e9cc.png)

5. Installs a bunch of nice shortcuts, including `git` aliases (e.g. `git add` -> `ga`).
6. Overrides `rm` in favor of the reversible `tp` (`trash-put`) command. No more accidentally permanently deleting crucial files!
7. Installs `tmux` with the `tmux-restore` and `tmux-continuum` plugins. Basically, this means that your `tmux` sessions will be saved and restored automatically. No more losing your work when your computer crashes!
8. Installs `AutoRaise`, which automatically focuses the window under the cursor (after a delay).
9. Automatically uses `mosh` instead of `ssh`. `mosh` is a more robust version of `ssh` which can handle network changes and disconnections more gracefully. It generally presents a lower-latency user experience.
10. Installs [`rbw`](https://github.com/doy/rbw) (a fast Rust Bitwarden CLI) for secret management. API keys and credentials live encrypted in your Bitwarden vault and sync across machines automatically.
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

This script creates `~/.extras.fish` and `~/.extras.bash`, which are automatically sourced by `config.fish` and `.bashrc`. These files are not tracked by version control --- include commands you only want for the current machine, but use Bitwarden (via `rbw`) for secret management.

## Secure secret management with [`rbw`](https://github.com/doy/rbw) + Bitwarden

- Encrypted at rest in your Bitwarden vault; only the unlocked plaintext lives in `rbw-agent` memory
- Syncs across every machine logged into your Bitwarden account
- `rbw-agent` caches the unlocked vault, so reads are ~10ms

### One-time setup

```fish
brew install rbw
rbw config set email <your-bitwarden-email>
rbw login
rbw unlock
```

### Naming convention

Each secret is stored as a Bitwarden Login item named `envchain/<namespace>/<VAR>`, in a folder called `envchain`. The fish wrappers (`ai_secrets_wrap`, `cloudflare_secrets_wrap`, `npm`, `rclone`, `twine`, `aider_redpill`, ...) call `rbw get` against these names.

### Adding a new secret

```fish
rbw add envchain/ai/NEW_KEY    # paste the value when prompted
rbw sync                        # other machines pick it up automatically
```

Then add a corresponding `set -lx NEW_KEY (_rbw_get envchain/ai/NEW_KEY); or return 1` line inside the relevant wrapper in `apps/fish/config.fish`.

### Migrating from envchain

If you previously used envchain on this machine, run the one-time migration script:

```fish
export BW_SESSION=(bw unlock --raw)
bash bin/migrate-envchain-to-bitwarden.sh
```

It pipes each envchain value into `bw create item` via stdin without ever logging the value.

## Reinstalling programs using `brew`

`Brewfile` contains a list of programs which I like using on my personal Mac. To install these, run `brew bundle --file=Brewfile`.

## Other notes

- To disable parenthesis matching in `nvim`, delete the `mini.pairs` plugin from `~/.local/share/nvim/lazy/LazyVim/lua/azyvim/plugins/coding.lua`.
