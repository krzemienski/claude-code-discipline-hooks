#!/usr/bin/env bash
# bash-guard.sh — PreToolUse on Bash. Refuses `rm -rf` whose target path is
# absolute and lives outside the current working directory.
set -euo pipefail
INPUT=$(cat)

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')

if printf '%s' "$CMD" | grep -qE '^[[:space:]]*rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*|--recursive)'; then
    TARGET=$(printf '%s' "$CMD" | grep -oE '[/~][^[:space:]]+' | head -1 || true)
    if [[ -n "${TARGET:-}" && "$TARGET" == /* && "$TARGET" != "$PWD"* ]]; then
        echo "REFUSED: rm -rf outside project root ($TARGET)" >&2
        echo "Bind the command to a project-relative path." >&2
        exit 2
    fi
fi

exit 0
