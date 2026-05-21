#!/bin/bash
# Shared linting script for both pre-push hook and CI
# Usage: lint.sh [--ci] [--fix]
#   --ci: CI mode - fail if tools missing, no colors
#   --fix: Auto-fix issues where possible (shellcheck, stylua)

set -euo pipefail

CI_MODE=false
FIX_MODE=false
for arg in "$@"; do
    case "$arg" in
    --ci) CI_MODE=true ;;
    --fix) FIX_MODE=true ;;
    esac
done

# Colors (disabled in CI mode)
if [[ "$CI_MODE" == true ]]; then
    RED='' GREEN='' YELLOW='' NC=''
else
    RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m' NC='\033[0m'
fi

# Change to repo root
cd "$(git rev-parse --show-toplevel)"

FAILED=0

require_or_skip() {
    local cmd="$1"
    local name="$2"
    if ! command -v "$cmd" &>/dev/null; then
        if [[ "$CI_MODE" == true ]]; then
            echo -e "${RED}$name: missing (required in CI)${NC}"
            FAILED=1
            return 1
        else
            echo -e "$name: ${YELLOW}skipped ($cmd not installed)${NC}"
            return 1
        fi
    fi
    return 0
}

# shfmt — formats shell scripts. Same set of files shellcheck inspects.
# Flags: -i 4 (4-space indent, matches existing style); no -ci (the repo
# uses un-indented case bodies).
check_shfmt() {
    require_or_skip shfmt "Shfmt" || return 0
    echo -n "Shfmt: "
    local shfmt_targets=(setup.sh bin/*.sh bin/lib/*.sh bin/dotfiles .hooks/*.sh .hooks/pre-push .hooks/pre-commit .hooks/commit-msg .claude/hooks/*.sh .bashrc)
    if [[ "$FIX_MODE" == true ]]; then
        shfmt -w -i 4 "${shfmt_targets[@]}" 2>/dev/null || true
        echo -e "${GREEN}fixed${NC}"
    else
        if shfmt -d -i 4 "${shfmt_targets[@]}" 2>/dev/null; then
            echo -e "${GREEN}passed${NC}"
        else
            echo -e "${RED}failed${NC}"
            return 1
        fi
    fi
}

# Shellcheck
check_shellcheck() {
    require_or_skip shellcheck "Shellcheck" || return 0
    echo -n "Shellcheck: "
    if [[ "$FIX_MODE" == true ]]; then
        local diff_output
        diff_output=$(shellcheck -e SC2016 --format=diff setup.sh bin/*.sh bin/lib/*.sh bin/dotfiles .hooks/*.sh .hooks/pre-push .hooks/pre-commit .hooks/commit-msg .claude/hooks/*.sh 2>/dev/null || true)
        diff_output+=$(shellcheck -s bash -e SC2148 -e SC1090 -e SC1091 -e SC2015 --format=diff .bashrc 2>/dev/null || true)
        if [ -n "$diff_output" ]; then
            echo "$diff_output" | git apply --allow-empty 2>/dev/null || true
            echo -e "${GREEN}fixed${NC}"
        else
            echo -e "${GREEN}passed${NC}"
        fi
    else
        if shellcheck -e SC2016 setup.sh bin/*.sh bin/lib/*.sh bin/dotfiles .hooks/*.sh .hooks/pre-push .hooks/pre-commit .hooks/commit-msg .claude/hooks/*.sh 2>/dev/null &&
            shellcheck -s bash -e SC2148 -e SC1090 -e SC1091 -e SC2015 .bashrc 2>/dev/null; then
            echo -e "${GREEN}passed${NC}"
        else
            echo -e "${RED}failed${NC}"
            return 1
        fi
    fi
}

# Fish syntax
check_fish() {
    require_or_skip fish "Fish syntax" || return 0
    echo -n "Fish syntax: "
    local fish_failed=0 err_output
    while IFS= read -r -d '' f; do
        if ! err_output=$(fish --no-execute "$f" 2>&1); then
            echo -e "\n  ${RED}Syntax error: $f${NC}"
            echo "  $err_output"
            fish_failed=1
        fi
    done < <(find . -name '*.fish' -not -path './apps/fish/functions/_tide*' -print0 2>/dev/null)
    if [ "$fish_failed" -ne 0 ]; then
        echo -e "${RED}failed${NC}"
        return 1
    fi
    echo -e "${GREEN}passed${NC}"
}

# StyLua
check_stylua() {
    require_or_skip stylua "Lua format" || return 0
    echo -n "Lua format: "
    if [[ "$FIX_MODE" == true ]]; then
        stylua . 2>/dev/null
        echo -e "${GREEN}fixed${NC}"
    else
        if stylua --check . 2>/dev/null; then
            echo -e "${GREEN}passed${NC}"
        else
            echo -e "${RED}failed${NC}"
            return 1
        fi
    fi
}

# YAML validation (includes .github/ workflows — they are standard YAML)
check_yaml() {
    require_or_skip yamllint "YAML validation" || return 0
    echo -n "YAML validation: "
    if ! find . \( -name '*.yml' -o -name '*.yaml' \) -not -path '*/node_modules/*' -print -quit 2>/dev/null | grep -q .; then
        echo -e "${GREEN}no files${NC}"
        return 0
    fi
    if find . \( -name '*.yml' -o -name '*.yaml' \) -not -path '*/node_modules/*' -print0 |
        xargs -0 yamllint -d "{extends: relaxed, rules: {line-length: disable}}" 2>/dev/null; then
        echo -e "${GREEN}passed${NC}"
    else
        echo -e "${RED}failed${NC}"
        return 1
    fi
}

# TOML validation
check_toml() {
    if ! python3 -c "import tomllib" 2>/dev/null; then
        if [[ "$CI_MODE" == true ]]; then
            echo -e "${RED}TOML validation: missing (requires Python 3.11+)${NC}"
            return 1
        else
            echo -e "TOML validation: ${YELLOW}skipped (Python 3.11+ required)${NC}"
            return 0
        fi
    fi
    echo -n "TOML validation: "
    if ! find . -name '*.toml' -not -path './.git/*' -not -path '*/node_modules/*' -print -quit 2>/dev/null | grep -q .; then
        echo -e "${GREEN}no files${NC}"
        return 0
    fi
    local toml_failed=0
    while IFS= read -r -d '' f; do
        if ! python3 -c "
import sys, tomllib
with open(sys.argv[1], 'rb') as fp:
    tomllib.load(fp)
" "$f"; then
            echo -e "\n  ${RED}Invalid: $f${NC}"
            toml_failed=1
        fi
    done < <(find . -name '*.toml' -not -path './.git/*' -not -path '*/node_modules/*' -print0 2>/dev/null)
    if [ $toml_failed -ne 0 ]; then
        echo -e "${RED}failed${NC}"
        return 1
    fi
    echo -e "${GREEN}passed${NC}"
}

# JSON validation
check_json() {
    require_or_skip python3 "JSON validation" || return 0
    echo -n "JSON validation: "
    # Exclude JSONC files (VSCode/VSCodium settings allow trailing commas)
    if ! find . -name '*.json' -not -path '*/node_modules/*' -not -path './.git/*' -not -path './apps/vscodium/*' -print -quit 2>/dev/null | grep -q .; then
        echo -e "${GREEN}no files${NC}"
        return 0
    fi
    local json_failed=0
    while IFS= read -r -d '' f; do
        if ! python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null; then
            echo -e "\n  ${RED}Invalid: $f${NC}"
            json_failed=1
        fi
    done < <(find . -name '*.json' -not -path '*/node_modules/*' -not -path './.git/*' -not -path './apps/vscodium/*' -print0 2>/dev/null)
    if [ $json_failed -ne 0 ]; then
        echo -e "${RED}failed${NC}"
        return 1
    fi
    echo -e "${GREEN}passed${NC}"
}

# Python lint
check_python() {
    require_or_skip ruff "Python lint" || return 0
    echo -n "Python lint: "
    if ! find . -name '*.py' -not -path './.git/*' -not -path '*/node_modules/*' -print -quit 2>/dev/null | grep -q .; then
        echo -e "${GREEN}no files${NC}"
        return 0
    fi
    if [[ "$FIX_MODE" == true ]]; then
        find . -name '*.py' -not -path './.git/*' -not -path '*/node_modules/*' -print0 |
            xargs -0 ruff check --fix 2>/dev/null || true
        echo -e "${GREEN}fixed${NC}"
    else
        if find . -name '*.py' -not -path './.git/*' -not -path '*/node_modules/*' -print0 |
            xargs -0 ruff check 2>/dev/null; then
            echo -e "${GREEN}passed${NC}"
        else
            echo -e "${RED}failed${NC}"
            return 1
        fi
    fi
}

# Secrets scan. bin/pre-push sets GITLEAKS_LOG_OPTS to narrow the scan to the
# push range; CI leaves it unset for a full-history scan. GITLEAKS_REQUIRED=1
# (also set by pre-push) flips missing-binary from SKIP to FAIL so the gate
# isn't silenceable by an unconfigured dev box.
check_gitleaks() {
    if ! command -v gitleaks >/dev/null 2>&1; then
        if [[ "${GITLEAKS_REQUIRED:-0}" == "1" ]]; then
            echo -e "${RED}Gitleaks: missing (required in pre-push — install via Brewfile)${NC}"
            return 1
        fi
        require_or_skip gitleaks "Gitleaks" || return 0
    fi
    echo -n "Gitleaks: "
    # `${arr[@]+"${arr[@]}"}` is the bash-3.2-safe expansion for an empty
    # array under `set -u` (macOS default bash trips on plain "${arr[@]}").
    local extra=()
    if [[ -n "${GITLEAKS_LOG_OPTS:-}" ]]; then
        extra=(--log-opts="$GITLEAKS_LOG_OPTS")
    fi
    if gitleaks detect --no-banner --redact --config=.gitleaks.toml ${extra[@]+"${extra[@]}"} >/dev/null 2>&1; then
        echo -e "${GREEN}passed${NC}"
    else
        echo -e "${RED}failed${NC}"
        echo "  Re-run for details: gitleaks detect --no-banner --redact --config=.gitleaks.toml ${GITLEAKS_LOG_OPTS:+--log-opts=\"$GITLEAKS_LOG_OPTS\"}" >&2
        return 1
    fi
}

# Pytest suites under tests/. Each runs in its own check so the failure
# line names the suite. Quiet on pass; surfaces full pytest output on fail.
_run_pytest_suite() {
    local label="$1" file="$2"
    require_or_skip pytest "$label" || return 0
    echo -n "$label: "
    local out
    if out="$(pytest -q "$file" 2>&1)"; then
        echo -e "${GREEN}passed${NC}"
    else
        echo -e "${RED}failed${NC}"
        printf '%s\n' "$out"
        return 1
    fi
}

check_safe_link_tests() {
    _run_pytest_suite "safe_link tests" "tests/test_safe_link.py"
}

check_claude_hook_tests() {
    _run_pytest_suite "Claude hook tests" "tests/test_claude_hooks.py"
}

# Run all checks
echo "Running lint checks..."
check_shfmt || FAILED=1
check_shellcheck || FAILED=1
check_fish || FAILED=1
check_stylua || FAILED=1
check_yaml || FAILED=1
check_toml || FAILED=1
check_json || FAILED=1
check_python || FAILED=1
check_gitleaks || FAILED=1
check_safe_link_tests || FAILED=1
check_claude_hook_tests || FAILED=1

if [ $FAILED -ne 0 ]; then
    echo -e "\n${RED}Lint checks failed.${NC}"
    exit 1
fi

echo -e "\n${GREEN}All checks passed!${NC}"
