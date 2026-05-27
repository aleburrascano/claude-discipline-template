#!/usr/bin/env bash
# stop-terminology-drift: scans changed source files for class/type names absent from
# docs/ubiquitous-language.md. Configurable for your stack via DOMAIN_PATHS regex.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
LOG="$PROJECT_DIR/.claude/hooks.log"
GLOSSARY="$PROJECT_DIR/docs/ubiquitous-language.md"
mkdir -p "$(dirname "$LOG")"

if [[ ! -f "$GLOSSARY" ]]; then exit 0; fi
cd "$PROJECT_DIR" 2>/dev/null || exit 0

# ---- TODO: configure DOMAIN_PATHS for your stack ----
# Examples:
#   DOMAIN_PATHS='<your-backend>/src/.*/domain/.*\.py$'
#   DOMAIN_PATHS='<your-mobile-or-frontend>/src/features/.*/types\.ts$'
#   DOMAIN_PATHS='internal/(domain|model)/.*\.go$'
DOMAIN_PATHS='(src|services|internal)/.*/(domain|model)/.*\.(py|ts|tsx|go|rs)$'
# -----------------------------------------------------

CHANGED="$(git diff --name-only HEAD 2>/dev/null | grep -E "$DOMAIN_PATHS" || true)"
if [[ -z "$CHANGED" ]]; then exit 0; fi

NEW_TERMS=()
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  # Generic extractor: Python `class Foo`, TS `class Foo`/`interface Foo`/`type Foo`,
  # Go `type Foo struct`, Rust `struct Foo`
  while IFS= read -r raw; do
    cls_name="$(echo "$raw" | sed -E 's/^.*(class|type|struct|interface)[[:space:]]+([A-Z][A-Za-z0-9_]*).*/\2/')"
    [[ -z "$cls_name" ]] && continue
    [[ "$cls_name" == _* ]] && continue
    if ! grep -qi "^[[:space:]]*[-*][[:space:]]*\*\*$cls_name\*\*" "$GLOSSARY" 2>/dev/null && \
       ! grep -qi "^[[:space:]]*[-*][[:space:]]*$cls_name[[:space:]]" "$GLOSSARY" 2>/dev/null; then
      NEW_TERMS+=("$cls_name (in $f)")
    fi
  done < <(grep -E '^(class|type|struct|interface) [A-Z]' "$f" 2>/dev/null || true)
done <<<"$CHANGED"

if [[ ${#NEW_TERMS[@]} -eq 0 ]]; then exit 0; fi

MSG="[terminology-drift] Domain terms in code not found in docs/ubiquitous-language.md:\n"
for t in "${NEW_TERMS[@]}"; do MSG+="  - $t\n"; done
MSG+="\nAdd them to the glossary in the same commit, or confirm they're not domain terms."

echo "[terminology-drift] flagged: ${NEW_TERMS[*]}" >> "$LOG"

python - "$MSG" <<'PYEOF'
import json, sys
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "Stop",
        "additionalContext": sys.argv[1]
    }
}))
PYEOF

exit 0
