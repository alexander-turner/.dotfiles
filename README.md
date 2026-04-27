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
10. Installs `envchain` (OS Keychain at runtime) plus the [Bitwarden CLI](https://bitwarden.com/help/cli/) for cross-machine secret sync. API keys live encrypted in your Bitwarden vault; a background sync at shell startup pulls updates into envchain so wrappers like `npm`, `rclone`, `twine`, and `aider_redpill` stay zero-prompt at runtime.
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

This script creates `~/.extras.fish` and `~/.extras.bash`, which are automatically sourced by `config.fish` and `.bashrc`. These files are not tracked by version control --- include commands you only want for the current machine, but use Bitwarden + envchain for secret management.

## Secret management: Bitwarden vault → envchain runtime

Two layers, both encrypted, complementary roles:

- **Bitwarden vault** (source of truth, cross-machine). End-to-end encrypted; syncs to every device logged into your Bitwarden account. We use the personal API key flow so WebAuthn-only accounts work without 2FA prompts on `bw login`.
- **envchain** (runtime cache, per-machine). Reads from the macOS Keychain, which is silently unlocked at GUI login — so wrappers like `npm`, `rclone`, and `aider_redpill` are zero-prompt during normal use.

Each secret is stored as a Bitwarden Login item named `envchain/<namespace>/<VAR>` inside a folder named `envchain`. The wrappers in `apps/fish/config.fish` call `envchain <namespace> -- <command>`, exactly as before.

### One-time setup

Get a Bitwarden personal API key from web vault → Settings → Security → Keys → "View API Key", then:

```bash
bash bin/bw-login.sh
```

You'll be prompted (each prompt is skippable) for `client_id`, `client_secret`, and your master password. Both are stashed in macOS Keychain; the master password lets the autosync run unattended on every shell startup. The script then runs an initial seed.

### Adding a new secret

```bash
bwadd <namespace> <VAR>     # prompts for value (no echo), pushes to vault + envchain
```

On every other machine the next shell startup picks it up automatically (or run `bwseed` on demand).

### Auto-sync on shell startup

`config.fish` kicks off a background `bw sync` + envchain refresh on each interactive shell, throttled to once per six hours via `~/.cache/bw-envchain-sync.stamp`. To force a refresh now:

```bash
bwseed
```

### Migrating an existing envchain into Bitwarden

If a machine has values in envchain that aren't in the vault yet:

```bash
export BW_SESSION=$(bw unlock --raw)
bash bin/migrate-envchain-to-bitwarden.sh
```

Values pipe stdin→stdin from envchain into `bw create item`; nothing is logged.

### Threat model

- Vault decryption requires the master password. A stolen API key without it gets only the encrypted vault.
- The cached master password in macOS Keychain has the same protection envchain values themselves do — Keychain ACL + GUI-login-time unlock.
- Secret values never appear on any process's argv: every helper pipes values stdin→stdin between bw, envchain, and child commands.

## Reinstalling programs using `brew`

`Brewfile` contains a list of programs which I like using on my personal Mac. To install these, run `brew bundle --file=Brewfile`.

## Other notes

- To disable parenthesis matching in `nvim`, delete the `mini.pairs` plugin from `~/.local/share/nvim/lazy/LazyVim/lua/azyvim/plugins/coding.lua`.
