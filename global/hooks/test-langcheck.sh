#!/bin/bash
# test-langcheck.sh — verification harness for post-write-langcheck.sh (Layer 9).
# Builds synthetic PostToolUse payloads, pipes them through the hook,
# asserts exit codes and stderr content. Run manually: ./test-langcheck.sh

set -uo pipefail

HOOK="$HOME/.claude/hooks/post-write-langcheck.sh"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0
FAIL_NAMES=()

run_case() {
  local name="$1" expected="$2" tool="$3" file_path="$4" must_contain="${5:-}"
  local input
  input=$(jq -nc --arg t "$tool" --arg p "$file_path" \
    '{tool_name:$t, tool_input:{file_path:$p}, hook_event_name:"PostToolUse"}')
  local stderr stdout actual
  stderr=$(mktemp)
  stdout=$("$HOOK" <<<"$input" 2>"$stderr")
  actual=$?
  local stderr_content
  stderr_content=$(cat "$stderr")
  rm -f "$stderr"

  local ok=1
  if [ "$actual" != "$expected" ]; then ok=0; fi
  if [ -n "$must_contain" ] && ! grep -qF -- "$must_contain" <<<"$stderr_content$stdout"; then ok=0; fi

  if [ "$ok" -eq 1 ]; then
    PASS=$((PASS + 1))
    echo "PASS: $name"
  else
    FAIL=$((FAIL + 1))
    FAIL_NAMES+=("$name (expected exit=$expected, got=$actual)")
    echo "FAIL: $name"
    echo "       stderr: $(head -c 400 <<<"$stderr_content")"
  fi
}

run_case_env() {
  local name="$1" expected="$2" envvar="$3" tool="$4" file_path="$5"
  local input
  input=$(jq -nc --arg t "$tool" --arg p "$file_path" \
    '{tool_name:$t, tool_input:{file_path:$p}, hook_event_name:"PostToolUse"}')
  local actual
  env "$envvar=1" "$HOOK" <<<"$input" >/dev/null 2>&1
  actual=$?
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
    echo "PASS: $name"
  else
    FAIL=$((FAIL + 1))
    FAIL_NAMES+=("$name (expected exit=$expected, got=$actual)")
    echo "FAIL: $name"
  fi
}

# --- Test fixtures ---------------------------------------------------------

PY_CLEAN="$TMPDIR/clean.py"
echo 'print("hi")' >"$PY_CLEAN"

PY_BAD="$TMPDIR/bad.py"
cat >"$PY_BAD" <<'EOF'
import os
import sys

print(undefined_variable)
EOF

GO_FILE="$TMPDIR/main.go"
echo 'package main' >"$GO_FILE"

RB_FILE="$TMPDIR/foo.rb"
echo 'puts "hi"' >"$RB_FILE"

SH_FILE="$TMPDIR/foo.sh"
echo '#!/bin/bash' >"$SH_FILE"

TS_FILE="$TMPDIR/foo.ts"
echo 'const x = 1' >"$TS_FILE"

MD_FILE="$TMPDIR/foo.md"
echo '# hi' >"$MD_FILE"

RS_FILE="$TMPDIR/foo.rs"
echo 'fn main() {}' >"$RS_FILE"

# --- Cases -----------------------------------------------------------------

# Layer 9 case 17 (Python ruff catches a real lint issue)
run_case "17a-py-undefined-name" 2 "Write" "$PY_BAD" "ruff"
run_case "17b-py-clean"          0 "Write" "$PY_CLEAN"

# Layer 9 case 18 — go vet missing on this system, so falls into 19 territory.
# When go IS installed we'd assert exit 2 on a vet violation; today it advises.
run_case "18-go-not-installed"   0 "Write" "$GO_FILE"

# Layer 9 case 19 (checker missing → advisory, no block)
run_case "19a-rb-not-installed"  0 "Write" "$RB_FILE"
run_case "19b-sh-not-installed"  0 "Write" "$SH_FILE"

# Pass-through cases (handled elsewhere or non-source)
run_case "ts-handoff-to-typecheck"     0 "Write" "$TS_FILE"
run_case "md-non-source-skip"          0 "Write" "$MD_FILE"

# Rust outside a crate → cargo can't run, advisory path
run_case "rs-no-cargo-toml"      0 "Write" "$RS_FILE"

# Defensive guards
run_case "non-existent-file"     0 "Write" "/no/such/path.py"
run_case "non-write-tool"        0 "Bash"  "$PY_BAD"

# Off-switches
run_case_env "skip-langcheck-env"      0 "CLAUDE_SKIP_LANGCHECK" "Write" "$PY_BAD"
run_case_env "skip-ruff-env"           0 "CLAUDE_SKIP_RUFF"      "Write" "$PY_BAD"

# ---------------------------------------------------------------------------
echo
echo "============================================"
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  echo "Failures:"
  for n in "${FAIL_NAMES[@]}"; do echo "  - $n"; done
  exit 1
fi
echo "All cases passed."
