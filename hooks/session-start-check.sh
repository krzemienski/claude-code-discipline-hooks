#!/usr/bin/env bash
# session-start-check.sh — SessionStart prerequisite gate. Refuses to start
# the session if jq is missing, or if a previous trial is still flagged
# active by an evidence/.trial-active sentinel.
set -euo pipefail
cat >/dev/null || true

command -v jq >/dev/null 2>&1 || {
    echo "REFUSED: jq is required for evidence parsing." >&2
    echo "Install with: brew install jq (macOS) / apt install jq (Debian)." >&2
    exit 2
}

if [[ ! -d "evidence" ]]; then
    mkdir -p evidence
    echo "[hook] created evidence/ directory" >&2
fi

if [[ -f "evidence/.trial-active" ]]; then
    TRIAL=$(cat evidence/.trial-active 2>/dev/null || echo "?")
    echo "REFUSED: trial '$TRIAL' is still active." >&2
    echo "Close it before starting a new session." >&2
    exit 2
fi

exit 0
