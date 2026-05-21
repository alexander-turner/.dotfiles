# CLAUDE.md

Guidance for Claude Code when working in this dotfiles repo. Optimized for
keeping `setup.sh`, `doctor.sh`, and CI honest with each other.

## Layout

- `setup.sh` — top-level installer; idempotent, supports `--link-only`.
  Always finishes by running `bin/doctor.sh` so the user sees a green
  health summary (or knows exactly what's still broken).
- `bin/lib/safe_link.sh` — the only place that creates user-facing symlinks.
  Backs up real files to `~/.dotfiles-backup/<UTC-timestamp>/` before
  overwriting.
- `bin/doctor.sh` — read-only health check; mirrors what `setup.sh` builds.
- `bin/uninstall.sh` — reverses `setup.sh`'s symlink creation, restoring
  the most recent backup when one exists.
- `apps/fish/config.fish`, `.bashrc` — interactive shell config. `.bashrc`
  hands off to fish for interactive use.
- `apps/fish/conf.d/*.fish` — auto-sourced activation snippets (mise,
  carapace).
- `apps/mods/mods.yml` — Charm `mods` config; routes through Venice
  (E2EE) only. Wrapped by the `mods` fish function.
- `apps/borders/bordersrc` — JankyBorders config; spawned by Aerospace's
  `after-startup-command`.
- `AGENTS.md` — symlink to `CLAUDE.md`. Lets Cursor / Aider / OpenCode
  pick up the same project context Claude Code uses.
- `.mcp.json` — Claude Code MCP server config; currently registers the
  filesystem MCP scoped to `~/.dotfiles`.
- `.claude/hooks/notify.sh` — cross-platform desktop notification for
  the Notification lifecycle hook.
- `Brewfile` — package manifest, gated by `if OS.mac?` for cask blocks.
- `launchagents/`, `etc/sudoers.d/` — `__USERNAME__` templates rendered
  during install.
- `.github/workflows/lint.yml` — shellcheck + shfmt + stylua + yamllint
  + ruff + gitleaks. Auto-fixes and pushes a `style:` commit.
- `.github/workflows/idempotency.yml` — runs `setup.sh --link-only` twice
  on both `ubuntu-latest` and `macos-latest`, asserts identical symlink
  set + clean doctor output. The macOS leg covers the `if [ "$(uname)"
  = "Darwin" ]` branches that Ubuntu can't.

## Maintenance invariants

Whenever you add anything to `setup.sh`, `safe_link`, or related scripts,
update the matching observer.

### Doctor upkeep

`doctor.sh` is the contract for "this dotfiles install is healthy."
Every new symlink, daemon, or required external dependency added to
`setup.sh` must get a corresponding check in `doctor.sh`. Concretely:

- New `safe_link` call in `setup.sh` → new `check_symlink` line in
  `doctor.sh`'s "Symlinks" section.
- New `brew install` of a tool that's expected at runtime (i.e. used by
  `config.fish` or shell wrappers) → new `check_command` entry.
- New `launchctl load` / launchd plist symlink → new check in the
  "launchd agents" section, including a `launchctl list | grep` for the
  loaded label.
- New `envchain` namespace consumed by a wrapper in `config.fish` → list
  it in the "Secrets" section comment so users know to seed it.

A doctor check that requires an optional tool should `skip` (not `fail`)
when the tool isn't installed — `doctor.sh` is meant to be safe to run on
a partially-bootstrapped machine.

### Uninstall upkeep

`bin/uninstall.sh` is the inverse of `setup.sh` for symlinks in `$HOME`.
Every new `safe_link` in `setup.sh` whose target lives in `$HOME` must
get a matching `remove_dotfile_symlink` call in `uninstall.sh`. The
mirror set is:

- `safe_link "$DOTFILES_DIR/foo" "$HOME/.foo"` in `setup.sh` →
  `remove_dotfile_symlink "$HOME/.foo" "$DOTFILES_DIR/foo"` in
  `uninstall.sh`.
- macOS-only links go inside `if $IS_MAC` in `uninstall.sh`, same as the
  `if [ "$(uname)" = "Darwin" ]` block in `setup.sh`.
- Loops over a directory (e.g. `for aider_file in ...`) should iterate
  the same source list in both files — don't hard-code the names.

`uninstall.sh` MUST NOT touch the in-repo `.hooks/pre-push` symlink (that
one's repo plumbing, not a user dotfile).

### Idempotency upkeep

`setup.sh --link-only` MUST be safe to run repeatedly. CI enforces this.
When editing the `--link-only` path:

- Don't add `read -rp` prompts on the success path — use `safe_link`,
  which only prompts when clobbering a non-symlink real file.
- Don't add commands that produce side effects on every run (e.g.
  unconditional `cp`, appending to a file). Guard with an existence or
  content check.
- Anything that writes outside `$HOME` (e.g. the in-repo `.hooks/pre-push`
  symlink, sudoers fragments) must also be a no-op on re-run.

### Linker upkeep

`safe_link` is the sole entry point for symlink creation. If you find
yourself writing `ln -s` directly in `setup.sh`, route it through
`safe_link` instead so the backup-on-clobber behaviour is uniform.

The neovim config block in `setup.sh` predates `safe_link` and handles
directory targets specially. If you extend it (e.g. for a new IDE config
dir), keep the three-branch structure: already-correct symlink → no-op,
real dir → prompt, missing → create.

### Secrets

- Bitwarden vault is the cross-machine source of truth; envchain is the
  per-machine runtime cache (auto-unlocked via macOS Keychain at GUI
  login). Don't add a third secrets layer.
- Secrets must never appear on argv. Pipe stdin → stdin between `bw`,
  `envchain`, and child commands. See `bin/bw-add-secret.sh` for the
  pattern.
- Public files must not contain credentials. The lint workflow runs
  `gitleaks` against the full git history on every PR — if it flags
  something, rotate the secret first, then fix the commit.

### AI provider routing

- Inference flows through Venice only for new tooling — Venice
  provides end-to-end encryption between client and inference, so
  prompts/outputs are not visible to the provider. Redpill's TEE is a
  weaker guarantee and is not used for new wrappers.
- `apps/mods/mods.yml` lists Venice models only (qwen-2.5-coder,
  llama-3.3, mistral, etc.). The `mods` fish function wraps invocations
  in `envchain ai` so `VENICE_INFERENCE_KEY` is populated from the
  Keychain.

### Cross-platform

- `IS_MAC=$([[ "$(uname)" == "Darwin" ]] && echo true || echo false)` is
  the canonical detector. Linux is everything else; we don't separately
  branch for distros, and we don't support WSL.
- Cask entries belong inside the `if OS.mac?` block in `Brewfile`. Brews
  that exist on both platforms go above it.
- macOS-only paths in `setup.sh` (launchd agents, defaults writes,
  iTerm2 integration) live inside `if [ "$(uname)" = "Darwin" ]`.

## Conventions

- Bash scripts: `set -euo pipefail` at the top. Use `command_exists` for
  tool detection. Use `status_msg "..."` (defined in `setup.sh`) for
  visible progress lines so output stays consistent.
- Prefer fish abbreviations (`abbr -a`) over functions when the only
  job is text expansion — abbrs preserve history readability.
- Use `command <name>` to bypass fish/bash function shadowing
  (e.g. `command rm`, `command npm`) rather than removing the wrapper.

## Workflow shell scripts live in `bin/`, not inline in `.yml`

Inline `run: |` blocks in `.github/workflows/*.yml` are invisible to
shellcheck/shfmt and skip the auto-fix pipeline. Anything beyond a
trivial 1-3 line install incantation should be extracted to
`bin/<name>.sh` and invoked from the workflow as `run: bash
bin/<name>.sh` — `bin/lint.sh`'s shellcheck glob (`bin/*.sh`) then
covers it automatically.

Reference: `bin/check-idempotency.sh` is invoked from
`.github/workflows/idempotency.yml` with `TEST_HOME` / `SCRATCH` passed
via `env:`. The script defaults both to `mktemp` so it's runnable
locally too.

**Don't extract from template-synced workflows.** `template-sync.yaml`
copies these files verbatim from the upstream template on every daily
run, so any local edits get clobbered:

- `.github/workflows/template-sync.yaml`
- `.github/workflows/dependabot-auto-merge.yaml`
- `.github/workflows/claude.yaml`
- `.github/workflows/phone-home.yaml`
- `.github/workflows/security-vulnerability-scan.yaml`

The full list is in `template-sync.yaml`'s `SYNC_PATHS` env. Any
refactor for shellcheck coverage of those scripts has to land upstream
in `alexander-turner/claude-automation-template`.

## When fixing CI failures

- `lint.yml` auto-fixes shellcheck/stylua/ruff issues and commits them
  back. If your push is followed by a `style: auto-fix` commit, pull
  before continuing.
- `gitleaks` failures are not auto-fixed. Treat any hit as a real
  incident: rotate the leaked credential, then either rewrite the
  commit (if local) or add an allowlist entry justifying the false
  positive.
- `idempotency.yml` failure usually means a new step in `setup.sh` is
  not safely re-runnable. The diff between `links1.txt` and `links2.txt`
  in the run log shows which symlink mutated.

## Local quick reference

```bash
bash setup.sh --link-only       # refresh symlinks only (also runs doctor)
bash bin/doctor.sh              # health check
bash bin/doctor.sh --quiet      # show only failures/skips
bash bin/uninstall.sh           # remove $HOME symlinks, restore backups
bash bin/uninstall.sh --yes     # ... non-interactive
bash bin/lint.sh                # run all linters locally
bash bin/lint.sh --fix          # auto-fix what we can
bwseed                          # force Bitwarden → envchain refresh
```
