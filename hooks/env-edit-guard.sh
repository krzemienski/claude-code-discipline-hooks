#!/usr/bin/env bash
# env-edit-guard.sh — PreToolUse on Edit / Write targeting a .env-shaped
# file. Refuses if the new content contains a long opaque secret value.
# Encourages running the secrets-manager skill instead.
set -euo pipefail
INPUT=$(cat)

PATH_TO_WRITE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
NEW_CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty')

case "$PATH_TO_WRITE" in
    *.env|*.env.*) ;;
    *) exit 0 ;;
esac

if printf '%s' "$NEW_CONTENT" | grep -qE '(API_KEY|SECRET|TOKEN|PASSWORD)[_A-Z]*=[A-Za-z0-9_/+=-]{16,}'; then
    echo "REFUSED: introducing a literal secret into $PATH_TO_WRITE." >&2
    echo "Use 1Password (op://...) refs or the secrets-manager skill." >&2
    exit 2
fi

exit 0
