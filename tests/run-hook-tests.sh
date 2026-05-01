#!/usr/bin/env bash
# run-hook-tests.sh — exercises every hook with refuse-cases and allow-cases.
# Iron rule: no mocks. Each case feeds a real JSON payload to the real hook
# script and checks the real exit code or stdout transformation. Sample
# payloads are constructed inline (Claude Code tool-call shapes) and piped
# straight to the hook on stdin.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
HOOKS="$ROOT/hooks"

cd "$ROOT"
chmod +x "$HOOKS"/*.sh
mkdir -p "$ROOT/.validation"

PASS_COUNT=0
FAIL_COUNT=0
HOOKS_TESTED=0

# expect_exit_from_payload <hook> <expected-code> <case-label> <payload>
expect_exit_from_payload() {
    local hook="$1"; local want="$2"; local label="$3"; local payload="$4"
    local got
    set +e
    printf '%s' "$payload" | "$HOOKS/$hook" >/dev/null 2>"$ROOT/.validation/last-stderr.txt"
    got=$?
    set -e
    if [[ "$got" -eq "$want" ]]; then
        echo "  PASS  $hook :: $label  (exit=$got)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL  $hook :: $label  (want exit=$want, got=$got)"
        echo "        stderr: $(cat "$ROOT/.validation/last-stderr.txt" 2>/dev/null || true)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# expect_stdout_contains_from_payload <hook> <case-label> <needle> <payload>
expect_stdout_contains_from_payload() {
    local hook="$1"; local label="$2"; local needle="$3"; local payload="$4"
    local out
    set +e
    out=$(printf '%s' "$payload" | "$HOOKS/$hook" 2>/dev/null)
    set -e
    if printf '%s' "$out" | grep -qF "$needle"; then
        echo "  PASS  $hook :: $label  (stdout contains '$needle')"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL  $hook :: $label  (stdout missing '$needle')"
        echo "        stdout: $out"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

echo
echo "=== Discipline hooks: real-hook validation sweep ==="

# 1. bash-guard.sh
echo "[1/12] bash-guard.sh"
expect_exit_from_payload bash-guard.sh 2 "refuse rm -rf outside cwd" \
    '{"tool_name":"Bash","tool_input":{"command":"rm -rf /private/var/some-other-project"}}'
expect_exit_from_payload bash-guard.sh 0 "allow rm -rf inside cwd" \
    "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf $PWD/build\"}}"
expect_exit_from_payload bash-guard.sh 0 "allow benign command" \
    '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
HOOKS_TESTED=$((HOOKS_TESTED + 1))

# 2. no-force-push.sh
echo "[2/12] no-force-push.sh"
expect_exit_from_payload no-force-push.sh 2 "refuse force-push to main" \
    '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}'
expect_exit_from_payload no-force-push.sh 2 "refuse -f to master" \
    '{"tool_name":"Bash","tool_input":{"command":"git push -f origin master"}}'
expect_exit_from_payload no-force-push.sh 0 "allow force-push to feature" \
    '{"tool_name":"Bash","tool_input":{"command":"git push --force origin feature/login"}}'
expect_exit_from_payload no-force-push.sh 0 "allow normal push" \
    '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
HOOKS_TESTED=$((HOOKS_TESTED + 1))

# 3. no-tmp-source.sh
echo "[3/12] no-tmp-source.sh"
expect_exit_from_payload no-tmp-source.sh 2 "refuse source /tmp" \
    '{"tool_name":"Bash","tool_input":{"command":"source /tmp/setup.sh"}}'
expect_exit_from_payload no-tmp-source.sh 2 "refuse source /var/tmp" \
    '{"tool_name":"Bash","tool_input":{"command":". /var/tmp/init.sh"}}'
expect_exit_from_payload no-tmp-source.sh 0 "allow source local" \
    '{"tool_name":"Bash","tool_input":{"command":"source ./scripts/setup.sh"}}'
HOOKS_TESTED=$((HOOKS_TESTED + 1))

# 4. refuse-secret-files.sh
echo "[4/12] refuse-secret-files.sh"
expect_exit_from_payload refuse-secret-files.sh 2 "refuse .env" \
    '{"tool_name":"Read","tool_input":{"file_path":"/Users/x/project/.env"}}'
expect_exit_from_payload refuse-secret-files.sh 2 "refuse id_rsa" \
    '{"tool_name":"Read","tool_input":{"file_path":"/Users/x/.ssh/id_rsa"}}'
expect_exit_from_payload refuse-secret-files.sh 2 "refuse kubeconfig" \
    '{"tool_name":"Read","tool_input":{"file_path":"/Users/x/.kube/config"}}'
expect_exit_from_payload refuse-secret-files.sh 0 "allow README" \
    '{"tool_name":"Read","tool_input":{"file_path":"/Users/x/project/README.md"}}'
HOOKS_TESTED=$((HOOKS_TESTED + 1))

# 5. protect-skills-dir.sh
echo "[5/12] protect-skills-dir.sh"
expect_exit_from_payload protect-skills-dir.sh 2 "refuse edit in skills dir" \
    "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$HOME/.claude/skills/some-skill/SKILL.md\"}}"
expect_exit_from_payload protect-skills-dir.sh 0 "allow edit in project src" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/Users/x/project/src/main.ts"}}'
HOOKS_TESTED=$((HOOKS_TESTED + 1))

# 6. no-node-modules-write.sh
echo "[6/12] no-node-modules-write.sh"
expect_exit_from_payload no-node-modules-write.sh 2 "refuse write inside node_modules" \
    '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/project/node_modules/lodash/index.js","content":"x"}}'
expect_exit_from_payload no-node-modules-write.sh 0 "allow write to src" \
    '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/project/src/main.ts","content":"x"}}'
HOOKS_TESTED=$((HOOKS_TESTED + 1))

# 7. env-edit-guard.sh
echo "[7/12] env-edit-guard.sh"
expect_exit_from_payload env-edit-guard.sh 2 "refuse literal secret in .env" \
    '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/project/.env","content":"API_KEY=AbCdEf0123456789xyzABCDEF"}}'
expect_exit_from_payload env-edit-guard.sh 0 "allow op:// ref in .env" \
    '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/project/.env","content":"API_KEY=op://Personal/svc/api-key"}}'
expect_exit_from_payload env-edit-guard.sh 0 "skip non-env files" \
    '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/project/src/main.ts","content":"const x=1"}}'
HOOKS_TESTED=$((HOOKS_TESTED + 1))

# 8. secret-scrub.sh
echo "[8/12] secret-scrub.sh"
PRINTENV_PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"cat config.json"},"tool_response":{"content":"API_KEY=verylongsecretvalue1234567890\nAuthorization: Bearer ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789\nUSER=nick"}}'
expect_stdout_contains_from_payload secret-scrub.sh "redacts API_KEY=..." "REDACTED" "$PRINTENV_PAYLOAD"
expect_stdout_contains_from_payload secret-scrub.sh "redacts GitHub token" "GHP-REDACTED" "$PRINTENV_PAYLOAD"
expect_exit_from_payload secret-scrub.sh 0 "passes clean output through" \
    '{"tool_name":"Bash","tool_input":{"command":"date"},"tool_response":{"content":"Wed Apr 30 22:30:00 PDT 2026"}}'
HOOKS_TESTED=$((HOOKS_TESTED + 1))

# 9. post-build-nudge.sh
echo "[9/12] post-build-nudge.sh"
BUILD_PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"npm run build"},"tool_response":{"content":"build complete in 3.2s"}}'
expect_stdout_contains_from_payload post-build-nudge.sh "appends nudge to build" "[hook]" "$BUILD_PAYLOAD"
expect_stdout_contains_from_payload post-build-nudge.sh "nudge text present" "functional validation" "$BUILD_PAYLOAD"
expect_exit_from_payload post-build-nudge.sh 0 "no-op for non-build" \
    '{"tool_name":"Bash","tool_input":{"command":"ls -la"},"tool_response":{"content":"file1\nfile2"}}'
HOOKS_TESTED=$((HOOKS_TESTED + 1))

# 10. session-start-check.sh
echo "[10/12] session-start-check.sh"
mkdir -p "$ROOT/evidence"
echo "trial-42" >"$ROOT/evidence/.trial-active"
expect_exit_from_payload session-start-check.sh 2 "refuse with active trial" '{}'
rm -f "$ROOT/evidence/.trial-active"
expect_exit_from_payload session-start-check.sh 0 "allow with no trial" '{}'
HOOKS_TESTED=$((HOOKS_TESTED + 1))

# 11. completion-gate.sh
echo "[11/12] completion-gate.sh"
rm -rf "$ROOT/evidence/completion-gate"
expect_exit_from_payload completion-gate.sh 2 "refuse when report missing" '{}'
mkdir -p "$ROOT/evidence/completion-gate"
echo '{"overall":"INCOMPLETE"}' >"$ROOT/evidence/completion-gate/report.json"
expect_exit_from_payload completion-gate.sh 2 "refuse when report INCOMPLETE" '{}'
echo '{"overall":"COMPLETE"}' >"$ROOT/evidence/completion-gate/report.json"
expect_exit_from_payload completion-gate.sh 0 "allow when report COMPLETE" '{}'
rm -rf "$ROOT/evidence"
HOOKS_TESTED=$((HOOKS_TESTED + 1))

# 12. read-redact.sh
echo "[12/12] read-redact.sh"
READ_PAYLOAD='{"tool_name":"Read","tool_input":{"file_path":"/x/config.json"},"tool_response":{"content":"sk-AbCdEfGhIjKlMnOpQrStUvWxYz0123456789\neyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NSJ9.signaturepart"}}'
expect_stdout_contains_from_payload read-redact.sh "redacts JWT" "JWT-REDACTED" "$READ_PAYLOAD"
expect_stdout_contains_from_payload read-redact.sh "redacts sk- token" "SK-REDACTED" "$READ_PAYLOAD"
expect_exit_from_payload read-redact.sh 0 "passes clean read through" \
    '{"tool_name":"Read","tool_input":{"file_path":"/x/README.md"},"tool_response":{"content":"# Project\nNothing sensitive here."}}'
HOOKS_TESTED=$((HOOKS_TESTED + 1))

echo
echo "=== Summary ==="
echo "  hooks tested: $HOOKS_TESTED"
echo "  pass cases:   $PASS_COUNT"
echo "  fail cases:   $FAIL_COUNT"

if [[ "$FAIL_COUNT" -eq 0 && "$HOOKS_TESTED" -eq 12 ]]; then
    echo
    echo "All 12 hooks pass test cases (refuse expected inputs, allow expected inputs)"
    exit 0
fi

echo
echo "FAILED: $FAIL_COUNT case(s) failed across $HOOKS_TESTED hooks"
exit 1
