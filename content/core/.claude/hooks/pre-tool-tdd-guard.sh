#!/usr/bin/env bash
# pre-tool-tdd-guard: blocks writes to production code if no failing test exists for the change.
# Pragmatic heuristic. Allows bypass via [ALLOW-NO-TEST: <reason>] in the user prompt.
# Adapt the production-path detection and test-discovery heuristic for your stack.

set -euo pipefail

LOG="${CLAUDE_PROJECT_DIR:-.}/.claude/hooks.log"
mkdir -p "$(dirname "$LOG")"

PAYLOAD="$(cat || true)"
TOOL_NAME="$(printf '%s' "$PAYLOAD" | python -c 'import sys,json;d=json.load(sys.stdin);print(d.get("tool_name",""))' 2>/dev/null || echo "")"
FILE_PATH="$(printf '%s' "$PAYLOAD" | python -c 'import sys,json;d=json.load(sys.stdin);t=d.get("tool_input",{});print(t.get("file_path") or t.get("path") or "")' 2>/dev/null || echo "")"
PROMPT="$(printf '%s' "$PAYLOAD" | python -c 'import sys,json;d=json.load(sys.stdin);print(d.get("user_prompt",""))' 2>/dev/null || echo "")"

if [[ -z "$FILE_PATH" ]]; then exit 0; fi

# ---- Configure your production paths ----
# Default: files under any */src/ folder are production source, excluding tests/templates/init.
is_prod_src=false
if [[ "$FILE_PATH" == *"/src/"* ]]; then
  if [[ "$FILE_PATH" != *"/tests/"* ]] && [[ "$FILE_PATH" != *"/__tests__/"* ]] && \
     [[ "$FILE_PATH" != *"_template/"* ]] && [[ "$FILE_PATH" != *"__init__.py" ]]; then
    is_prod_src=true
  fi
fi
# Examples for narrower configuration:
#   if [[ "$FILE_PATH" =~ (<your-backend>/src/|<your-mobile-or-frontend>/src/) ]]; then is_prod_src=true; fi
#   if [[ "$FILE_PATH" =~ ^(internal|pkg|cmd)/ ]]; then is_prod_src=true; fi  # Go
# -----------------------------------------

if ! $is_prod_src; then exit 0; fi

# Explicit bypass
if [[ "$PROMPT" =~ \[ALLOW-NO-TEST: ]]; then
  echo "[tdd-guard] ALLOW no-test for $FILE_PATH (explicit override)" >> "$LOG"
  exit 0
fi

# Look for a sibling test file — multi-language heuristic
basename="$(basename "$FILE_PATH")"
stem="${basename%.*}"
relative="${FILE_PATH#*/src/}"
parent_dir="$(dirname "$FILE_PATH")"

test_candidates=(
  "${CLAUDE_PROJECT_DIR:-.}/tests/unit/${relative%/*}/test_${stem}.py"
  "${CLAUDE_PROJECT_DIR:-.}/tests/${relative%/*}/test_${stem}.py"
  "${parent_dir}/__tests__/${stem}.test.ts"
  "${parent_dir}/__tests__/${stem}.test.tsx"
  "${parent_dir}/${stem}.test.ts"
  "${parent_dir}/${stem}.test.tsx"
  "${parent_dir}/${stem}_test.go"
)

found_test=false
for candidate in "${test_candidates[@]}"; do
  [[ -f "$candidate" ]] && found_test=true && break
done

if $found_test; then
  echo "[tdd-guard] PASS for $FILE_PATH (test exists)" >> "$LOG"
  exit 0
fi

# No test found. Soft-warn on Write of new files; block on Edit of existing files.
if [[ "$TOOL_NAME" == "Write" ]] && [[ ! -f "$FILE_PATH" ]]; then
  echo "[tdd-guard] WARN new file $FILE_PATH has no companion test. Consider TDD-first." >&2
  exit 0
fi

reason="No companion test for $FILE_PATH. TDD discipline: write a failing test first. Override with [ALLOW-NO-TEST: <reason>] in your prompt if this edit is non-behavioral (rename, formatting)."
echo "[tdd-guard] BLOCK $FILE_PATH ($reason)" >> "$LOG"
cat <<EOF
{
  "decision": "block",
  "reason": "$reason",
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "$reason"
  }
}
EOF
exit 2
