#!/bin/bash
# parry-guard-wrap.sh — PreToolUse hook (Layer 7)
#
# Wrapper for parry-guard (https://github.com/vaporif/parry) — a prompt-injection
# scanner that runs on tool inputs/outputs. This wrapper:
#
#   - Invokes parry-guard if it's on PATH (or one of its runtime wrappers).
#   - If parry-guard isn't installed, emits a one-line advisory to stderr
#     (suppressible) and exits 0 — fail-open until the binary is installed.
#
# Wired to PreToolUse on WebFetch (and other context-entry tools as desired)
# in settings.json. Parry-guard itself decides allow/block based on its own
# detection layers; this script just routes input to it.
#
# Env:
#   CLAUDE_SKIP_PARRY=1   — disable entirely
#   CLAUDE_PARRY_QUIET=1  — suppress the "not installed" advisory (default: warn once)
#   CLAUDE_PARRY_BIN=...  — explicit path to the binary, overrides PATH lookup

set -uo pipefail

input=$(cat)

if [ "${CLAUDE_SKIP_PARRY:-}" = "1" ]; then
  exit 0
fi

# Resolve binary.
PARRY=""
if [ -n "${CLAUDE_PARRY_BIN:-}" ] && [ -x "$CLAUDE_PARRY_BIN" ]; then
  PARRY="$CLAUDE_PARRY_BIN"
elif command -v parry-guard >/dev/null 2>&1; then
  PARRY="parry-guard"
elif command -v parry >/dev/null 2>&1; then
  PARRY="parry"
fi

if [ -z "$PARRY" ]; then
  if [ "${CLAUDE_PARRY_QUIET:-}" != "1" ]; then
    # Single-line advisory; exit 0 so the tool call still proceeds.
    echo "parry-guard not installed — Layer 7 (prompt-injection scan) is inactive. Install: cargo install --path bin OR nix-env -i parry-guard. Set CLAUDE_PARRY_QUIET=1 to silence this." >&2
  fi
  exit 0
fi

# Pass the hook event JSON through to parry-guard. It honors the same stdin/stdout
# hook contract as Anthropic-defined hooks, so its decision propagates as-is.
echo "$input" | "$PARRY" --pre-tool-use 2>&1
exit_code=$?

# Map parry-guard's exit code into the hook contract:
# 0 = allow, 2 = block, anything else = non-blocking error (treat as 0).
case "$exit_code" in
  0|2) exit "$exit_code" ;;
  *) exit 0 ;;
esac
