#!/bin/bash
# response-discipline-reminder.sh — UserPromptSubmit hook
#
# Always-on. Injects a tight reminder via additionalContext (cache-preserving)
# combining citation-style guidance and brevity. Replaces post-hoc Stop-block
# retries with first-pass discipline.
#
# Off switch: CLAUDE_SKIP_RESPONSE_DISCIPLINE=1

set -uo pipefail

if [ "${CLAUDE_SKIP_RESPONSE_DISCIPLINE:-}" = "1" ]; then
  echo '{}'
  exit 0
fi

reminder='Cite inline as you write — not after. Two forms: [VERIFIED:Read@<path>#L<n>-L<m>] for code references (Read/Grep/Glob/MultiEdit, no quote); [VERIFIED:WebFetch@<url>] "exact phrase" for textual claims. Use angle-bracket placeholders when discussing this format. Brevity: no preamble, no recap, no transition phrases. State the answer, cite, stop.'

jq -nc --arg ctx "$reminder" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
