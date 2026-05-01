#!/usr/bin/env bash
# completion-gate.sh — Stop hook. Refuses to let the session end unless
# evidence/completion-gate/report.json exists and reports overall=COMPLETE.
set -euo pipefail
cat >/dev/null || true

REPORT="evidence/completion-gate/report.json"

if [[ ! -f "$REPORT" ]]; then
    echo "REFUSED: $REPORT not found." >&2
    echo "Run the completion gate before declaring done." >&2
    exit 2
fi

OVERALL=$(jq -r '.overall // empty' "$REPORT" 2>/dev/null || true)

if [[ "$OVERALL" != "COMPLETE" ]]; then
    echo "REFUSED: $REPORT.overall = '$OVERALL', expected 'COMPLETE'." >&2
    echo "Resolve the open items and re-run the gate." >&2
    exit 2
fi

exit 0
