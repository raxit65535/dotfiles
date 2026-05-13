#!/usr/bin/env bash
# Active pre-tool-use hook in warn mode.
# Aligned workflow gates: validate before commit, review before push, test before task_done.
# Warns on command patterns that bypass validation gates or edit secrets.
set -euo pipefail

INPUT="${1:-}"
HOOK_LOG="${HOME}/.vs-agents/hooks/hook.log"
TIMESTAMP=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

# Ensure log directory exists
mkdir -p "$(dirname "$HOOK_LOG")"

# Pattern 1: Destructive git operations that bypass commit gate
if echo "$INPUT" | grep -qE "git\s+(reset\s+--hard|checkout\s+--|push\s+-f|revert)"; then
  MSG="[WARN] $TIMESTAMP pre-tool-use: destructive git operation detected. Bypasses commit gate: $INPUT"
  echo "$MSG" >> "$HOOK_LOG"
  echo "[warn] Pre-tool safety check: $MSG. Ensure validation is recent (commit gate requires <15min old report)."
fi

# Pattern 2: Broad force pushes or rebase operations that bypass PR gate
if echo "$INPUT" | grep -qE "git\s+push\s+--force|git\s+rebase\s+(--interactive|-i)|git\s+push\s+.*-f"; then
  MSG="[WARN] $TIMESTAMP pre-tool-use: force push or interactive rebase detected. May require gatekeeper re-approval: $INPUT"
  echo "$MSG" >> "$HOOK_LOG"
  echo "[warn] Pre-tool safety check: $MSG. Consider running gatekeeper agent if change scope expanded."
fi

# Pattern 3: Secret/credential edits (.env, tokens, api keys, passwords)
if echo "$INPUT" | grep -qE "\.env|api[_-]?key|password|token|secret|credential"; then
  MSG="[WARN] $TIMESTAMP pre-tool-use: secret-related operation detected. Keep tokens in env vars, not files: $INPUT"
  echo "$MSG" >> "$HOOK_LOG"
  echo "[warn] Pre-tool safety check: $MSG. Secrets should be in environment or .local/ (git-ignored)."
fi

# Pattern 4: Validation bypass (skipping tests, lints, or checks before commit)
if echo "$INPUT" | grep -qE "git\s+commit\s+.*--no-verify|-n|skip.*test|bypass.*lint"; then
  MSG="[WARN] $TIMESTAMP pre-tool-use: validation bypass detected. Violates commit gate: $INPUT"
  echo "$MSG" >> "$HOOK_LOG"
  echo "[warn] Pre-tool safety check: $MSG. Run 'npm run validate' before commit (commit gate enforces <15min recency)."
fi

# Pattern 5: Broad file deletions or destructive operations outside version control
if echo "$INPUT" | grep -qE "rm\s+-rf|rm\s+.*\*|find\s+.*-delete"; then
  MSG="[WARN] $TIMESTAMP pre-tool-use: destructive file operation detected: $INPUT"
  echo "$MSG" >> "$HOOK_LOG"
  echo "[warn] Pre-tool safety check: $MSG. Consider using git rm for version-controlled files."
fi

# Log successful pass (benign operation)
if [[ -z "$INPUT" ]] || ! echo "$INPUT" | grep -qE "git\s+(reset|checkout|push)|\.env|token|secret|rm\s+-rf"; then
  MSG="[INFO] $TIMESTAMP pre-tool-use: benign operation passed: $INPUT"
  echo "$MSG" >> "$HOOK_LOG"
fi

exit 0
