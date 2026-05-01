#!/usr/bin/env bash
# protect-skills-dir.sh — PreToolUse on Edit / Write. Refuses any mutation
# inside ~/.claude/skills/ — that directory holds user-authored skills,
# never agent-authored ones.
set -euo pipefail
INPUT=$(cat)

PATH_TO_WRITE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
HOME_DIR="${HOME:-$(eval echo "~$(whoami)")}"
SKILLS_DIR="$HOME_DIR/.claude/skills"

if [[ -n "$PATH_TO_WRITE" && "$PATH_TO_WRITE" == "$SKILLS_DIR"* ]]; then
    echo "REFUSED: $PATH_TO_WRITE is inside ~/.claude/skills/." >&2
    echo "User skills are not agent-writable. Edit them yourself." >&2
    exit 2
fi

exit 0
