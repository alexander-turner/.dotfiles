# BrokenPipeError when pressing Enter rapidly (not conda-specific)

## Description

When pressing Enter rapidly with a Python virtual environment active, a `BrokenPipeError` is printed:

```
Exception ignored in: <_io.TextIOWrapper name='<stdout>' mode='w' encoding='utf-8'>
BrokenPipeError: [Errno 32] Broken pipe
```

Previous issues (#143, #409, #355) attributed this to conda, but **this affects any virtualenv**, not just conda environments.

## Reproduction

1. Activate any Python virtual environment (conda, venv, virtualenv, etc.)
2. Navigate to any directory
3. Press Enter rapidly 5-10 times

## Root Cause

`_tide_item_python.fish` uses a pipe to get the Python version:

```fish
python3 --version | string match -qr "(?<v>[\d.]+)"
```

Tide's prompt runs in a background process. When Enter is pressed quickly, `fish_prompt` kills the previous background process (`builtin kill $_tide_last_pid`). If Python is mid-output when the process is killed, it receives SIGPIPE and prints the BrokenPipeError to stderr.

## Fix

Use command substitution instead of piping. This lets fish control the pipe lifecycle, so Python completes writing before the output is consumed:

```fish
# Before (causes BrokenPipeError under race conditions)
python3 --version | string match -qr "(?<v>[\d.]+)"

# After (fish captures output first, no race condition)
set -l py_output (python3 --version 2>/dev/null)
string match -qr "(?<v>[\d.]+)" -- $py_output
```

## Proof

```bash
# Piping to a command that closes stdin causes BrokenPipeError
$ (python3 -c "print('x' * 10000)" | true) 2>&1
BrokenPipeError: [Errno 32] Broken pipe

# Command substitution does not
$ output=$(python3 -c "print('x' * 10000)" 2>&1); echo "OK: ${#output} chars"
OK: 10000 chars
```

## Environment

- Fish: 3.x
- Tide: v6
- OS: macOS / Linux
- Affects: Any Python virtual environment (not conda-specific)
