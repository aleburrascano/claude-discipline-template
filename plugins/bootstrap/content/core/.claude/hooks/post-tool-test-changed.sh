#!/usr/bin/env bash
# post-tool-test-changed: runs the tests closest to the touched file for fast feedback.
# THIS IS A STUB. Fill in the TODOs for your stack.

set -euo pipefail

LOG="${CLAUDE_PROJECT_DIR:-.}/.claude/hooks.log"
mkdir -p "$(dirname "$LOG")"

PAYLOAD="$(cat || true)"
FILE_PATH="$(printf '%s' "$PAYLOAD" | python -c 'import sys,json;d=json.load(sys.stdin);t=d.get("tool_input",{});print(t.get("file_path") or t.get("path") or "")' 2>/dev/null || echo "")"

if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then exit 0; fi

# Don't re-run tests on test edits themselves
if [[ "$FILE_PATH" == *"/tests/"* ]] || [[ "$FILE_PATH" == *"/__tests__/"* ]] || \
   [[ "$FILE_PATH" == *"_test.py" ]] || [[ "$FILE_PATH" == *".test.ts" ]] || [[ "$FILE_PATH" == *".test.tsx" ]]; then
  exit 0
fi

OUTPUT=""
STATUS=0

# ---- TODO: replace with your stack's targeted-test command(s) ----
#
# Python (pytest): find a matching test_<stem>.py and run it
# Jest:            pnpm exec jest --findRelatedTests "$FILE_PATH"
# Go:              go test ./$(dirname "$FILE_PATH")
# ------------------------------------------------------------------

if [[ $STATUS -ne 0 ]] && [[ -n "$OUTPUT" ]]; then
  echo "[test-changed] FAIL $FILE_PATH" >> "$LOG"
  echo "$OUTPUT" >> "$LOG"
  TRIMMED="$(printf '%s' "$OUTPUT" | head -c 3000)"
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Tests failing for $FILE_PATH:\n$TRIMMED"
  }
}
EOF
fi

exit 0
