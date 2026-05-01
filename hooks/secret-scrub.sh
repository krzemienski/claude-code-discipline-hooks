#!/usr/bin/env bash
# secret-scrub.sh — PostToolUse on any tool. Reads the tool response off
# stdin, redacts known secret shapes, writes the rewritten JSON to stdout.
set -euo pipefail
INPUT=$(cat)

RESULT=$(printf '%s' "$INPUT" | jq -r '.tool_response.content // empty')

SCRUBBED=$(printf '%s' "$RESULT" | sed -E '
    s/sk-ant-[a-zA-Z0-9_-]{20,}/SK-ANT-REDACTED/g
    s/sk-[a-zA-Z0-9]{32,}/SK-REDACTED/g
    s/ghp_[a-zA-Z0-9]{36}/GHP-REDACTED/g
    s/gho_[a-zA-Z0-9]{36}/GHO-REDACTED/g
    s/AKIA[0-9A-Z]{16}/AKIA-REDACTED/g
    s/sk_live_[a-zA-Z0-9]{24,}/STRIPE-REDACTED/g
    s/eyJ[a-zA-Z0-9_-]{10,}\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/JWT-REDACTED/g
    s/(API_KEY|SECRET|TOKEN|PASSWORD)([_A-Z]*)=[^[:space:]]+/\1\2=REDACTED/g
')

printf '%s' "$INPUT" | jq --arg c "$SCRUBBED" '.tool_response.content = $c'
