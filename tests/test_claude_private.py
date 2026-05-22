"""Smoke tests for bin/claude-private.

The wrapper routes claude-code through ccr (loopback proxy) to Venice's
biggest E2EE model. End-to-end testing would require a running ccr + valid
Venice key; instead we use CLAUDE_PRIVATE_DRY_RUN=1 to assert the wrapper
resolves the right `claude` binary and sets the right env, and we use a
stub `claude` on PATH so the resolver actually has something to find.
"""

from __future__ import annotations

import os
import stat
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
CLAUDE_PRIVATE = REPO_ROOT / "bin" / "claude-private"


def _make_fake_claude(dir_: Path) -> Path:
    """Drop a 'claude' stub into dir_ so find_real_claude() has a hit."""
    fake = dir_ / "claude"
    fake.write_text('#!/bin/bash\necho "fake-claude $*"\n')
    fake.chmod(fake.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    return fake


def _run(args: list[str], path_dirs: list[Path], **env_overrides: str) -> subprocess.CompletedProcess[str]:
    env = {
        **os.environ,
        "PATH": ":".join(str(p) for p in path_dirs),
        "CLAUDE_PRIVATE_DRY_RUN": "1",
        **env_overrides,
    }
    return subprocess.run(
        [str(CLAUDE_PRIVATE), *args],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def test_dry_run_sets_routing_envs(tmp_path: Path) -> None:
    _make_fake_claude(tmp_path)
    r = _run(["--help"], [tmp_path])
    assert r.returncode == 0, r.stderr
    assert "ANTHROPIC_BASE_URL=http://127.0.0.1:3456" in r.stdout
    assert "ANTHROPIC_AUTH_TOKEN=ccr-routed" in r.stdout
    assert "CLAUDE_NO_SANDBOX=1" in r.stdout
    assert "--model venice,qwen3-coder-480b-a35b-instruct-turbo" in r.stdout
    assert "--help" in r.stdout


def test_overrides_via_env(tmp_path: Path) -> None:
    """CCR_URL and CLAUDE_PRIVATE_MODEL knobs should win over defaults."""
    _make_fake_claude(tmp_path)
    r = _run(
        ["-p", "hi"],
        [tmp_path],
        CCR_URL="http://127.0.0.1:9999",
        CLAUDE_PRIVATE_MODEL="venice,qwen3-235b",
    )
    assert r.returncode == 0, r.stderr
    assert "ANTHROPIC_BASE_URL=http://127.0.0.1:9999" in r.stdout
    assert "--model venice,qwen3-235b" in r.stdout


def test_missing_claude_binary_errors(tmp_path: Path) -> None:
    """No claude on PATH ⇒ exit 127 with an actionable message."""
    empty = tmp_path / "empty"
    empty.mkdir()
    r = _run([], [empty])
    assert r.returncode == 127
    assert "real claude binary not found" in r.stderr
    assert "pnpm add -g @anthropic-ai/claude-code" in r.stderr


@pytest.mark.parametrize("self_path_first", [True, False])
def test_skips_dotfiles_claude_shim(tmp_path: Path, self_path_first: bool) -> None:
    """If bin/claude (the sandbox shim) appears on PATH, claude-private must
    skip it — otherwise it'd recursively re-enter the wrapper chain."""
    # Plant the dotfiles shim and a real-looking claude side by side.
    shim_dir = tmp_path / "shim"
    real_dir = tmp_path / "real"
    shim_dir.mkdir()
    real_dir.mkdir()
    # Real binary first
    _make_fake_claude(real_dir)
    # Copy the actual bin/claude shim so the grep-by-comment skip rule fires.
    shim_dst = shim_dir / "claude"
    shim_dst.write_text((REPO_ROOT / "bin" / "claude").read_text())
    shim_dst.chmod(shim_dst.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    path_dirs = [shim_dir, real_dir] if self_path_first else [real_dir, shim_dir]
    r = _run([], path_dirs)
    assert r.returncode == 0, r.stderr
    assert f"real_claude={real_dir / 'claude'}" in r.stdout
