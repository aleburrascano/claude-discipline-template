#!/usr/bin/env bash
# post-tool-commit-doc-drift: after `git commit`, check if code changed without touching
# expected doc artifacts; warn + suggest /update-docs-freshness.
# Override per-commit with [ALLOW-DRIFT: <reason>] in the commit body.

set -euo pipefail

LOG="${CLAUDE_PROJECT_DIR:-.}/.claude/hooks.log"
DRIFT_LOG="${CLAUDE_PROJECT_DIR:-.}/.claude/doc-drift.log"
mkdir -p "$(dirname "$LOG")"

PAYLOAD="$(cat || true)"
TOOL_NAME="$(printf '%s' "$PAYLOAD" | python -c 'import sys,json;d=json.load(sys.stdin);print(d.get("tool_name",""))' 2>/dev/null || echo "")"
COMMAND="$(printf '%s' "$PAYLOAD" | python -c 'import sys,json;d=json.load(sys.stdin);print(d.get("tool_input",{}).get("command",""))' 2>/dev/null || echo "")"

if [[ "$TOOL_NAME" != "Bash" ]] || [[ ! "$COMMAND" =~ git[[:space:]]+commit ]]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

LAST_MSG="$(git log -1 --pretty=%B 2>/dev/null || echo '')"
if [[ "$LAST_MSG" =~ \[ALLOW-DRIFT: ]]; then
  echo "[doc-drift] OVERRIDE on $(git rev-parse HEAD): $LAST_MSG" >> "$DRIFT_LOG"
  exit 0
fi

CHANGED="$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null || echo '')"
if [[ -z "$CHANGED" ]]; then exit 0; fi

WARNINGS=()

# ---- TODO: configure path → expected-doc mappings for your project ----
#
# Examples to adapt:
#
# # Code in a feature/context folder should touch docs/specs/<feature>/
# while IFS= read -r f; do
#   if [[ "$f" =~ src/(domain|application|adapters)/([^/]+)/ ]]; then
#     context="${BASH_REMATCH[2]}"
#     spec_dir="docs/specs/$context"
#     if [[ -d "$spec_dir" ]] && ! echo "$CHANGED" | grep -q "^$spec_dir/"; then
#       WARNINGS+=("Code in $context/ changed; $spec_dir/ not touched.")
#     fi
#   fi
# done <<<"$CHANGED"
#
# # Domain changes may need glossary updates
# if echo "$CHANGED" | grep -q "/domain/" && ! echo "$CHANGED" | grep -q "docs/ubiquitous-language.md"; then
#   WARNINGS+=("Domain changes detected; check docs/ubiquitous-language.md for new terms.")
# fi
# -----------------------------------------------------------------------

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  SHA="$(git rev-parse --short HEAD)"
  echo "[doc-drift] $SHA flagged:" >> "$DRIFT_LOG"
  for w in "${WARNINGS[@]}"; do echo "  - $w" >> "$DRIFT_LOG"; done

  MSG="⚠️ Doc drift after commit $SHA:\n"
  for w in "${WARNINGS[@]}"; do MSG+="  - $w\n"; done
  MSG+="\nRun /update-docs-freshness to address, or amend with [ALLOW-DRIFT: <reason>] in commit body."

  python - "$MSG" <<'PYEOF'
import json, sys
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": sys.argv[1]
    }
}))
PYEOF
fi

exit 0
