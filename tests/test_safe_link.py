"""Tests for bin/lib/safe_link.sh — the only function that touches user files.

Invoked from bin/lint.bash (check_safe_link_tests). Pytest's fixtures + assertion
rewriting express the same coverage in roughly half the lines a shell harness
would need.
"""

import fcntl
import os
import pty
import re
import subprocess
import termios
import time
from pathlib import Path

import pytest

REPO_ROOT = Path(
    subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], text=True
    ).strip()
)
SAFE_LINK_SH = REPO_ROOT / "bin" / "lib" / "safe_link.sh"
STAMP_RE = re.compile(r"^\d{8}T\d{6}Z$")


def _openpty_or_skip() -> tuple[int, int]:
    """pty.openpty() can fail with 'out of pty devices' when the system-wide
    kernel pty cap (kern.tty.maxptys) is saturated by other terminals/tmux.
    Retry briefly, then skip — this is environmental, not a real regression."""
    last_exc: OSError | None = None
    for _ in range(5):
        try:
            return pty.openpty()
        except OSError as e:
            last_exc = e
            time.sleep(0.1)
    pytest.skip(f"pty.openpty() unavailable: {last_exc}")
    raise AssertionError("unreachable")


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
    """Invoke safe_link.sh as a script — the entry point setup.bash uses.

    start_new_session=True detaches the child from pytest's controlling
    terminal so safe_link's /dev/tty open fails (the non-interactive path)."""
    return subprocess.run(
        ["bash", str(SAFE_LINK_SH), str(src), str(tgt)],
        input=stdin, capture_output=True, text=True,
        start_new_session=True,
    ).returncode


def source_and_run(snippet: str) -> subprocess.CompletedProcess[str]:
    """Source the lib and run a snippet — needed for tests that exercise
    _safe_link_backup directly or rely on shared SAFE_LINK_BACKUP_STAMP state."""
    return subprocess.run(
        ["bash", "-c", f"source {SAFE_LINK_SH}; {snippet}"],
        capture_output=True, text=True,
    )


def run_with_pty(
    src: Path, tgt: Path, *, answer: bytes, timeout: float = 2.0
) -> tuple[int, bytes]:
    """Invoke safe_link with stdin=/dev/null but a controlling pty available
    on /dev/tty — what setup.bash sees inside `while ... done < <(...)`.
    Returns (returncode, captured_pty_output)."""
    master, slave = _openpty_or_skip()

    def _make_pty_controlling() -> None:
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    try:
        os.write(master, answer)
        proc = subprocess.Popen(
            ["bash", str(SAFE_LINK_SH), str(src), str(tgt)],
            stdin=subprocess.DEVNULL,
            stdout=slave,
            stderr=slave,
            preexec_fn=_make_pty_controlling,
            close_fds=True,
        )
        os.close(slave)
        try:
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        os.set_blocking(master, False)
        captured = bytearray()
        while True:
            try:
                chunk = os.read(master, 4096)
            except (BlockingIOError, OSError):
                break
            if not chunk:
                break
            captured.extend(chunk)
        return proc.returncode, bytes(captured)
    finally:
        for fd in (master, slave):
            try:
                os.close(fd)
            except OSError:
                pass


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


def test_piped_stdin_with_tty_prompts_via_tty_and_overwrites(
    home: Path, tmp_path: Path
) -> None:
    """When stdin is a pipe but a controlling terminal is available
    (setup.bash's `while ... done < <(managed_symlinks)` from an
    interactive shell), safe_link must prompt via /dev/tty and proceed
    on 'y'."""
    src = tmp_path / "source"
    src.write_text("new")
    tgt = home / ".foo"
    tgt.write_text("user-data")
    rc, output = run_with_pty(src, tgt, answer=b"y\n")
    assert rc == 0
    assert tgt.is_symlink()
    assert os.readlink(tgt) == str(src)
    [stamp] = stamp_dirs()
    assert (stamp / ".foo").read_text() == "user-data"
    # Prompt must disambiguate by path, not just basename — two managed
    # symlinks (apps/ssh/config, apps/mods/config) both bottom out as "config".
    # Both target and source get ~-collapsed when they live under $HOME.
    assert b"~/.foo already exists" in output, output
    # `src` from tmp_path is not under $HOME, so it stays absolute here.
    assert str(src).encode() in output, output


def test_non_interactive_skips_real_file_silently(home: Path, tmp_path: Path) -> None:
    """CI idempotency depends on setup.bash's closed-stdin runs not blocking
    or tripping set -e on the overwrite prompt."""
    src = tmp_path / "source"
    src.write_text("x")
    tgt = home / ".foo"
    tgt.write_text("user-data")
    assert run_script(src, tgt, stdin="") == 0
    assert not tgt.is_symlink()
    assert tgt.read_text() == "user-data"
    assert stamp_dirs() == []
