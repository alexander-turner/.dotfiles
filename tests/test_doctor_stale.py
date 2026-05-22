"""doctor.bash: stale-symlink detection.

Catches rename-leftovers like ~/.config/swiftbar/vpn.10s.sh -> .../vpn.10s.sh
that the managed list no longer references.
"""

import os
import subprocess
from pathlib import Path

import pytest

DOTFILES = Path(
    subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
)


def _run_doctor(home: Path) -> str:
    return subprocess.run(
        ["bash", str(DOTFILES / "bin" / "doctor.bash")],
        env={**os.environ, "HOME": str(home)},
        capture_output=True,
        text=True,
    ).stdout


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

    out = _run_doctor(tmp_path)
    assert ("stale symlink" in out and "rogue.yml" in out) is flagged
