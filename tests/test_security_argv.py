"""Regression test: macOS Keychain secrets must not transit argv.

`security add-generic-password -w "$value"` and
`security unlock-keychain -p "$pw"` used to put plaintext secrets on the
process argv (visible to any local user via `ps -eo args`). The fix
routes both calls through `security -i` (interactive mode reading from
stdin). These tests stub `security` to record its argv and stdin and
assert the secret stays on the stdin side of the divide.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def _make_security_stub(tmp_path: Path, exit_code: int = 0) -> tuple[Path, Path]:
    """Install a stub `security` on PATH that records argv and stdin separately.

    argv is recorded one arg per line so substring assertions can't
    accidentally match across arg boundaries.
    """
    argv_log = tmp_path / "argv.log"
    stdin_log = tmp_path / "stdin.log"
    stub = tmp_path / "security"
    stub.write_text(
        '#!/bin/bash\n'
        f'printf "%s\\n" "$@" >> "{argv_log}"\n'
        f'cat >> "{stdin_log}"\n'
        f'exit {exit_code}\n'
    )
    stub.chmod(0o755)
    return argv_log, stdin_log


def _bash(script: str, env: dict[str, str], check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["bash", "-c", script],
        env=env,
        check=check,
        cwd=REPO,
    )


def _argv_tokens(argv_log: Path) -> list[str]:
    return argv_log.read_text().splitlines()


def test_secret_set_security_backend_does_not_leak_value_to_argv(tmp_path: Path) -> None:
    argv_log, stdin_log = _make_security_stub(tmp_path)
    secret = "s3cret-tokn-DO-NOT-LEAK-9f8e7d"

    env = {
        **os.environ,
        "PATH": f"{tmp_path}{os.pathsep}{os.environ['PATH']}",
        "DOTFILES_SECRET_BACKEND": "security",
        "USER": "tester",
    }
    _bash(
        f'source "{REPO}/bin/lib/secret-store.sh"\n'
        f'secret_set my-service {secret!r}\n',
        env,
    )

    argv = _argv_tokens(argv_log)
    stdin_text = stdin_log.read_text()
    assert all(secret not in tok for tok in argv), f"secret leaked to argv: {argv!r}"
    assert argv == ["-i"], f"expected exactly `security -i`, got: {argv!r}"
    assert secret in stdin_text, f"secret missing from stdin: {stdin_text!r}"


def test_keychain_unlock_does_not_leak_password_to_argv(tmp_path: Path) -> None:
    argv_log, stdin_log = _make_security_stub(tmp_path)
    password = "p@ssw0rd-DO-NOT-LEAK-1a2b3c"

    env = {
        **os.environ,
        "PATH": f"{tmp_path}{os.pathsep}{os.environ['PATH']}",
    }
    _bash(
        f'source "{REPO}/bin/lib/keychain.sh"\n'
        f'_keychain_unlock {password!r} /fake/login.keychain-db\n',
        env,
    )

    argv = _argv_tokens(argv_log)
    stdin_text = stdin_log.read_text()
    assert all(password not in tok for tok in argv), f"password leaked to argv: {argv!r}"
    assert argv == ["-i"], f"expected exactly `security -i`, got: {argv!r}"
    assert password in stdin_text, f"password missing from stdin: {stdin_text!r}"


def test_keychain_unlock_propagates_failure_exit_code(tmp_path: Path) -> None:
    """`security -i` exits with the result of its last (only) command,
    so _keychain_unlock must surface unlock failure to its caller."""
    _make_security_stub(tmp_path, exit_code=42)

    env = {
        **os.environ,
        "PATH": f"{tmp_path}{os.pathsep}{os.environ['PATH']}",
    }
    result = _bash(
        f'source "{REPO}/bin/lib/keychain.sh"\n'
        '_keychain_unlock wrong-pw /fake/login.keychain-db\n',
        env,
        check=False,
    )
    # The stub exits 42; _keychain_unlock pipes into it, so the pipeline's
    # final exit code is 42 (pipefail isn't required — security is the last
    # stage). Caller can branch on it the same way the real code does.
    assert result.returncode == 42, f"expected rc=42, got rc={result.returncode}"


def test_security_quote_escapes_backslash_and_double_quote(tmp_path: Path) -> None:
    """Values containing " or \\ must round-trip through `security -i`'s parser."""
    argv_log, stdin_log = _make_security_stub(tmp_path)
    # A value the naive `printf '"%s"'` would mis-quote without escaping.
    tricky = 'has "quote" and \\backslash inside'

    env = {
        **os.environ,
        "PATH": f"{tmp_path}{os.pathsep}{os.environ['PATH']}",
        "DOTFILES_SECRET_BACKEND": "security",
        "USER": "tester",
    }
    _bash(
        f'source "{REPO}/bin/lib/secret-store.sh"\n'
        f'secret_set my-service {tricky!r}\n',
        env,
    )

    stdin_text = stdin_log.read_text()
    # Stdin should contain the escaped form: \" and \\ inside double quotes.
    assert r'\"quote\"' in stdin_text, f"unexpected stdin: {stdin_text!r}"
    assert r'\\backslash' in stdin_text, f"unexpected stdin: {stdin_text!r}"
