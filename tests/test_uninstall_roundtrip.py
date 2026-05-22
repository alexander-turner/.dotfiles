"""Setup → uninstall round-trip.

Enforces CLAUDE.md's "Uninstall upkeep" invariant: every safe_link in setup.bash
whose target lives in $HOME has a matching remove in uninstall.bash (typically
via bin/lib/symlinks.sh). Scope matches uninstall.bash — symlinks only, not the
touch-files setup.bash creates.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

DOTFILES = Path(
    subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], text=True
    ).strip()
)


def _repo_symlinks(home: Path) -> list[Path]:
    """Symlinks under `home` that point into the dotfiles repo."""
    found: list[Path] = []
    for root, dirs, files in os.walk(home, followlinks=False):
        for name in (*dirs, *files):
            p = Path(root) / name
            if p.is_symlink() and os.readlink(p).startswith(f"{DOTFILES}{os.sep}"):
                found.append(p)
    return sorted(found)


def _run(script: str, *args: str, home: Path) -> None:
    subprocess.run(
        ["bash", str(DOTFILES / script), *args],
        env={**os.environ, "HOME": str(home)},
        check=True,
    )


def test_uninstall_removes_every_setup_symlink(tmp_path: Path) -> None:
    _run("setup.bash", "--link-only", home=tmp_path)
    installed = _repo_symlinks(tmp_path)
    assert installed, "setup.bash --link-only produced zero repo symlinks — test is no longer testing anything"

    _run("bin/uninstall.bash", "--yes", home=tmp_path)
    leftover = _repo_symlinks(tmp_path)
    assert not leftover, (
        "uninstall.bash left repo-pointing symlinks in $HOME. Likely cause: a "
        "safe_link in setup.bash has no matching entry in bin/lib/symlinks.sh. "
        f"Leftover: {leftover}"
    )
