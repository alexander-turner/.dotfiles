#!/bin/bash
# gitleaks wrapper for the pre-commit local hook (.pre-commit-config.yaml).
#
# bin/pre-push sets GITLEAKS_LOG_OPTS to narrow the scan to the push range;
# CI leaves it unset for a full-history scan. GITLEAKS_REQUIRED=1 (also set
# by pre-push) flips missing-binary from a soft skip to a hard fail so an
# unconfigured dev box can't silence the gate by leaving gitleaks uninstalled.
set -euo pipefail

if ! command -v gitleaks >/dev/null 2>&1; then
    if [[ "${GITLEAKS_REQUIRED:-0}" == "1" ]]; then
        echo "gitleaks: missing (required in pre-push — install via Brewfile)" >&2
        exit 1
    fi
    echo "gitleaks: skipped (not installed)"
    exit 0
fi

extra=()
if [[ -n "${GITLEAKS_LOG_OPTS:-}" ]]; then
    extra=(--log-opts="$GITLEAKS_LOG_OPTS")
fi

if gitleaks detect --no-banner --redact --config=.gitleaks.toml "${extra[@]+"${extra[@]}"}" >/dev/null 2>&1; then
    exit 0
fi

echo "gitleaks: failed" >&2
echo "  Re-run for details: gitleaks detect --no-banner --redact --config=.gitleaks.toml${GITLEAKS_LOG_OPTS:+ --log-opts=\"$GITLEAKS_LOG_OPTS\"}" >&2
exit 1
