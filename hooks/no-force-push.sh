#!/usr/bin/env bash
# no-force-push.sh — PreToolUse on Bash. Refuses `git push --force` (and -f)
# against any branch name matching main, master, prod, production, or release.
set -euo pipefail
INPUT=$(cat)

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')

if printf '%s' "$CMD" | grep -qE '^[[:space:]]*git[[:space:]]+push[[:space:]]+'; then
    if printf '%s' "$CMD" | grep -qE '(--force([[:space:]]|=|$)|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
        if printf '%s' "$CMD" | grep -qE '\b(main|master|prod|production|release(/[A-Za-z0-9._/-]+)?)\b'; then
            echo "REFUSED: force-push to a protected branch (main/master/prod/release)." >&2
            echo "Use a feature branch and open a PR; or rewind locally without --force." >&2
            exit 2
        fi
    fi
fi

exit 0
