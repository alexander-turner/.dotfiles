"""Tests for .claude/hooks/monitor.bash — the AI safety trusted monitor.

All tests are offline — no real API calls.
"""

import json
import os
import subprocess
from pathlib import Path

import pytest

REPO = Path(
    subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
)
MONITOR = REPO / ".claude" / "hooks" / "monitor.bash"

CLEAN_ENV = {
    "MONITOR_DISABLED": "0",
    "IS_SANDBOX": "",
    "ANTHROPIC_API_KEY": "",
    "VENICE_INFERENCE_KEY": "",
    "MONITOR_API_KEY": "",
    "MONITOR_PROVIDER": "",
    "MONITOR_LOG": "/dev/null",
}


def _run(envelope: dict, **env_overrides: str) -> subprocess.CompletedProcess:
    env = {**os.environ, **CLEAN_ENV, **env_overrides}
    return subprocess.run(
        ["bash", str(MONITOR)],
        input=json.dumps(envelope),
        capture_output=True,
        text=True,
        env=env,
    )


def _envelope(
    tool: str = "Bash", cmd: str = "ls", session_id: str = "test-session"
) -> dict:
    return {
        "session_id": session_id,
        "tool_name": tool,
        "tool_input": {"command": cmd},
        "cwd": "/tmp/test-project",
    }


def _fake_path(tmp_path: Path, bins: list[str]) -> str:
    d = tmp_path / "bin"
    d.mkdir()
    for b in ["bash", "cat"]:
        src = Path(f"/usr/bin/{b}")
        if not src.exists():
            src = Path(f"/bin/{b}")
        (d / b).symlink_to(src)
    for b in bins:
        real = subprocess.check_output(["which", b], text=True).strip()
        (d / b).symlink_to(real)
    return str(d)


# --- Silent skip paths ---


@pytest.mark.parametrize(
    "env",
    [
        {"MONITOR_DISABLED": "1"},
        {"IS_SANDBOX": "yes"},
    ],
)
def test_disabled_exits_clean(env: dict[str, str]) -> None:
    r = _run(_envelope(), **env)
    assert r.returncode == 0 and r.stdout == ""


@pytest.mark.parametrize("tool", ["Read", "Edit"])
def test_skip_tools(tool: str) -> None:
    r = _run(_envelope(tool=tool), MONITOR_SKIP_TOOLS="Read:Edit:Agent")
    assert r.returncode == 0 and r.stdout == ""


# --- Fail closed ---


def test_missing_jq_blocks(tmp_path: Path) -> None:
    r = _run(_envelope(), PATH=_fake_path(tmp_path, []))
    assert r.returncode == 2 and "jq" in r.stderr


def test_missing_curl_blocks(tmp_path: Path) -> None:
    r = _run(_envelope(), PATH=_fake_path(tmp_path, ["jq"]))
    assert r.returncode == 2 and "curl" in r.stderr


def test_unknown_provider_blocks() -> None:
    r = _run(_envelope(), MONITOR_PROVIDER="unsupported", MONITOR_API_KEY="key")
    assert r.returncode == 2


# --- No API key warning ---


def test_warns_once_per_session() -> None:
    sid = f"test-warn-{os.getpid()}"
    warned = Path(f"/tmp/claude-monitor-no-key-{sid}")
    warned.unlink(missing_ok=True)
    try:
        r1 = _run(_envelope(session_id=sid))
        assert r1.returncode == 0
        out = json.loads(r1.stdout)
        assert out["hookSpecificOutput"]["permissionDecision"] == "ask"
        assert "INACTIVE" in out["hookSpecificOutput"]["permissionDecisionReason"]

        r2 = _run(_envelope(session_id=sid))
        assert r2.returncode == 0 and r2.stdout == ""
    finally:
        warned.unlink(missing_ok=True)


# --- Provider detection + output format ---


@pytest.mark.parametrize(
    "key_env,key_val",
    [("ANTHROPIC_API_KEY", "sk-test"), ("VENICE_INFERENCE_KEY", "ven-test")],
)
def test_provider_detected(key_env: str, key_val: str) -> None:
    r = _run(_envelope(), **{key_env: key_val})
    assert r.returncode == 0
    if r.stdout:
        assert "Monitor (" in json.loads(r.stdout)["hookSpecificOutput"]["permissionDecisionReason"]


def test_explicit_model_override() -> None:
    r = _run(
        _envelope(),
        ANTHROPIC_API_KEY="sk-test",
        MONITOR_MODEL="custom-model-123",
        MONITOR_API_URL="http://localhost:1/v1/messages",
        MONITOR_TIMEOUT="1",
    )
    assert r.returncode == 0
    assert "custom-model-123" in json.loads(r.stdout)["hookSpecificOutput"]["permissionDecisionReason"]


def test_api_failure_defaults_to_deny() -> None:
    r = _run(
        _envelope(),
        ANTHROPIC_API_KEY="sk-invalid",
        MONITOR_API_URL="http://localhost:1/v1/messages",
        MONITOR_TIMEOUT="1",
    )
    assert r.returncode == 0
    hook = json.loads(r.stdout)["hookSpecificOutput"]
    assert hook["hookEventName"] == "PreToolUse"
    assert hook["permissionDecision"] == "deny"
    assert "API call failed" in hook["permissionDecisionReason"]


@pytest.mark.parametrize("fail_mode", ["allow", "ask"])
def test_api_failure_respects_override(fail_mode: str) -> None:
    r = _run(
        _envelope(),
        ANTHROPIC_API_KEY="sk-invalid",
        MONITOR_API_URL="http://localhost:1/v1/messages",
        MONITOR_TIMEOUT="1",
        MONITOR_FAIL_MODE=fail_mode,
    )
    assert r.returncode == 0
    assert json.loads(r.stdout)["hookSpecificOutput"]["permissionDecision"] == fail_mode
