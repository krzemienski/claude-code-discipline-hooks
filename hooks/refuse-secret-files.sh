#!/usr/bin/env bash
# refuse-secret-files.sh — PreToolUse on Read. Blocks reads of files that
# typically hold plaintext secrets (.env, SSH private keys, kubeconfig,
# AWS credentials). Soft-warns on adjacent suspicious paths.
set -euo pipefail
INPUT=$(cat)

PATH_TO_READ=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')

case "$PATH_TO_READ" in
    *.env|*.env.*|*/.aws/credentials|*/id_rsa|*/id_ed25519|*/id_ecdsa|*kubeconfig|*/.kube/config)
        echo "REFUSED: $PATH_TO_READ contains secrets in plaintext." >&2
        echo "Use environment variables or a secrets-manager skill instead." >&2
        exit 2
        ;;
    *secret*|*credentials*|*.pem|*.key|*.p12)
        echo "WARNING: path looks sensitive ($PATH_TO_READ). Confirm before reading." >&2
        ;;
esac

exit 0
