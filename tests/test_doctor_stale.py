"""bin/lib/stale-symlinks.sh — rename-leftover detection.

Drives the lib directly (not the full doctor.bash) so the test stays a
sub-second pure-logic check instead of an integration run that spawns bw,
brew, gh, launchctl, etc.
"""

import os
import subprocess
from pathlib import Path

import pytest

DOTFILES = Path(
    subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
)
STALE_SH = DOTFILES / "bin" / "lib" / "stale-symlinks.sh"


def _run_stale(home: Path) -> str:
    proc = subprocess.run(
        ["bash", str(STALE_SH)],
        env={**os.environ, "HOME": str(home)},
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
        timeout=5,
    )
    # A crash (bad source, syntax error) yields empty stdout, which would make
    # the flagged=False cases pass vacuously. Fail loudly instead.
    assert proc.returncode == 0, (
        f"stale-symlinks.sh exited {proc.returncode}\n"
        f"stdout: {proc.stdout!r}\nstderr: {proc.stderr!r}"
    )
    return proc.stdout


@pytest.mark.parametrize(
    "target_kind,flagged",
    [
        ("repo_missing", True),
        ("repo_present", False),
        ("outside_repo", False),
    ],
)
def test_stale_detection(tmp_path: Path, target_kind: str, flagged: bool) -> None:
    parent = tmp_path / ".config" / "mods"
    parent.mkdir(parents=True)
    rogue = parent / "rogue.yml"
    targets = {
        "repo_missing": DOTFILES / "apps" / "mods" / "does-not-exist.yml",
        "repo_present": DOTFILES / "apps" / "mods" / "mods.yml",
        "outside_repo": tmp_path / "not-in-repo.yml",
    }
    rogue.symlink_to(targets[target_kind])

    out = _run_stale(tmp_path)
    assert (str(rogue) in out) is flagged
