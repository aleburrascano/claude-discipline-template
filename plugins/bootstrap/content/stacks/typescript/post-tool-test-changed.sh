#!/usr/bin/env bash
# post-tool-test-changed: runs jest --findRelatedTests on touched files.
set -euo pipefail

LOG="${CLAUDE_PROJECT_DIR:-.}/.claude/hooks.log"
mkdir -p "$(dirname "$LOG")"

PAYLOAD="$(cat || true)"
FILE_PATH="$(printf '%s' "$PAYLOAD" | python -c 'import sys,json;d=json.load(sys.stdin);t=d.get("tool_input",{});print(t.get("file_path") or t.get("path") or "")' 2>/dev/null || echo "")"

if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then exit 0; fi
case "$FILE_PATH" in *.ts|*.tsx|*.js|*.jsx) ;; *) exit 0 ;; esac
# skip test files themselves
case "$FILE_PATH" in *.test.*|*.spec.*|*/__tests__/*) exit 0 ;; esac

DIR="$(dirname "$FILE_PATH")"
PROJECT_DIR=""
while [[ "$DIR" != "/" && "$DIR" != "." ]]; do
  if [[ -f "$DIR/package.json" ]]; then PROJECT_DIR="$DIR"; break; fi
  DIR="$(dirname "$DIR")"
done
[[ -z "$PROJECT_DIR" ]] && exit 0

OUTPUT=""
STATUS=0
pushd "$PROJECT_DIR" >/dev/null
if command -v pnpm >/dev/null 2>&1; then
  if OUTPUT="$(pnpm exec jest --findRelatedTests "$FILE_PATH" --passWithNoTests 2>&1)"; then STATUS=0; else STATUS=$?; fi
fi
popd >/dev/null

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
