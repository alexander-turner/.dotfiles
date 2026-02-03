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
set -l py_output (python3 --version 2>/dev/null)
string match -qr "(?<v>[\d.]+)" -- $py_output
```

## Related

May resolve:
- https://github.com/IlanCosman/tide/issues/143
- https://github.com/IlanCosman/tide/issues/355
- https://github.com/IlanCosman/tide/issues/409
- https://github.com/IlanCosman/tide/issues/554
