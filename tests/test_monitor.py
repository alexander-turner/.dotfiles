"""Tests for .claude/hooks/monitor.bash — the AI safety trusted monitor.

Verifies that the monitor fails closed on missing dependencies, skips
correctly in disabled/sandbox/low-risk scenarios, warns once per session
when no API key is available, and produces valid hook JSON output.

All tests are offline — no real API calls.
"""

import json
import os
import subprocess
from pathlib import Path

REPO = Path(
    subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], text=True
    ).strip()
)
MONITOR = REPO / ".claude" / "hooks" / "monitor.bash"


def _run_monitor(
    envelope: dict,
    env_overrides: dict[str, str] | None = None,
) -> subprocess.CompletedProcess:
    """Run monitor.bash with the given envelope on stdin."""
    env = {
        **os.environ,
        "MONITOR_DISABLED": "0",
        "IS_SANDBOX": "",
        "ANTHROPIC_API_KEY": "",
        "VENICE_INFERENCE_KEY": "",
        "MONITOR_API_KEY": "",
        "MONITOR_PROVIDER": "",
        "MONITOR_LOG": "/dev/null",
    }
    if env_overrides:
        env.update(env_overrides)

    return subprocess.run(
        ["bash", str(MONITOR)],
        input=json.dumps(envelope),
        capture_output=True,
        text=True,
        env=env,
    )


def _make_envelope(
    tool_name: str = "Bash",
    tool_input: dict | None = None,
    session_id: str = "test-session",
) -> dict:
    return {
        "session_id": session_id,
        "tool_name": tool_name,
        "tool_input": tool_input or {"command": "ls"},
        "cwd": "/tmp/test-project",
    }


class TestDisabledPaths:
    def test_monitor_disabled_exits_clean(self) -> None:
        result = _run_monitor(
            _make_envelope(),
            env_overrides={"MONITOR_DISABLED": "1"},
        )
        assert result.returncode == 0
        assert result.stdout == ""

    def test_sandbox_exits_clean(self) -> None:
        result = _run_monitor(
            _make_envelope(),
            env_overrides={"IS_SANDBOX": "yes"},
        )
        assert result.returncode == 0
        assert result.stdout == ""

    def test_read_tool_skipped(self) -> None:
        result = _run_monitor(_make_envelope(tool_name="Read"))
        assert result.returncode == 0
        assert result.stdout == ""

    def test_custom_skip_tools(self) -> None:
        result = _run_monitor(
            _make_envelope(tool_name="Edit"),
            env_overrides={"MONITOR_SKIP_TOOLS": "Read:Edit:Agent"},
        )
        assert result.returncode == 0
        assert result.stdout == ""


class TestFailClosed:
    def test_missing_jq_blocks(self, tmp_path: Path) -> None:
        # Build a PATH with bash but not jq.
        bin_dir = tmp_path / "bin"
        bin_dir.mkdir()
        bash_real = Path("/usr/bin/bash")
        if not bash_real.exists():
            bash_real = Path("/bin/bash")
        (bin_dir / "bash").symlink_to(bash_real)
        (bin_dir / "cat").symlink_to("/usr/bin/cat")

        result = _run_monitor(
            _make_envelope(),
            env_overrides={"PATH": str(bin_dir)},
        )
        assert result.returncode == 2
        assert "MONITOR BLOCKED" in result.stderr
        assert "jq" in result.stderr

    def test_missing_curl_blocks(self, tmp_path: Path) -> None:
        # Build a PATH with bash + jq but not curl.
        bin_dir = tmp_path / "bin"
        bin_dir.mkdir()
        bash_real = Path("/usr/bin/bash")
        if not bash_real.exists():
            bash_real = Path("/bin/bash")
        (bin_dir / "bash").symlink_to(bash_real)
        (bin_dir / "cat").symlink_to("/usr/bin/cat")
        jq_real = subprocess.check_output(
            ["which", "jq"], text=True
        ).strip()
        (bin_dir / "jq").symlink_to(jq_real)

        result = _run_monitor(
            _make_envelope(),
            env_overrides={"PATH": str(bin_dir)},
        )
        assert result.returncode == 2
        assert "MONITOR BLOCKED" in result.stderr
        assert "curl" in result.stderr


class TestNoApiKey:
    def test_warns_once_per_session(self, tmp_path: Path) -> None:
        session_id = f"test-warn-{os.getpid()}"
        warned_file = Path(f"/tmp/claude-monitor-no-key-{session_id}")
        warned_file.unlink(missing_ok=True)

        try:
            result1 = _run_monitor(
                _make_envelope(session_id=session_id),
            )
            assert result1.returncode == 0
            output = json.loads(result1.stdout)
            assert output["hookSpecificOutput"]["permissionDecision"] == "ask"
            assert "INACTIVE" in output["hookSpecificOutput"]["permissionDecisionReason"]

            result2 = _run_monitor(
                _make_envelope(session_id=session_id),
            )
            assert result2.returncode == 0
            assert result2.stdout == ""
        finally:
            warned_file.unlink(missing_ok=True)


class TestProviderDetection:
    def test_anthropic_detected(self) -> None:
        result = _run_monitor(
            _make_envelope(),
            env_overrides={"ANTHROPIC_API_KEY": "sk-test-key"},
        )
        assert result.returncode == 0
        if result.stdout:
            output = json.loads(result.stdout)
            hook = output["hookSpecificOutput"]
            assert hook["permissionDecision"] in ("allow", "deny", "ask")
            assert "Monitor (" in hook["permissionDecisionReason"]

    def test_venice_detected(self) -> None:
        result = _run_monitor(
            _make_envelope(),
            env_overrides={"VENICE_INFERENCE_KEY": "ven-test-key"},
        )
        assert result.returncode == 0
        if result.stdout:
            output = json.loads(result.stdout)
            hook = output["hookSpecificOutput"]
            assert hook["permissionDecision"] in ("allow", "deny", "ask")
            assert "Monitor (" in hook["permissionDecisionReason"]

    def test_explicit_model_override(self) -> None:
        result = _run_monitor(
            _make_envelope(),
            env_overrides={
                "ANTHROPIC_API_KEY": "sk-test",
                "MONITOR_MODEL": "custom-model-123",
                "MONITOR_API_URL": "http://localhost:1/v1/messages",
                "MONITOR_TIMEOUT": "1",
            },
        )
        assert result.returncode == 0
        output = json.loads(result.stdout)
        assert "custom-model-123" in output["hookSpecificOutput"]["permissionDecisionReason"]

    def test_unknown_provider_blocks(self) -> None:
        result = _run_monitor(
            _make_envelope(),
            env_overrides={
                "MONITOR_PROVIDER": "unsupported",
                "MONITOR_API_KEY": "key",
            },
        )
        assert result.returncode == 2
        assert "MONITOR BLOCKED" in result.stderr


class TestOutputFormat:
    def test_valid_hook_json_on_api_failure(self) -> None:
        result = _run_monitor(
            _make_envelope(),
            env_overrides={
                "ANTHROPIC_API_KEY": "sk-invalid",
                "MONITOR_API_URL": "http://localhost:1/v1/messages",
                "MONITOR_TIMEOUT": "1",
                "MONITOR_FAIL_MODE": "deny",
            },
        )
        assert result.returncode == 0
        output = json.loads(result.stdout)
        hook = output["hookSpecificOutput"]
        assert hook["hookEventName"] == "PreToolUse"
        assert hook["permissionDecision"] == "deny"
        assert "API call failed" in hook["permissionDecisionReason"]

    def test_fail_mode_ask_is_default(self) -> None:
        result = _run_monitor(
            _make_envelope(),
            env_overrides={
                "ANTHROPIC_API_KEY": "sk-invalid",
                "MONITOR_API_URL": "http://localhost:1/v1/messages",
                "MONITOR_TIMEOUT": "1",
            },
        )
        assert result.returncode == 0
        output = json.loads(result.stdout)
        assert output["hookSpecificOutput"]["permissionDecision"] == "ask"
