#!/usr/bin/env bash
# no-tmp-source.sh — PreToolUse on Bash. Refuses `source` / `.` of files under
# /tmp or /var/tmp. Sourcing untrusted scripts from world-writable dirs is one
# of the highest-impact code-execution paths.
set -euo pipefail
INPUT=$(cat)

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')

if printf '%s' "$CMD" | grep -qE '(^|[[:space:]]|;|&&|\|\|)(source|\.)[[:space:]]+(/tmp/|/var/tmp/)'; then
    echo "REFUSED: refusing to source a script from /tmp or /var/tmp." >&2
    echo "Move the script to a project-controlled path before sourcing." >&2
    exit 2
fi

exit 0
