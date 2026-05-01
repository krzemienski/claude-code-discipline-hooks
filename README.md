# claude-code-discipline-hooks

Twelve drop-in hooks for Claude Code. Refusal-on-exit-2, plus a couple of
PostToolUse filters for redaction and build nudges. Each hook is short
(under 30 lines), opinionated, and enforces one rule.

## Why this exists

I built this after reading my own session logs and finding things that
should never have been there: a `rm -rf` aimed at the wrong directory, a
`git push --force` against `main` that I caught only because the agent
narrated it, an API key inside a `.env` that flowed into the transcript.

Each of those is a tiny script away from being structurally impossible.
The post that explains the pattern is here:

- [Hooks as a Control Plane](https://withagents.dev/posts/post-22-hook-control-plane)
- [Giving Agents Secrets Without Giving Agents Secrets](https://withagents.dev/posts/post-26-secrets-without-secrets)

Read the first one if you want the theory. Read this README if you want
to drop the hooks into a project right now.

## Install

```bash
git clone https://github.com/krzemienski/claude-code-discipline-hooks
cd claude-code-discipline-hooks
chmod +x hooks/*.sh
```

Two install paths:

| Path | Use when | Steps |
|------|----------|-------|
| User-level (recommended) | One machine, all projects | `cp hooks/*.sh ~/.claude/hooks/` and merge `hooks.json` into `~/.claude/settings.json` |
| Plugin-style | Per-project, version-controlled | Copy the repo into `.claude/` at the project root; `hooks.json` is auto-loaded |

## What each hook does

| Hook | Event | Matcher | Refuses on |
|------|-------|---------|-----------|
| `bash-guard.sh` | PreToolUse | Bash | `rm -rf` against an absolute path outside `$PWD` |
| `no-force-push.sh` | PreToolUse | Bash | `git push --force` (or `-f`) on main / master / prod / release |
| `no-tmp-source.sh` | PreToolUse | Bash | `source` / `.` of any file under `/tmp` or `/var/tmp` |
| `refuse-secret-files.sh` | PreToolUse | Read | reads of `.env*`, `id_rsa`, `id_ed25519`, kubeconfig, `~/.aws/credentials` |
| `protect-skills-dir.sh` | PreToolUse | Edit / Write | mutations inside `~/.claude/skills/` |
| `no-node-modules-write.sh` | PreToolUse | Edit / Write | writes whose path contains `node_modules/` |
| `env-edit-guard.sh` | PreToolUse | Edit / Write | `.env` writes that introduce a literal long opaque value |
| `secret-scrub.sh` | PostToolUse | * | (transforms) tool result content; redacts known secret shapes |
| `read-redact.sh` | PostToolUse | Read | (transforms) Read result content; redacts API keys and JWTs |
| `post-build-nudge.sh` | PostToolUse | Bash | (transforms) appends a nudge after `npm/pnpm/cargo/go/swift/make build` |
| `session-start-check.sh` | SessionStart | — | session start when `evidence/.trial-active` sentinel is present |
| `completion-gate.sh` | Stop | — | session end without `evidence/completion-gate/report.json` reporting `overall=COMPLETE` |

## Quickstart

The canonical refusal looks like this. The hook reads JSON on stdin,
greps the command, prints to stderr, exits 2.

```bash
$ echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /var/tmp/whatever"}}' \
  | ./hooks/bash-guard.sh
REFUSED: rm -rf outside project root (/var/tmp/whatever)
Bind the command to a project-relative path.
$ echo $?
2
```

A pass-through looks like this. Same hook, in-cwd target, exit 0.

```bash
$ echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf $PWD/build\"}}" \
  | ./hooks/bash-guard.sh
$ echo $?
0
```

## Validate the hooks

The repo ships a real-system test sweep. Every case is a Claude-Code-shaped
JSON payload piped straight to the hook script. No mocks.

```bash
bash tests/run-hook-tests.sh
```

Expected final line:

```
All 12 hooks pass test cases (refuse expected inputs, allow expected inputs)
```

The first run produces `.validation/run-1.log` plus `.validation/PASSED.md`
once the sweep is green.

## Customize

Each hook is a single file. Edit it. The patterns are regex; the matchers
are regex. Tighten or relax in place.

If you add a new hook:

1. Drop it in `hooks/`, make it executable.
2. Register it under the right event in `hooks.json`.
3. Add a refuse-case and an allow-case to `tests/run-hook-tests.sh`.
4. Bump the `[N/12]` counters and the final summary string.

## License

MIT, see `LICENSE`. Author: Nick Krzemienski.
