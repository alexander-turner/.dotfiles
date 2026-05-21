#!/usr/bin/env bash
# Test harness for .claude/hooks/ scripts. Exercises each hook with synthetic
# env in a temp dir and asserts exit code + key output patterns.
#
# Run locally:  bash bin/test-claude-hooks.sh
# In CI:        same command — non-interactive, no network calls.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.claude/hooks"

PASS=0
FAIL=0
FAILURES=()

# Run a single test case in an isolated temp dir.
#   $1 = test name
#   $2 = bash snippet to evaluate (must set $expected_rc and may set $expected_match);
#        the snippet runs the hook and captures stdout+stderr into $output and exit
#        code into $rc.
run_test() {
    local name="$1" snippet="$2"
    local tmpdir
    tmpdir=$(mktemp -d -t claude-hooks-test-XXXXXX)
    (
        cd "$tmpdir"
        local output rc expected_rc=0 expected_match=""
        eval "$snippet" || true
        if [ "$rc" != "$expected_rc" ]; then
            echo "FAIL: $name (rc=$rc, expected=$expected_rc)" >&2
            echo "----- output -----" >&2
            echo "$output" >&2
            echo "------------------" >&2
            exit 1
        fi
        if [ -n "$expected_match" ] && ! grep -qE "$expected_match" <<<"$output"; then
            echo "FAIL: $name (output didn't match /$expected_match/)" >&2
            echo "----- output -----" >&2
            echo "$output" >&2
            echo "------------------" >&2
            exit 1
        fi
    )
    local subshell_rc=$?
    rm -rf "$tmpdir"
    if [ "$subshell_rc" -eq 0 ]; then
        echo "PASS: $name"
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        FAILURES+=("$name")
    fi
}

# --- session-setup.sh ---

run_test "session-setup: empty repo, no env -> exit 0" '
    git init -q
    output=$(CLAUDE_PROJECT_DIR="$PWD" bash "'"$HOOKS_DIR"'/session-setup.sh" 2>&1)
    rc=$?
    expected_rc=0
'

run_test "session-setup: proxy-URL remote -> exports GH_REPO via CLAUDE_ENV_FILE" '
    git init -q
    git remote add origin "http://local_proxy@127.0.0.1:18393/git/foo/bar"
    env_file=$(mktemp)
    output=$(env -u GH_REPO CLAUDE_PROJECT_DIR="$PWD" CLAUDE_ENV_FILE="$env_file" \
        bash "'"$HOOKS_DIR"'/session-setup.sh" 2>&1)
    rc=$?
    expected_rc=0
    output+=$'\''\n--ENVFILE--\n'\''$(cat "$env_file")
    rm -f "$env_file"
    expected_match="GH_REPO=\"foo/bar\""
'

run_test "session-setup: github.com remote attempts set-default (warn is fine)" '
    git init -q
    git remote add origin "https://github.com/owner/repo.git"
    unset GH_REPO
    output=$(CLAUDE_PROJECT_DIR="$PWD" GH_REPO="owner/repo" \
        bash "'"$HOOKS_DIR"'/session-setup.sh" 2>&1)
    rc=$?
    expected_rc=0
'

# --- pre-push-check.sh ---

run_test "pre-push-check: no package.json, no pyproject -> exit 0, no output" '
    git init -q
    output=$(CLAUDE_PROJECT_DIR="$PWD" bash "'"$HOOKS_DIR"'/pre-push-check.sh" 2>&1)
    rc=$?
    expected_rc=0
'

run_test "pre-push-check: package.json with failing lint -> exit 1" '
    git init -q
    cat >package.json <<JSON
{"scripts":{"lint":"false"}}
JSON
    output=$(CLAUDE_PROJECT_DIR="$PWD" bash "'"$HOOKS_DIR"'/pre-push-check.sh" 2>&1)
    rc=$?
    expected_rc=1
    expected_match="lint FAILED"
'

run_test "pre-push-check: package.json with placeholder script -> skipped" '
    git init -q
    cat >package.json <<JSON
{"scripts":{"lint":"echo ERROR: Configure your linter"}}
JSON
    output=$(CLAUDE_PROJECT_DIR="$PWD" bash "'"$HOOKS_DIR"'/pre-push-check.sh" 2>&1)
    rc=$?
    expected_rc=0
'

# --- notify.sh ---

run_test "notify.sh: JSON on stdin -> exit 0 (no-op without notifier)" '
    output=$(echo '\''{"message":"hi"}'\'' | bash "'"$HOOKS_DIR"'/notify.sh" 2>&1)
    rc=$?
    expected_rc=0
'

run_test "notify.sh: no stdin -> falls back to default message, exit 0" '
    output=$(bash "'"$HOOKS_DIR"'/notify.sh" </dev/null 2>&1)
    rc=$?
    expected_rc=0
'

# --- scan-input.sh ---

run_test "scan-input: clean prompt -> exit 0" '
    output=$(echo '\''{"prompt":"refactor the doctor script"}'\'' \
        | bash "'"$HOOKS_DIR"'/scan-input.sh" 2>&1)
    rc=$?
    expected_rc=0
'

run_test "scan-input: AWS-shaped key in prompt -> exit 2 (refuse)" '
    output=$(echo '\''{"prompt":"please rotate AKIAIOSFODNN7EXAMPLE before deploy"}'\'' \
        | bash "'"$HOOKS_DIR"'/scan-input.sh" 2>&1)
    rc=$?
    expected_rc=2
    expected_match="refused"
'

run_test "scan-input: AWS-shaped key with CLAUDE_ALLOW_SECRETS=1 -> exit 0" '
    output=$(echo '\''{"prompt":"AKIAIOSFODNN7EXAMPLE"}'\'' \
        | CLAUDE_ALLOW_SECRETS=1 bash "'"$HOOKS_DIR"'/scan-input.sh" 2>&1)
    rc=$?
    expected_rc=0
'

run_test "scan-input: missing prompt field -> exit 0 (soft-fail)" '
    output=$(echo '\''{}'\'' | bash "'"$HOOKS_DIR"'/scan-input.sh" 2>&1)
    rc=$?
    expected_rc=0
'

# --- audit-log.sh ---

run_test "audit-log: writes a jsonl line to ~/.claude/audit/" '
    fake_home=$(mktemp -d)
    output=$(echo '\''{"tool_name":"Read","tool_input":{"file_path":"/x"},"tool_response":"ok"}'\'' \
        | HOME="$fake_home" bash "'"$HOOKS_DIR"'/audit-log.sh" 2>&1)
    rc=$?
    expected_rc=0
    line_count=$(find "$fake_home/.claude/audit" -name "*.jsonl" -exec wc -l {} + 2>/dev/null \
        | awk "END{print \$1+0}")
    output+=$'\''\n--lines--\n'\''"$line_count"
    rm -rf "$fake_home"
    expected_match="^1$|--lines--[[:space:]]*1"
'

run_test "audit-log: missing HOME tree -> still exits 0 (best-effort)" '
    fake_home=$(mktemp -d)
    chmod 000 "$fake_home" || true
    output=$(echo '\''{}'\'' | HOME="$fake_home" bash "'"$HOOKS_DIR"'/audit-log.sh" 2>&1)
    rc=$?
    expected_rc=0
    chmod 700 "$fake_home" 2>/dev/null || true
    rm -rf "$fake_home"
'

# --- notify-dangerous.sh: removed; destructive Bash is blocked via
# permissions.deny in .claude/settings.json, no script needed.

# --- statusline.sh ---

run_test "statusline: well-formed payload -> prints model + cwd" '
    output=$(echo '\''{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/tmp"}}'\'' \
        | bash "'"$HOOKS_DIR"'/statusline.sh" 2>&1)
    rc=$?
    expected_rc=0
    expected_match="Opus.*/tmp"
'

run_test "statusline: empty stdin -> still prints a line" '
    output=$(bash "'"$HOOKS_DIR"'/statusline.sh" </dev/null 2>&1)
    rc=$?
    expected_rc=0
    expected_match="claude"
'

echo
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    printf '  - %s\n' "${FAILURES[@]}" >&2
    exit 1
fi
