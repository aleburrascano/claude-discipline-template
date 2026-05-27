#!/bin/bash
# source-prefetch-reminder.sh — UserPromptSubmit hook (Layer 2)
#
# When the user's prompt names URLs or file paths, inject a reminder that the
# corresponding retrieval tool MUST be called before any content claim. Pre-frames
# the turn so the Stop-side claim-audit isn't a surprise.

set -uo pipefail

input=$(cat)

if [ "${CLAUDE_SKIP_PREFETCH_REMINDER:-}" = "1" ]; then
  echo '{}'
  exit 0
fi

prompt=$(jq -r '.prompt // .hookSpecificInput.prompt // ""' <<<"$input" 2>/dev/null)
if [ -z "$prompt" ]; then
  echo '{}'
  exit 0
fi

# Extract URLs first; then strip URLs from the prompt before scanning for file paths
# (otherwise URL path components get matched as bare paths).
urls=$(echo "$prompt" | grep -oE 'https?://[^[:space:]"'\''<>)]+' | sort -u)
prompt_no_urls=$(echo "$prompt" | sed -E 's#https?://[^[:space:]"'"'"'<>)]+##g')
paths=$(echo "$prompt_no_urls" | grep -oE '[A-Za-z0-9_./-]+\.(md|ts|tsx|js|jsx|py|rs|go|rb|sh|json|yml|yaml|toml|html|css|scss|sql|txt)' | sort -u)

if [ -z "$urls" ] && [ -z "$paths" ]; then
  echo '{}'
  exit 0
fi

# Build the reminder.
items=""
if [ -n "$urls" ]; then
  while IFS= read -r u; do
    [ -n "$u" ] && items="${items}- ${u} (use WebFetch)"$'\n'
  done <<<"$urls"
fi
if [ -n "$paths" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] && items="${items}- ${p} (use Read)"$'\n'
  done <<<"$paths"
fi

reminder="Sources in user prompt — fetch before claiming, cite inline (CLAUDE.md rule 8):
${items}"

jq -n --arg ctx "$reminder" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
