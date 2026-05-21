"""Tests for bin/lib/safe_link.sh — the only function that touches user files.

Invoked from bin/lint.bash (check_safe_link_tests). Pytest's fixtures + assertion
rewriting express the same coverage in roughly half the lines a shell harness
would need.
"""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
SAFE_LINK_SH = REPO_ROOT / "bin" / "lib" / "safe_link.sh"
STAMP_RE = re.compile(r"^\d{8}T\d{6}Z$")


@pytest.fixture
def home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """Isolated HOME + backup root. Clearing SAFE_LINK_BACKUP_STAMP makes
    each test simulate a fresh shell session."""
    h = tmp_path / "home"
    h.mkdir()
    monkeypatch.setenv("HOME", str(h))
    monkeypatch.setenv("SAFE_LINK_BACKUP_ROOT", str(tmp_path / "backups"))
    monkeypatch.delenv("SAFE_LINK_BACKUP_STAMP", raising=False)
    return h


def run_script(src: Path, tgt: Path, *, stdin: str | None = None) -> int:
    """Invoke safe_link.sh as a script — the entry point setup.bash uses."""
    return subprocess.run(
        ["bash", str(SAFE_LINK_SH), str(src), str(tgt)],
        input=stdin, capture_output=True, text=True,
    ).returncode


def source_and_run(snippet: str) -> subprocess.CompletedProcess[str]:
    """Source the lib and run a snippet — needed for tests that exercise
    _safe_link_backup directly or rely on shared SAFE_LINK_BACKUP_STAMP state."""
    return subprocess.run(
        ["bash", "-c", f"source {SAFE_LINK_SH}; {snippet}"],
        capture_output=True, text=True,
    )


def stamp_dirs() -> list[Path]:
    root = Path(os.environ["SAFE_LINK_BACKUP_ROOT"])
    return sorted(root.iterdir()) if root.exists() else []


def test_already_correct_symlink_is_noop(home: Path, tmp_path: Path) -> None:
    src = tmp_path / "source"
    src.write_text("x")
    tgt = home / ".foo"
    tgt.symlink_to(src)
    assert run_script(src, tgt) == 0
    assert os.readlink(tgt) == str(src)
    assert stamp_dirs() == []


def test_stale_symlink_relinked_atomically(home: Path, tmp_path: Path) -> None:
    src = tmp_path / "source"
    other = tmp_path / "other"
    src.write_text("x")
    other.write_text("y")
    tgt = home / ".foo"
    tgt.symlink_to(other)
    assert run_script(src, tgt) == 0
    assert os.readlink(tgt) == str(src)
    # Symlinks aren't user data, so no backup.
    assert stamp_dirs() == []


def test_real_file_backed_up_before_clobber(home: Path) -> None:
    """Data-preservation contract — exercised through _safe_link_backup
    directly because the prompted overwrite branch needs a real PTY."""
    tgt = home / ".foo"
    tgt.write_text("user-data-do-not-lose")
    result = source_and_run(f'_safe_link_backup "{tgt}"')
    assert result.returncode == 0, result.stderr
    assert not tgt.exists(), "original must be moved, not copied"
    [stamp] = stamp_dirs()
    assert STAMP_RE.match(stamp.name), f"backup dir '{stamp.name}' not UTC ISO 8601"
    assert (stamp / ".foo").read_text() == "user-data-do-not-lose"


def test_same_session_backups_share_stamp(home: Path) -> None:
    """uninstall.bash's "restore from latest" depends on every file clobbered
    in one setup.bash run landing under the same UTC stamp dir."""
    (home / ".a").write_text("a-data")
    (home / ".b").write_text("b-data")
    result = source_and_run(
        f'_safe_link_backup "{home}/.a"; _safe_link_backup "{home}/.b"'
    )
    assert result.returncode == 0, result.stderr
    [stamp] = stamp_dirs()
    assert (stamp / ".a").read_text() == "a-data"
    assert (stamp / ".b").read_text() == "b-data"


def test_missing_source_creates_dangling_link(home: Path, tmp_path: Path) -> None:
    """nvim's bootstrap flow and others rely on ln -sf accepting missing sources."""
    src = tmp_path / "does-not-exist"
    tgt = home / ".foo"
    assert run_script(src, tgt) == 0
    assert os.readlink(tgt) == str(src)


def test_two_runs_are_idempotent(home: Path, tmp_path: Path) -> None:
    src = tmp_path / "source"
    src.write_text("x")
    tgt = home / ".foo"
    assert run_script(src, tgt) == 0
    assert run_script(src, tgt) == 0
    assert os.readlink(tgt) == str(src)
    assert stamp_dirs() == []


def test_non_interactive_skips_real_file_silently(home: Path, tmp_path: Path) -> None:
    """CI idempotency depends on setup.bash's closed-stdin runs not blocking
    or tripping set -e on the overwrite prompt."""
    src = tmp_path / "source"
    src.write_text("x")
    tgt = home / ".foo"
    tgt.write_text("user-data")
    # stdin="" with no real TTY trips `[ ! -t 0 ]` → silent skip.
    assert run_script(src, tgt, stdin="") == 0
    assert not tgt.is_symlink()
    assert tgt.read_text() == "user-data"
    assert stamp_dirs() == []
