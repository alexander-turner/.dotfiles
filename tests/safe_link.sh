#!/bin/bash
# tests/safe_link.sh — unit tests for bin/lib/safe_link.sh.
#
# safe_link is the only place in this repo that touches user files, so its
# three branches (already-correct symlink / real-file clobber + backup /
# stale-or-missing target) need automated coverage. Plain bash to avoid
# adding bats as a dev dependency for one tiny function.
#
# Each test runs in an isolated tmpdir with HOME and SAFE_LINK_BACKUP_ROOT
# rebound, so the real $HOME and ~/.dotfiles-backup are untouched.
#
# Usage:
#   bash tests/safe_link.sh            # run all cases, print PASS/FAIL summary
#   bash tests/safe_link.sh -v         # verbose: also print passing cases
#
# Wired into bin/lint.sh (check_safe_link_tests) so CI catches regressions.

set -uo pipefail

VERBOSE=false
[[ "${1:-}" == "-v" || "${1:-}" == "--verbose" ]] && VERBOSE=true

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../bin/lib/safe_link.sh disable=SC1091
source "$REPO_ROOT/bin/lib/safe_link.sh"

if [[ -t 1 ]]; then
    GREEN='\033[0;32m' RED='\033[0;31m' NC='\033[0m'
else
    GREEN='' RED='' NC=''
fi

PASS=0
FAIL=0
FAILED_CASES=()

# Each test is a function that exits the subshell non-zero on failure. We run
# it under `set +e` so one failing case doesn't abort the suite.
run_case() {
    local name="$1"
    shift
    # Each case gets a clean tmpdir + fresh backup-stamp env so backups from
    # one case can't bleed into another's assertions.
    local tmp
    tmp="$(mktemp -d)"
    local output rc
    output="$(
        set +e
        export HOME="$tmp/home"
        export SAFE_LINK_BACKUP_ROOT="$tmp/backups"
        unset SAFE_LINK_BACKUP_STAMP
        mkdir -p "$HOME"
        "$@" "$tmp" 2>&1
    )"
    rc=$?
    rm -rf "$tmp"
    if [[ $rc -eq 0 ]]; then
        PASS=$((PASS + 1))
        [[ "$VERBOSE" == true ]] && printf "  ${GREEN}PASS${NC} %s\n" "$name"
    else
        FAIL=$((FAIL + 1))
        FAILED_CASES+=("$name")
        printf "  ${RED}FAIL${NC} %s\n" "$name"
        printf '%s\n' "$output" | sed 's/^/        /'
    fi
}

# ── Assertion helpers ────────────────────────────────────────────────────────

# Each helper echoes the failure reason and returns non-zero on miss so cases
# can chain them with `||` for a single-point exit.
assert_symlink_to() {
    local link="$1" want="$2"
    if [[ ! -L "$link" ]]; then
        echo "expected $link to be a symlink"
        return 1
    fi
    local got
    got="$(readlink "$link")"
    if [[ "$got" != "$want" ]]; then
        echo "expected $link -> $want, got $got"
        return 1
    fi
}

assert_file_contents() {
    local path="$1" want="$2"
    if [[ ! -f "$path" ]]; then
        echo "expected $path to be a regular file"
        return 1
    fi
    local got
    got="$(cat "$path")"
    if [[ "$got" != "$want" ]]; then
        echo "expected $path to contain '$want', got '$got'"
        return 1
    fi
}

assert_not_exists() {
    if [[ -e "$1" || -L "$1" ]]; then
        echo "expected $1 not to exist"
        return 1
    fi
}

# ── Test cases ───────────────────────────────────────────────────────────────

# Case 1: target is already the correct symlink → no-op, no backup written.
case_already_correct() {
    local tmp="$1"
    local src="$tmp/source"
    local tgt="$HOME/.foo"
    echo "src-contents" >"$src"
    ln -s "$src" "$tgt"
    safe_link "$src" "$tgt" || {
        echo "safe_link returned non-zero"
        return 1
    }
    assert_symlink_to "$tgt" "$src" || return 1
    # No backup directory should have been created.
    if [[ -d "$SAFE_LINK_BACKUP_ROOT" ]]; then
        echo "no-op path must not create $SAFE_LINK_BACKUP_ROOT"
        return 1
    fi
}

# Case 2: target is a symlink pointing somewhere else → atomic relink, no backup
# (symlinks are not "user data," so we replace without prompting or backing up).
case_stale_symlink() {
    local tmp="$1"
    local src="$tmp/source"
    local other="$tmp/other"
    local tgt="$HOME/.foo"
    echo "src-contents" >"$src"
    echo "other-contents" >"$other"
    ln -s "$other" "$tgt"
    safe_link "$src" "$tgt" || {
        echo "safe_link returned non-zero"
        return 1
    }
    assert_symlink_to "$tgt" "$src" || return 1
    # Stale-symlink path doesn't touch user data, so no backup expected.
    if [[ -d "$SAFE_LINK_BACKUP_ROOT" ]]; then
        echo "stale-symlink path must not create $SAFE_LINK_BACKUP_ROOT"
        return 1
    fi
}

# Case 3: data-preservation contract for the clobber path. Exercises
# _safe_link_backup directly because the prompted overwrite branch needs a
# real TTY (here-strings and pipes both trip safe_link's non-interactive
# skip), and faking a PTY portably between Linux and macOS in a plain bash
# test isn't worth the complexity for what is, structurally, three lines:
# prompt → _safe_link_backup → ln -sf. The risky line is the backup helper;
# we pin its behaviour here.
case_real_file_clobber_with_backup() {
    local tmp="$1"
    local tgt="$HOME/.foo"
    echo "user-data-do-not-lose" >"$tgt"
    _safe_link_backup "$tgt" >/dev/null || {
        echo "_safe_link_backup returned non-zero"
        return 1
    }
    # Original must be gone (moved, not copied) so the caller can ln -sf in
    # its place without races.
    assert_not_exists "$tgt" || return 1
    # Exactly one timestamped backup dir, containing the original file with
    # its original contents under the same relative path (.foo).
    local stamp_dirs
    stamp_dirs=("$SAFE_LINK_BACKUP_ROOT"/*)
    if [[ ${#stamp_dirs[@]} -ne 1 ]]; then
        echo "expected exactly 1 backup dir, got ${#stamp_dirs[@]}: ${stamp_dirs[*]}"
        return 1
    fi
    local stamp
    stamp="$(basename "${stamp_dirs[0]}")"
    if [[ ! "$stamp" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then
        echo "backup dir name '$stamp' is not UTC ISO 8601"
        return 1
    fi
    assert_file_contents "${stamp_dirs[0]}/.foo" "user-data-do-not-lose" || return 1
}

# Case 3b: backups from a single shell session land under the same UTC stamp
# (the per-session SAFE_LINK_BACKUP_STAMP). Pins the invariant that
# uninstall.sh relies on for "restore from latest" to find every file from a
# single setup.sh run, not just the last one clobbered.
case_session_backups_share_stamp() {
    local tmp="$1"
    local a="$HOME/.a" b="$HOME/.b"
    echo "a-data" >"$a"
    echo "b-data" >"$b"
    _safe_link_backup "$a" >/dev/null || {
        echo "first backup failed"
        return 1
    }
    _safe_link_backup "$b" >/dev/null || {
        echo "second backup failed"
        return 1
    }
    local stamp_dirs
    stamp_dirs=("$SAFE_LINK_BACKUP_ROOT"/*)
    if [[ ${#stamp_dirs[@]} -ne 1 ]]; then
        echo "expected 1 stamp dir for same-session backups, got ${#stamp_dirs[@]}"
        return 1
    fi
    assert_file_contents "${stamp_dirs[0]}/.a" "a-data" || return 1
    assert_file_contents "${stamp_dirs[0]}/.b" "b-data" || return 1
}

# Case 4: source doesn't exist. ln -sf happily creates a dangling symlink (that's
# how nvim's config dir gets bootstrapped before the repo dir is populated, etc.)
# so we pin "dangling is allowed" rather than "must fail" — changing this would
# break legitimate uses.
case_source_missing() {
    local tmp="$1"
    local src="$tmp/does-not-exist"
    local tgt="$HOME/.foo"
    safe_link "$src" "$tgt" || {
        echo "safe_link returned non-zero on missing source (dangling links are allowed)"
        return 1
    }
    assert_symlink_to "$tgt" "$src" || return 1
}

# Case 6: idempotency at the unit level. Two back-to-back invocations must
# produce identical state and the second must not create another backup.
# This mirrors the workflow assertion in .github/workflows/idempotency.yml
# but exercises the function directly.
case_idempotent_re_run() {
    local tmp="$1"
    local src="$tmp/source"
    local tgt="$HOME/.foo"
    echo "src-contents" >"$src"
    safe_link "$src" "$tgt" || {
        echo "first call failed"
        return 1
    }
    safe_link "$src" "$tgt" || {
        echo "second call failed"
        return 1
    }
    assert_symlink_to "$tgt" "$src" || return 1
    # No backups expected — both runs hit the "already-correct" fast path.
    if [[ -d "$SAFE_LINK_BACKUP_ROOT" ]]; then
        echo "idempotent re-run must not create $SAFE_LINK_BACKUP_ROOT"
        return 1
    fi
}

# Case 7: non-interactive (stdin not a TTY) with a real file present must skip
# silently, NOT prompt or trip `set -e`. This is the behaviour the idempotency
# workflow relies on — setup.sh runs under CI with closed stdin and must not
# block.
case_non_interactive_skip() {
    local tmp="$1"
    local src="$tmp/source"
    local tgt="$HOME/.foo"
    echo "src-contents" >"$src"
    echo "user-data" >"$tgt"
    # Close stdin via </dev/null so `[ ! -t 0 ]` triggers the skip branch.
    safe_link "$src" "$tgt" </dev/null >/dev/null || {
        echo "safe_link should return 0 on non-interactive skip"
        return 1
    }
    # Target must still be the original real file; no symlink, no backup.
    if [[ -L "$tgt" ]]; then
        echo "non-interactive must not replace real file with symlink"
        return 1
    fi
    assert_file_contents "$tgt" "user-data" || return 1
    if [[ -d "$SAFE_LINK_BACKUP_ROOT" ]]; then
        echo "non-interactive skip must not create $SAFE_LINK_BACKUP_ROOT"
        return 1
    fi
}

# ── Run ──────────────────────────────────────────────────────────────────────

# The prompted "decline overwrite" branch isn't exercised — non-TTY skip has
# the same observable outcome and faking a PTY portably isn't worth it.

# Silent-on-pass so lint.sh can call this without cluttering its output. With
# -v: also prints PASS lines and a summary. Failures always print.
[[ "$VERBOSE" == true ]] && echo "Running safe_link tests..."
run_case "already-correct symlink is a no-op"             case_already_correct
run_case "stale symlink is atomically replaced"           case_stale_symlink
run_case "real file is backed up before clobber"          case_real_file_clobber_with_backup
run_case "same-session backups share one UTC stamp"       case_session_backups_share_stamp
run_case "missing source creates dangling link (allowed)" case_source_missing
run_case "two runs are idempotent and create no backups"  case_idempotent_re_run
run_case "non-interactive stdin skips real file silently" case_non_interactive_skip

if [[ "$VERBOSE" == true ]]; then
    printf "\n%d passed, %d failed\n" "$PASS" "$FAIL"
fi
if [[ $FAIL -gt 0 ]]; then
    printf "failed: %s\n" "${FAILED_CASES[*]}"
    exit 1
fi
exit 0
