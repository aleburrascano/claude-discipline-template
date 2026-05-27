#!/usr/bin/env bash
# post-tool-test-changed: runs the nearest test_<stem>.py for the touched Python file.
set -euo pipefail

LOG="${CLAUDE_PROJECT_DIR:-.}/.claude/hooks.log"
mkdir -p "$(dirname "$LOG")"

PAYLOAD="$(cat || true)"
FILE_PATH="$(printf '%s' "$PAYLOAD" | python -c 'import sys,json;d=json.load(sys.stdin);t=d.get("tool_input",{});print(t.get("file_path") or t.get("path") or "")' 2>/dev/null || echo "")"

if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then exit 0; fi
[[ "$FILE_PATH" != *.py ]] && exit 0
case "$FILE_PATH" in */tests/*|*/test_*.py|*_test.py) exit 0 ;; esac

DIR="$(dirname "$FILE_PATH")"
PROJECT_DIR=""
while [[ "$DIR" != "/" && "$DIR" != "." ]]; do
  if [[ -f "$DIR/pyproject.toml" ]]; then PROJECT_DIR="$DIR"; break; fi
  DIR="$(dirname "$DIR")"
done
[[ -z "$PROJECT_DIR" ]] && exit 0

basename="$(basename "$FILE_PATH" .py)"

OUTPUT=""
STATUS=0
pushd "$PROJECT_DIR" >/dev/null
TEST_FILE="$(find tests -name "test_${basename}.py" -type f 2>/dev/null | head -1 || true)"
if [[ -n "$TEST_FILE" ]] && command -v uv >/dev/null 2>&1; then
  if OUTPUT="$(uv run --quiet pytest -q "$TEST_FILE" 2>&1)"; then STATUS=0; else STATUS=$?; fi
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
