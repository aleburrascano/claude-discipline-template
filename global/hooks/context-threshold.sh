#!/bin/bash
# Hook: Context-usage warning at threshold
# Event: UserPromptSubmit
# Purpose: Alert when transcript size suggests high context utilization, so the
# user can /half-clone or /clear before auto-compaction degrades reasoning.
#
# Sizing: English averages ~4 characters per token. 85% of a 200k-token context
# is ~680 KB of transcript. The transcript JSONL also includes JSON envelope
# overhead that the model never sees, so the real percentage is somewhat lower
# than this proxy suggests — that's intentional, false alarms are cheap, missed
# alarms aren't.
#
# Override:
#   CLAUDE_CONTEXT_THRESHOLD_KB=<n>   raise/lower the trigger (default 680)
#   CLAUDE_SKIP_CONTEXT_THRESHOLD=1   disable entirely
#
# 1M-context users (Opus 1M) should set CLAUDE_CONTEXT_THRESHOLD_KB to ~3400
# to trigger at the same relative 85% mark.

set -e

if [ "${CLAUDE_SKIP_CONTEXT_THRESHOLD:-}" = "1" ]; then
  echo '{}'
  exit 0
fi

input=$(cat)
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
  echo '{}'
  exit 0
fi

# Threshold default: 680 KB ≈ 85% of 200k-token context at ~4 chars/token.
THRESHOLD_KB="${CLAUDE_CONTEXT_THRESHOLD_KB:-680}"
THRESHOLD_BYTES=$((THRESHOLD_KB * 1024))

transcript_size=$(stat -f%z "$transcript_path" 2>/dev/null || stat -c%s "$transcript_path" 2>/dev/null || echo 0)
transcript_kb=$((transcript_size / 1024))

if [ "$transcript_size" -gt "$THRESHOLD_BYTES" ]; then
  jq -nc --arg kb "$transcript_kb" --arg thr "$THRESHOLD_KB" '{
    continue: true,
    systemMessage: ("⚠️ Transcript size " + $kb + " KB exceeds threshold " + $thr + " KB (~85% of 200k context at default). Consider /half-clone or /clear before auto-compaction degrades reasoning. Override threshold via CLAUDE_CONTEXT_THRESHOLD_KB."),
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      contextWarningTriggered: true,
      transcriptSizeKB: ($kb | tonumber),
      thresholdKB: ($thr | tonumber)
    }
  }'
  exit 0
fi

jq -nc --arg kb "$transcript_kb" --arg thr "$THRESHOLD_KB" '{
  continue: true,
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    contextWarningTriggered: false,
    transcriptSizeKB: ($kb | tonumber),
    thresholdKB: ($thr | tonumber)
  }
}'
