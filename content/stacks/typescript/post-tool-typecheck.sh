#!/usr/bin/env bash
# post-tool-typecheck: runs tsc --noEmit on touched TS/TSX files.
set -euo pipefail

LOG="${CLAUDE_PROJECT_DIR:-.}/.claude/hooks.log"
mkdir -p "$(dirname "$LOG")"

PAYLOAD="$(cat || true)"
FILE_PATH="$(printf '%s' "$PAYLOAD" | python -c 'import sys,json;d=json.load(sys.stdin);t=d.get("tool_input",{});print(t.get("file_path") or t.get("path") or "")' 2>/dev/null || echo "")"

if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then exit 0; fi
[[ "$FILE_PATH" != *.ts && "$FILE_PATH" != *.tsx ]] && exit 0

OUTPUT=""
STATUS=0

# Find the nearest tsconfig.json above the file
DIR="$(dirname "$FILE_PATH")"
TSCONFIG=""
while [[ "$DIR" != "/" && "$DIR" != "." ]]; do
  if [[ -f "$DIR/tsconfig.json" ]]; then TSCONFIG="$DIR/tsconfig.json"; break; fi
  DIR="$(dirname "$DIR")"
done

if [[ -z "$TSCONFIG" ]]; then exit 0; fi
PROJECT_DIR="$(dirname "$TSCONFIG")"

pushd "$PROJECT_DIR" >/dev/null
if command -v pnpm >/dev/null 2>&1; then
  if OUTPUT="$(pnpm exec tsc --noEmit 2>&1)"; then STATUS=0; else STATUS=$?; fi
elif command -v npx >/dev/null 2>&1; then
  if OUTPUT="$(npx --no-install tsc --noEmit 2>&1)"; then STATUS=0; else STATUS=$?; fi
fi
popd >/dev/null

if [[ $STATUS -ne 0 ]] && [[ -n "$OUTPUT" ]]; then
  echo "[typecheck] FAIL $FILE_PATH" >> "$LOG"
  echo "$OUTPUT" >> "$LOG"
  TRIMMED="$(printf '%s' "$OUTPUT" | head -c 4000)"
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Typecheck failed on $FILE_PATH:\n$TRIMMED"
  }
}
EOF
fi

exit 0
