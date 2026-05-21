# .dotfiles

To install:

```bash
git clone https://github.com/alexander-turner/.dotfiles ~/.dotfiles && cd ~/.dotfiles && bash setup.bash
```

`setup.bash` will (with warning) **overwrite** your existing `.bashrc`, `.vimrc`, `.gitconfig`, `.npmrc`, `.tmux.conf`, `.config/nvim`, `.config/fish/config.fish`, `.config/mods/mods.yml`, and any `.aider*` files. On macOS it also links `.aerospace.toml`, `~/Library/com.googlecode.iterm2.plist`, `~/.config/borders/bordersrc`, and `~/.config/vagrant-templates/Vagrantfile`. Before clobbering, the previous file is moved to `~/.dotfiles-backup/<UTC-timestamp>/<rel-path>/` — so a misclick on the y/N prompt is recoverable. The new files are symlinked to the files in the repository, so edits to the originals are reflected immediately.

You can also run `bash setup.bash --link-only` to refresh symlinks without reinstalling packages. Both setup paths end by running `bin/doctor.bash`, which reports a green health summary (or tells you exactly what's still broken).

To verify health at any time: `bash bin/doctor.bash` (or `--quiet` for failures-only). To reverse the install — removing only symlinks that point into this repo and restoring the most recent backup — run `bash bin/uninstall.bash` (add `--yes` for non-interactive). The dotfiles repo itself is left untouched.

Once setup has run, those chores are also reachable through the `dotfiles` dispatcher symlinked at `~/.local/bin/dotfiles` (fish completions included): `dotfiles doctor | uninstall | link | lint`.

Two CI workflows guard the install:

- `lint.yml` — shellcheck + fish syntax + stylua + yamllint + ruff, plus a `gitleaks` scan of the full git history (auto-fixes the formatters).
- `idempotency.yml` — runs `setup.bash --link-only` twice on `ubuntu-latest` and `macos-latest`, asserts identical symlink set, no skip/overwrite/backup output on the second pass, and a clean `doctor.bash` symlink section.

Features (configurable by changing `setup.bash`):

1. Installs `fish` shell and sets it as the default shell. `fish` has autocomplete, syntax highlighting, and indicates when a command is invalid.
   ![fish suggests command completions.](https://fishshell.com/assets/img/screenshots/autosuggestion.webp)

2. Also installs a cool `fish` theme, [`tide`](https://github.com/IlanCosman/tide):
![Compares tide theme configurations for the fish shell.](https://github.com/IlanCosman/tide/raw/assets/images/header.png)

3. Installs [`zoxide`](https://github.com/ajeetdsouza/zoxide) for quick directory navigation. Once you've been to directory `dir`, just hit `j dir` to go back there.
4. Installs `neovim` and sets it as default editor. Furthermore, sets up `LazyVim`, which is basically a full-fledged IDE.
   ![Showing off the LazyVim CLI IDE.](https://user-images.githubusercontent.com/292349/213447056-92290767-ea16-430c-8727-ce994c93e9cc.png)

5. Installs a bunch of nice shortcuts, including `git` aliases (e.g. `git add` -> `ga`).
6. Overrides `rm` in favor of the reversible `tp` (`trash-put`) command. No more accidentally permanently deleting crucial files!
7. Installs `tmux` with the `tmux-restore` and `tmux-continuum` plugins. Basically, this means that your `tmux` sessions will be saved and restored automatically. No more losing your work when your computer crashes!
8. Installs `mosh` alongside `ssh`. `mosh` is a more robust version of `ssh` that handles network changes and disconnections more gracefully. Set `USE_MOSH=true` in `config.fish` to use it by default.
9. Installs `envchain` (OS Keychain at runtime) plus the [Bitwarden CLI](https://bitwarden.com/help/cli/) for cross-machine secret sync. API keys live encrypted in your Bitwarden vault; a background sync at shell startup pulls updates into envchain so wrappers like `npm`, `rclone`, `twine`, and `aider_redpill` stay zero-prompt at runtime.
10. Configures open source AI-powered development tools:
    - Automatic commit message generation,
    - Aider for CLI coding,
    - VSCodium with Roo Cline extension for privacy-first AI pair programming (use also with confidential cloud computing, like via [`redpill.ai`](https://redpill.ai)),
    - `claude-code-router` (`ccr`) installed via pnpm and supervised by `launchagents/com.turntrout.ccr.plist`, so the private Claude wrappers route through [Venice](https://venice.ai) without the daemon dying across reboots. Store your Venice API key in Bitwarden as `envchain/ai/VENICE_INFERENCE_KEY` (the standard `envchain/<namespace>/<VAR>` convention) — `bwseed` then pulls it into envchain on every machine.
    - `mods` (Charm) for piping shell output to an LLM, e.g. `<failing-cmd> 2>&1 | mods 'what broke?'`. Routes through Venice via `apps/mods/mods.yml`.
11. Modern Unix toolkit installed via `Brewfile`:
    - `eza` — drop-in `ls` replacement with git-aware listing and tree view; the fish `ls` function prefers it when present.
    - `ripgrep` (`rg`), `fd`, `bat` — faster grep / find / cat. In interactive fish, `grep` dispatches to `rg` and `cat` to `bat`; bash scripts and subshells still get the real binaries. (`find` is intentionally not shadowed — the argument grammars don't line up.) Use `command grep` or `\grep` to bypass the wrapper.
    - `fzf` plus the [`PatrickF1/fzf.fish`](https://github.com/PatrickF1/fzf.fish) plugin: Ctrl-R history search, Ctrl-Alt-F file picker, etc., all with `bat` previews.
    - `git-delta` — paged, syntax-highlighted git diffs, wired up in `.gitconfig`.
    - `mise` — single tool for Node, Python, Ruby, Go versions; auto-activated in fish via `apps/fish/conf.d/mise.fish`.
    - `tokei` (LOC), `dust` (`du` with bars), `bottom` (`btm`, htop-alike).
    - `carapace` — universal completion engine, auto-activated for fish.
    - `shfmt` — shell formatter, also enforced in CI.

12. AI tooling routed through Venice (E2EE inference):
    - `mods` (Charm) for piping shell output through an LLM (`git diff | mods 'review for issues'`); configured in `apps/mods/mods.yml`.
    - `aider`, `claude-code-router`, VSCodium + Roo Cline.
    - `AGENTS.md` symlinks to `CLAUDE.md` so Cursor/Aider/OpenCode pick up the same project context Claude Code uses.
    - `.mcp.json` configures the filesystem MCP server scoped to `~/.dotfiles` for Claude Code sessions in this repo.
    - `.claude/hooks/notify.bash` fires cross-platform desktop notifications when Claude Code needs input.

13. macOS keyboard-driven WM:
    - `aerospace` for tiling.
    - `JankyBorders` (`borders`) draws a colored outline around the focused window; config at `apps/borders/bordersrc`, spawned by Aerospace's `after-startup-command`.

14. Most importantly, the `goosesay` command. A variant on the classic `cowsay` (which renders text inside a cow's speech bubble), `goosesay` goosens up your terminal just the right amount. For example:

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

### Defense against accidental leaks

Two-layer `gitleaks` gate, same `.gitleaks.toml`: pre-push scans only
the commits the push adds (fast even on huge histories), CI scans full
history on every PR. If a real hit lands, **rotate first**, then rewrite.

### One-time setup

Get a Bitwarden personal API key from web vault → Settings → Security → Keys → "View API Key", then:

```bash
bash bin/bw-login.bash
```

You'll be prompted (each prompt is skippable) for `client_id`, `client_secret`, and your master password. Both are stashed in macOS Keychain; the master password lets the autosync run unattended on every shell startup. The script then runs an initial seed.

### Adding a new secret

```bash
bwadd <namespace> <VAR>              # prompts for value, pushes to vault + envchain
bwadd --update <namespace> <VAR>     # overwrite an existing vault value (rotation)
```

On every other machine the next shell startup picks it up automatically (or run `bwseed` on demand).

### GitHub CLI auth via Bitwarden

`setup.bash` authenticates `gh` non-interactively when a PAT is stored in the vault as `envchain/github/PAT`. Generate a token at <https://github.com/settings/tokens> (scopes: `repo`, `read:org` — add `admin:public_key` only if you want `gh` to upload your SSH key for you), then:

```bash
bin/bw-add-secret.bash github PAT
```

On the next `setup.bash` run (or directly via `bin/gh-auth-from-bw.bash`), `gh auth login --with-token` picks it up. No browser, no SSH-key-upload step — useful on headless boxes. If the item is missing, `setup.bash` falls back to the interactive `gh auth login` flow.

### Auto-sync on shell startup

`config.fish` kicks off a background `bw sync` + envchain refresh on each interactive shell, throttled to once per six hours via `~/.cache/bw-envchain-sync.stamp`. To force a refresh now:

```bash
bwseed
```

### Migrating an existing envchain into Bitwarden

If a machine has values in envchain that aren't in the vault yet:

```bash
export BW_SESSION=$(bw unlock --raw)
bash bin/migrate-envchain-to-bitwarden.bash
```

Values pipe stdin→stdin from envchain into `bw create item`; nothing is logged.

### Threat model

- Vault decryption requires the master password. A stolen API key without it gets only the encrypted vault.
- The cached master password in macOS Keychain has the same protection envchain values themselves do — Keychain ACL + GUI-login-time unlock.
- Secret values never appear on any process's argv: every helper pipes values stdin→stdin between bw, envchain, and child commands.

## Reinstalling programs using `brew`

`Brewfile` contains a list of programs which I like using on my personal Mac. To install these, run `brew bundle --file=Brewfile`.

## Devcontainer

`.devcontainer/` ships a sandboxed image for hacking on this repo with
Claude Code: Ubuntu 22.04 base + Node 20 (NodeSource) + the lint/test
toolchain (shellcheck, shfmt, ruff/pytest, yamllint, fish, gitleaks,
stylua) + the `gh` CLI via the official `github-cli` devcontainer
feature + Claude Code itself. The MCP filesystem server is **not**
pre-installed; `.mcp.json`'s `npx --yes` is the single source of truth
for its version and fetches on first use (allowed by the firewall).

`postCreateCommand` locks egress with `init-firewall.sh` (NET_ADMIN
allowlist of npm, PyPI, Anthropic, GitHub) and then runs
`setup.sh --link-only` against the container's `$HOME`.

### Pulling the prebuilt image

`.github/workflows/devcontainer-smoke.yml` publishes the image to
`ghcr.io/alexander-turner/dotfiles-devcontainer:latest` (plus a tag
per commit SHA) on every push to `main`. Both devcontainer configs
declare it as `build.cacheFrom`, so a cold-machine build pulls the
cached layers (~1 min) instead of rebuilding from scratch (~5-10 min).
Local edits to the Dockerfile still rebuild only the affected layers.

To pull explicitly (e.g. for `docker run` outside VS Code):

```bash
docker pull ghcr.io/alexander-turner/dotfiles-devcontainer:latest
```

### Multiple Claude sessions on the same repo

Use a `git worktree` per session — the container is the protection
boundary, the session is just an invocation. Each worktree is a
different *workspace path*, so the `${devcontainerId}` macro in
`mounts:` hashes to a different value, and the
`dotfiles-claude-history-*` / `dotfiles-claude-config-*` named
volumes resolve to *different* volumes per worktree. Full
shell-history / Claude-config isolation; near-zero disk overhead
(worktrees share `.git`).

```bash
git worktree add ../dotfiles-feature-b feature-b
# Open ../dotfiles-feature-b in a second VS Code window and Reopen in Container.
# Or, without VS Code:
devcontainer up --workspace-folder ../dotfiles-feature-b
```

## Other notes

- To disable parenthesis matching in `nvim`, delete the `mini.pairs` plugin from `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/coding.lua`.
