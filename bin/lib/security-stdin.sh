# shellcheck shell=bash
# Helpers for invoking the macOS `security` tool without putting secrets on
# argv. Both `add-generic-password -w "$value"` and `unlock-keychain -p "$pw"`
# leak via `ps -eo args` if called the obvious way; piping commands into
# `security -i` keeps the secret in a parent→child pipe instead.
#
# SecurityTool's interactive parser (split_line) supports backslash escapes
# for " and \ inside double-quoted args, so we only need to escape those two
# characters. The program's exit code is the result of the last command in
# the input, so feeding exactly one command + EOF gives us a real exit code.

_security_quote() {
    local s=${1//\\/\\\\}
    printf '"%s"' "${s//\"/\\\"}"
}
