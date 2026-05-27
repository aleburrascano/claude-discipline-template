#!/usr/bin/env bash
# post-tool-typecheck: runs your project's typechecker on touched files.
# THIS IS A STUB. Fill in the TODOs for your stack.

set -euo pipefail

LOG="${CLAUDE_PROJECT_DIR:-.}/.claude/hooks.log"
mkdir -p "$(dirname "$LOG")"

PAYLOAD="$(cat || true)"
FILE_PATH="$(printf '%s' "$PAYLOAD" | python -c 'import sys,json;d=json.load(sys.stdin);t=d.get("tool_input",{});print(t.get("file_path") or t.get("path") or "")' 2>/dev/null || echo "")"

if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then exit 0; fi

OUTPUT=""
STATUS=0

# ---- TODO: replace below with your stack's typecheck command(s) ----
#
# Python (mypy):
#   if [[ "$FILE_PATH" == *.py ]]; then
#     pushd "${CLAUDE_PROJECT_DIR:-.}/services/api" >/dev/null
#     if OUTPUT="$(uv run --quiet mypy "$FILE_PATH" 2>&1)"; then STATUS=0; else STATUS=$?; fi
#     popd >/dev/null
#   fi
#
# TypeScript (tsc):
#   if [[ "$FILE_PATH" == *.ts || "$FILE_PATH" == *.tsx ]]; then
#     pushd "${CLAUDE_PROJECT_DIR:-.}/apps/mobile" >/dev/null
#     if OUTPUT="$(pnpm exec tsc --noEmit 2>&1)"; then STATUS=0; else STATUS=$?; fi
#     popd >/dev/null
#   fi
#
# Go: go vet ./...   |   Rust: cargo check   |   etc.
# --------------------------------------------------------------------

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
