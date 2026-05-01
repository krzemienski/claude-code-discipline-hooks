#!/usr/bin/env bash
# no-node-modules-write.sh — PreToolUse on Write / Edit. Refuses writes that
# land inside any node_modules tree. Drift between "intent to write source"
# and "actually writing into a vendored dependency" is almost always a bug.
set -euo pipefail
INPUT=$(cat)

PATH_TO_WRITE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')

case "$PATH_TO_WRITE" in
    */node_modules/*|*/node_modules)
        echo "REFUSED: $PATH_TO_WRITE is inside node_modules/." >&2
        echo "If you really need to patch a dep, use patch-package against source." >&2
        exit 2
        ;;
esac

exit 0
