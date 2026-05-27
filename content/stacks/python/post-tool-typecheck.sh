#!/usr/bin/env bash
# post-tool-typecheck: runs mypy on touched Python files.
set -euo pipefail

LOG="${CLAUDE_PROJECT_DIR:-.}/.claude/hooks.log"
mkdir -p "$(dirname "$LOG")"

PAYLOAD="$(cat || true)"
FILE_PATH="$(printf '%s' "$PAYLOAD" | python -c 'import sys,json;d=json.load(sys.stdin);t=d.get("tool_input",{});print(t.get("file_path") or t.get("path") or "")' 2>/dev/null || echo "")"

if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then exit 0; fi
[[ "$FILE_PATH" != *.py ]] && exit 0

# Find nearest pyproject.toml above the file
DIR="$(dirname "$FILE_PATH")"
PROJECT_DIR=""
while [[ "$DIR" != "/" && "$DIR" != "." ]]; do
  if [[ -f "$DIR/pyproject.toml" ]]; then PROJECT_DIR="$DIR"; break; fi
  DIR="$(dirname "$DIR")"
done
[[ -z "$PROJECT_DIR" ]] && exit 0

OUTPUT=""
STATUS=0
pushd "$PROJECT_DIR" >/dev/null
if command -v uv >/dev/null 2>&1; then
  if OUTPUT="$(uv run --quiet mypy "$FILE_PATH" 2>&1)"; then STATUS=0; else STATUS=$?; fi
elif command -v mypy >/dev/null 2>&1; then
  if OUTPUT="$(mypy "$FILE_PATH" 2>&1)"; then STATUS=0; else STATUS=$?; fi
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
