# Claude Code Configuration

This directory contains configuration and skills for Claude Code.

## Structure

```
.claude/
├── settings.json              # Hooks + statusLine + permissions.deny
├── hooks/
│   ├── session-setup.sh      # SessionStart — installs tools, configures git
│   ├── pre-push-check.sh     # PreToolUse(git push|gh pr) — build/lint/typecheck
│   ├── audit-log.sh          # PostToolUse — append-only JSONL audit at ~/.claude/audit/
│   ├── scan-input.sh         # UserPromptSubmit — refuse prompts containing secrets
│   ├── statusline.sh         # statusLine — model · cwd · git branch · mode
│   ├── notify.sh             # Notification — cross-platform desktop notifier
│   └── lib-checks.sh         # Shared bash helpers (exists, has_script)
└── skills/
    └── pr-creation/       # PR creation workflow with self-critique
        ├── SKILL.md       # Main skill entrypoint
        ├── critique-prompt.md  # Self-critique checklist for sub-agent
        └── pr-templates.md     # PR formatting and validation reference
```

## How It Works

### Session Start Hook

When Claude Code starts a session, it automatically runs `session-setup.sh` which:

1. **Installs tools**: shfmt, gh (GitHub CLI), jq, shellcheck
2. **Configures git hooks**: Sets `core.hooksPath` to `.hooks/`
3. **Validates GitHub CLI auth**: Fails fast if `GH_TOKEN` is missing
4. **Detects GitHub repo**: Extracts `owner/repo` from proxy remotes in web sessions
5. **Installs dependencies**: Node (pnpm/npm) and Python (uv) if applicable

### Pre-Push Check Hook

Before `git push` or `gh pr` commands, `pre-push-check.sh` runs any configured checks:

- **build** (`pnpm build`): Catches type errors in TypeScript projects
- **lint** (`pnpm lint`): Catches code quality issues
- **typecheck** (`pnpm check`): Additional type checking if configured
- **ruff**: Python linting if applicable

Only runs scripts that are actually configured in `package.json` — skips placeholder scripts.

### Destructive-Bash Block

Hard-to-reverse Bash commands are blocked outright via `permissions.deny`
in `settings.json`, not by a script. Anything matching `rm -rf*`, `rm -fr*`,
`rm -Rf*`, `sudo rm*`, `git push --force*`, `git push -f*`,
`git reset --hard*`, `git clean -f[dx]*`, `git branch -D*`, `bw delete*`,
`envchain --unset*`, or `launchctl unload|bootout*` is refused by the
harness before the tool call runs. To run such a command intentionally,
do it in your own shell — Claude Code shouldn't be the one pulling the
trigger.

### Audit Log

`audit-log.sh` runs on every `PostToolUse` and appends a single JSONL line
per tool invocation to `~/.claude/audit/<UTC-date>.jsonl` (`chmod 600`).
Lines are stamped with `date -u +%FT%TZ` server-side so the model can't
spoof the timestamp. Tool responses are truncated to 500 chars — the
`tool_input` is the auditable bit. Failures are silent so the hook can
never block tool use.

### Prompt Secret Scan

`scan-input.sh` runs on `UserPromptSubmit` and refuses (exit 2) prompts
that match high-precision secret patterns (AWS keys, GitHub PATs, Anthropic
keys, Slack tokens, PEM private keys). The matching span is **not** echoed
back so the rejection reason doesn't re-leak the secret. Bypass with
`CLAUDE_ALLOW_SECRETS=1` if you genuinely need to discuss a token shape.
Soft-fails to allow when `jq` is missing — the same prompt would still hit
`gitleaks` at commit time.

### Status Line

`statusline.sh` formats Claude Code's bottom-bar to
`model · cwd · git:branch · [permission_mode]`. `cwd` collapses `$HOME`
to `~` and elides paths longer than 40 chars to `.../basename`. The
permission-mode chip is omitted when it's the default.

### Skills

Skills in `skills/` are reusable workflows that guide Claude through complex tasks:

- **pr-creation**: Creating pull requests with mandatory self-critique before submission (invoke with `/pr-creation`)

Skills are automatically available to Claude Code when working in this repository.

## Customization

### Adding Tools

Edit `hooks/session-setup.sh` to add more tools:

```bash
# Via uv
uv_install_if_missing mycommand mypackage

# Via webi (https://webinstall.dev)
webi_install_if_missing mytool

# Via apt (requires root)
if is_root; then
  apt-get install -y mytool
fi
```

### Adding Skills

Create new skill directories in `skills/` following the pattern in `pr-creation/SKILL.md`. Each skill should be a directory with a `SKILL.md` entrypoint and optional supporting files.

### Customizing Hooks

Modify `settings.json` to add more hooks. See the [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code) for available hook types.
