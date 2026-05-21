"""Tests for .claude/hooks/ scripts.

Mirrors the coverage of the previous bin/test-claude-hooks.sh harness but
expressed as pytest cases — pytest's tmp_path isolation, subprocess
capture, and assertion rewriting do in three lines what the shell harness
needed eval + heredocs for. Invoked from .github/workflows/lint.yml.
"""

from __future__ import annotations

import json
import os
import re
import stat
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
HOOKS = REPO_ROOT / ".claude" / "hooks"


def run_hook(
    name: str,
    *,
    stdin: str | None = None,
    env: dict[str, str] | None = None,
    cwd: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    """Invoke a hook the way Claude Code would: bash <script>, piping
    the JSON envelope on stdin. Env defaults to the parent process's env;
    callers pass `env={...}` to override (HOME, CLAUDE_PROJECT_DIR, etc.)."""
    merged_env = os.environ.copy()
    if env is not None:
        merged_env.update(env)
    return subprocess.run(
        ["bash", str(HOOKS / name)],
        input=stdin,
        env=merged_env,
        cwd=cwd,
        capture_output=True,
        text=True,
    )


# ── session-setup.sh ────────────────────────────────────────────────────────


def test_session_setup_empty_repo(tmp_path: Path) -> None:
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    result = run_hook("session-setup.sh", env={"CLAUDE_PROJECT_DIR": str(tmp_path)}, cwd=tmp_path)
    assert result.returncode == 0, result.stderr


def test_session_setup_proxy_url_exports_gh_repo(tmp_path: Path) -> None:
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    subprocess.run(
        ["git", "remote", "add", "origin", "http://local_proxy@127.0.0.1:18393/git/foo/bar"],
        cwd=tmp_path,
        check=True,
    )
    env_file = tmp_path / "env"
    result = run_hook(
        "session-setup.sh",
        env={
            "CLAUDE_PROJECT_DIR": str(tmp_path),
            "CLAUDE_ENV_FILE": str(env_file),
            # Clear inherited GH_REPO so the detection branch fires.
            "GH_REPO": "",
        },
        cwd=tmp_path,
    )
    assert result.returncode == 0, result.stderr
    assert 'GH_REPO="foo/bar"' in env_file.read_text()


def test_session_setup_github_remote_attempts_set_default(tmp_path: Path) -> None:
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    subprocess.run(
        ["git", "remote", "add", "origin", "https://github.com/owner/repo.git"],
        cwd=tmp_path,
        check=True,
    )
    result = run_hook(
        "session-setup.sh",
        env={"CLAUDE_PROJECT_DIR": str(tmp_path), "GH_REPO": "owner/repo"},
        cwd=tmp_path,
    )
    assert result.returncode == 0, result.stderr


# ── pre-push-check.sh ───────────────────────────────────────────────────────


def test_pre_push_check_no_project_files(tmp_path: Path) -> None:
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    result = run_hook(
        "pre-push-check.sh",
        env={"CLAUDE_PROJECT_DIR": str(tmp_path)},
        cwd=tmp_path,
    )
    assert result.returncode == 0


def test_pre_push_check_failing_lint(tmp_path: Path) -> None:
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    (tmp_path / "package.json").write_text(json.dumps({"scripts": {"lint": "false"}}))
    result = run_hook(
        "pre-push-check.sh",
        env={"CLAUDE_PROJECT_DIR": str(tmp_path)},
        cwd=tmp_path,
    )
    assert result.returncode == 1
    assert "lint FAILED" in (result.stdout + result.stderr)


def test_pre_push_check_placeholder_lint_skipped(tmp_path: Path) -> None:
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    (tmp_path / "package.json").write_text(
        json.dumps({"scripts": {"lint": "echo ERROR: Configure your linter"}})
    )
    result = run_hook(
        "pre-push-check.sh",
        env={"CLAUDE_PROJECT_DIR": str(tmp_path)},
        cwd=tmp_path,
    )
    assert result.returncode == 0


# ── notify.sh ───────────────────────────────────────────────────────────────


def test_notify_with_message() -> None:
    result = run_hook("notify.sh", stdin='{"message":"hi"}')
    assert result.returncode == 0


def test_notify_no_stdin_uses_fallback() -> None:
    result = run_hook("notify.sh", stdin="")
    assert result.returncode == 0


# ── scan-input.sh ───────────────────────────────────────────────────────────


def test_scan_input_clean_prompt() -> None:
    result = run_hook("scan-input.sh", stdin='{"prompt":"refactor the doctor script"}')
    assert result.returncode == 0


def test_scan_input_refuses_aws_key() -> None:
    result = run_hook(
        "scan-input.sh",
        stdin='{"prompt":"please rotate AKIAIOSFODNN7EXAMPLE before deploy"}',
    )
    assert result.returncode == 2
    assert "refused" in result.stderr


def test_scan_input_override_with_env() -> None:
    result = run_hook(
        "scan-input.sh",
        stdin='{"prompt":"AKIAIOSFODNN7EXAMPLE"}',
        env={"CLAUDE_ALLOW_SECRETS": "1"},
    )
    assert result.returncode == 0


def test_scan_input_missing_prompt_field_soft_fails() -> None:
    result = run_hook("scan-input.sh", stdin="{}")
    assert result.returncode == 0


# ── audit-log.sh ────────────────────────────────────────────────────────────


def test_audit_log_writes_jsonl(tmp_path: Path) -> None:
    fake_home = tmp_path / "home"
    fake_home.mkdir()
    payload = json.dumps(
        {"tool_name": "Read", "tool_input": {"file_path": "/x"}, "tool_response": "ok"}
    )
    result = run_hook("audit-log.sh", stdin=payload, env={"HOME": str(fake_home)})
    assert result.returncode == 0
    log_files = list((fake_home / ".claude" / "audit").glob("*.jsonl"))
    assert len(log_files) == 1
    lines = log_files[0].read_text().splitlines()
    assert len(lines) == 1
    record = json.loads(lines[0])
    assert record["tool"] == "Read"
    assert re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", record["ts"])


def test_audit_log_unwritable_home_still_exits_zero(tmp_path: Path) -> None:
    """Hook must never block tool use, even when ~/.claude is unwritable."""
    fake_home = tmp_path / "home"
    fake_home.mkdir(mode=0o000)
    try:
        result = run_hook("audit-log.sh", stdin="{}", env={"HOME": str(fake_home)})
        assert result.returncode == 0
    finally:
        fake_home.chmod(stat.S_IRWXU)


# ── statusline.sh ───────────────────────────────────────────────────────────


def test_statusline_well_formed_payload() -> None:
    payload = json.dumps(
        {"model": {"display_name": "Opus"}, "workspace": {"current_dir": "/tmp"}}
    )
    result = run_hook("statusline.sh", stdin=payload)
    assert result.returncode == 0
    assert "Opus" in result.stdout
    assert "/tmp" in result.stdout


def test_statusline_empty_stdin_still_prints() -> None:
    result = run_hook("statusline.sh", stdin="")
    assert result.returncode == 0
    assert "claude" in result.stdout.lower()


# notify-dangerous.sh was removed in favour of permissions.deny in
# .claude/settings.json — destructive Bash is now refused by the harness,
# no script needed. No test case here on purpose.


@pytest.fixture(autouse=True)
def _stable_settings_json() -> None:
    """Smoke-check that .claude/settings.json is well-formed JSON before
    every test. A typo there breaks every hook silently in CI, so failing
    fast keeps the failure attributable."""
    json.loads((REPO_ROOT / ".claude" / "settings.json").read_text())
