# BrokenPipeError when pressing Enter rapidly with virtualenv active

Pressing Enter quickly (~5 times in rapid succession) with a Python virtualenv active prints:

```
Exception ignored in: <_io.TextIOWrapper name='<stdout>' mode='w' encoding='utf-8'>
BrokenPipeError: [Errno 32] Broken pipe
```

## Cause

`_tide_item_python.fish` pipes Python's output directly to `string match`:

```fish
python3 --version | string match -qr "(?<v>[\d.]+)"
```

When `fish_prompt` kills the previous background prompt process (`builtin kill $_tide_last_pid`), Python may still be writing to the pipe, triggering SIGPIPE.

## Fix

Use command substitution so Python completes before output is consumed:

```fish
set -l py_cmd python
command -q python3 && set py_cmd python3
set -l py_output ($py_cmd --version 2>/dev/null)
string match -qr "(?<v>[\d.]+)" -- $py_output
```

Happy to open a PR if this approach looks good.

## Related

This may resolve #143, #355, #409, #554 — the underlying cause is the pipe race condition, not conda specifically.
