#!/usr/bin/env bash
# Active post-tool-use hook in warn mode.
# Logs tool outcomes and decision checkpoints for mistake pattern tracking (Glayvin-aligned).
set -euo pipefail

EVENT="${1:-tool-use}"
STATUS="${2:-unknown}"
TOOL_NAME="${3:-}"
HOOK_LOG="${HOME}/.vs-agents/hooks/hook.log"
TIMESTAMP=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

# Ensure log directory exists
mkdir -p "$(dirname "$HOOK_LOG")"

# Log the outcome with context
{
  printf "[INFO] $TIMESTAMP post-tool-use: event=%s status=%s tool=%s\n" "$EVENT" "$STATUS" "$TOOL_NAME"
} >> "$HOOK_LOG"

# Log to hook.log with structured format for mistake pattern analysis
LOG_ENTRY=$(printf '{"timestamp": "%s", "event": "%s", "status": "%s", "tool": "%s"}' "$TIMESTAMP" "$EVENT" "$STATUS" "$TOOL_NAME")
echo "$LOG_ENTRY" >> "$HOOK_LOG"

# If status is fail/error, log with higher visibility for gatekeeper review
if [[ "$STATUS" == "fail" ]] || [[ "$STATUS" == "error" ]]; then
  printf "[WARN] $TIMESTAMP post-tool-use: tool operation failed. Check gate status. Event=%s Tool=%s\n" "$EVENT" "$TOOL_NAME" >> "$HOOK_LOG"
  echo "[warn] Post-tool outcome: Operation $EVENT failed with status $STATUS. Gatekeeper may need to re-approve if scope changed."
fi

exit 0
