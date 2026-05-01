#!/usr/bin/env bash
# post-build-nudge.sh — PostToolUse on Bash. When the command was a build
# (npm run build, pnpm build, cargo build, go build, swift build, make),
# append a one-line nudge reminding the model that a green build is not
# the same as a working feature.
set -euo pipefail
INPUT=$(cat)

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
NUDGE="Build success != functional validation. Did you exercise the feature through real UI / a real request?"

if printf '%s' "$CMD" | grep -qE '\b(npm|pnpm|yarn|bun)[[:space:]]+run[[:space:]]+build\b|\b(cargo|go|swift)[[:space:]]+build\b|\bmake[[:space:]]*$|\bmake[[:space:]]+build\b'; then
    printf '%s' "$INPUT" | jq --arg n "$NUDGE" '.tool_response.content = ((.tool_response.content // "") + "\n[hook] " + $n)'
else
    printf '%s' "$INPUT"
fi
