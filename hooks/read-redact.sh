#!/usr/bin/env bash
# read-redact.sh — PostToolUse on Read. Tighter scrub of file content as it
# returns to the model. Catches API keys and JWTs that slipped through to
# disk before the hooks were installed.
set -euo pipefail
INPUT=$(cat)

RESULT=$(printf '%s' "$INPUT" | jq -r '.tool_response.content // empty')

REDACTED=$(printf '%s' "$RESULT" | sed -E '
    s/(sk-[a-zA-Z0-9]{32,})/SK-REDACTED/g
    s/(ghp_[a-zA-Z0-9]{36})/GHP-REDACTED/g
    s/("api_key"[[:space:]]*:[[:space:]]*)"[^"]+"/\1"REDACTED"/g
    s/eyJ[a-zA-Z0-9_-]{10,}\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/JWT-REDACTED/g
')

printf '%s' "$INPUT" | jq --arg c "$REDACTED" '.tool_response.content = $c'
