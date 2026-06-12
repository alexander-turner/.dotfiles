"""bin/tailscale-set-exit-node.bash — exit-code, stderr, and menu.log contract.

SwiftBar invokes this script detached, so its menu.log lines and distinct
exit codes (2 invalid target, 4 daemon unhealthy, 127 no CLI) are the only
observable failure surface. A stubbed `tailscale` on PATH drives it.
"""

import os
import stat
import subprocess
from pathlib import Path

import pytest

DOTFILES = Path(
    subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
)
SCRIPT = DOTFILES / "bin" / "tailscale-set-exit-node.bash"

# find_tailscale prefers /opt/homebrew and /usr/local over PATH, so on a
# machine with a real CLI the stub would be shadowed and the test would
# drive the user's actual VPN. Never do that.
REAL_CLI = any(
    Path(p).exists()
    for p in ("/opt/homebrew/bin/tailscale", "/usr/local/bin/tailscale")
)
pytestmark = pytest.mark.skipif(
    REAL_CLI, reason="real tailscale CLI would shadow the stub"
)


def _run(tmp_path: Path, target: str, status_out: str = "", status_rc: int = 0):
    """Run the script against a stub CLI; return (proc, menu.log text, set args)."""
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)
    args_file = tmp_path / "set-args"
    stub = bin_dir / "tailscale"
    stub.write_text(
        "#!/bin/sh\n"
        'case "$1" in\n'
        "version) echo 1.86.0; exit 0 ;;\n"
        f'status) cat <<"TS_EOF"\n{status_out}\nTS_EOF\nexit {status_rc} ;;\n'
        f'set) shift; printf \'%s\\n\' "$@" >"{args_file}"; exit 0 ;;\n'
        "esac\n"
    )
    stub.chmod(stub.stat().st_mode | stat.S_IXUSR)
    proc = subprocess.run(
        ["bash", str(SCRIPT), target],
        env={
            **os.environ,
            "HOME": str(tmp_path),
            "PATH": f"{bin_dir}:{os.environ['PATH']}",
        },
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
        timeout=10,
    )
    menu_log = tmp_path / "Library/Logs/com.turntrout.tailscale-exit-node/menu.log"
    log = menu_log.read_text() if menu_log.exists() else ""
    set_args = args_file.read_text().split() if args_file.exists() else None
    return proc, log, set_args


def test_invalid_target_exits_2_and_lists_valid_codes(tmp_path: Path) -> None:
    proc, log, set_args = _run(tmp_path, "param1=ca")
    assert proc.returncode == 2
    assert "valid: off" in proc.stderr and "ca" in proc.stderr
    assert "FAIL" in log
    assert set_args is None


def test_logged_out_exits_4_with_remediation(tmp_path: Path) -> None:
    proc, log, set_args = _run(tmp_path, "ca", "Logged out.", 1)
    assert proc.returncode == 4
    assert "tailscale up" in proc.stderr
    assert "tailscale up" in log
    assert set_args is None, "must not call `tailscale set` on an unhealthy daemon"


def test_healthy_set_passes_node_and_lan_flag(tmp_path: Path) -> None:
    proc, log, set_args = _run(tmp_path, "ca", "100.64.0.1 mac turntrout@ macOS -")
    assert proc.returncode == 0, proc.stderr
    assert "ca-mtr-wg-001.mullvad.ts.net" in log
    assert set_args == [
        "--exit-node=ca-mtr-wg-001.mullvad.ts.net",
        "--exit-node-allow-lan-access=true",
    ]


def test_off_clears_exit_node_without_lan_flag(tmp_path: Path) -> None:
    proc, log, set_args = _run(tmp_path, "off", "100.64.0.1 mac turntrout@ macOS -")
    assert proc.returncode == 0, proc.stderr
    assert "off" in log
    assert set_args == ["--exit-node="]
