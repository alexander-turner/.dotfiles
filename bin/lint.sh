#!/bin/bash
# Shared linting script for both pre-push hook and CI
# Usage: lint.sh [--ci]
#   --ci: CI mode - fail if tools missing, no colors

set -e

CI_MODE=false
if [[ "$1" == "--ci" ]]; then
    CI_MODE=true
fi

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
    if ! command -v "$cmd" &> /dev/null; then
        if [[ "$CI_MODE" == true ]]; then
            echo -e "${RED}$name: missing (required in CI)${NC}"
            return 1
        else
            echo -e "$name: ${YELLOW}skipped ($cmd not installed)${NC}"
            return 1
        fi
    fi
    return 0
}

# Shellcheck
check_shellcheck() {
    require_or_skip shellcheck "Shellcheck" || return 0
    echo -n "Shellcheck: "
    if shellcheck -e SC2016 setup.sh bin/*.sh 2>/dev/null && \
       shellcheck -s bash -e SC2148 -e SC1090 -e SC1091 -e SC2015 .bashrc 2>/dev/null; then
        echo -e "${GREEN}passed${NC}"
    else
        echo -e "${RED}failed${NC}"
        return 1
    fi
}

# Fish syntax
check_fish() {
    require_or_skip fish "Fish syntax" || return 0
    echo -n "Fish syntax: "
    if find . -name '*.fish' -not -path './apps/fish/functions/_tide*' -exec fish --no-execute {} \; 2>/dev/null; then
        echo -e "${GREEN}passed${NC}"
    else
        echo -e "${RED}failed${NC}"
        return 1
    fi
}

# StyLua
check_stylua() {
    require_or_skip stylua "Lua format" || return 0
    echo -n "Lua format: "
    if stylua --check . 2>/dev/null; then
        echo -e "${GREEN}passed${NC}"
    else
        echo -e "${RED}failed${NC}"
        return 1
    fi
}

# YAML validation
check_yaml() {
    require_or_skip yamllint "YAML validation" || return 0
    echo -n "YAML validation: "
    YAML_FILES=$(find . -name '*.yml' -o -name '*.yaml' | grep -v '.github/' || true)
    if [ -z "$YAML_FILES" ]; then
        echo -e "${GREEN}no files${NC}"
        return 0
    fi
    if echo "$YAML_FILES" | xargs yamllint -d "{extends: relaxed, rules: {line-length: disable}}" 2>/dev/null; then
        echo -e "${GREEN}passed${NC}"
    else
        echo -e "${RED}failed${NC}"
        return 1
    fi
}

# TOML validation
check_toml() {
    if ! python3 -c "import toml" 2>/dev/null; then
        if [[ "$CI_MODE" == true ]]; then
            echo -e "${RED}TOML validation: missing (required in CI)${NC}"
            return 1
        else
            echo -e "TOML validation: ${YELLOW}skipped (python toml not installed)${NC}"
            return 0
        fi
    fi
    echo -n "TOML validation: "
    for f in $(find . -name '*.toml'); do
        if ! python3 -c "import toml; toml.load('$f')" 2>/dev/null; then
            echo -e "${RED}failed${NC} ($f)"
            return 1
        fi
    done
    echo -e "${GREEN}passed${NC}"
}

# Run all checks
echo "Running lint checks..."
check_shellcheck || FAILED=1
check_fish || FAILED=1
check_stylua || FAILED=1
check_yaml || FAILED=1
check_toml || FAILED=1

if [ $FAILED -ne 0 ]; then
    echo -e "\n${RED}Lint checks failed.${NC}"
    exit 1
fi

echo -e "\n${GREEN}All checks passed!${NC}"
