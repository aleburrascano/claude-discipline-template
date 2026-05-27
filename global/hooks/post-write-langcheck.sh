#!/bin/bash
# post-write-langcheck.sh — PostToolUse hook (Layer 9)
#
# After a Write or Edit on a source file, run the language-appropriate static check.
# Catches code-gen hallucinations (invented function names, type errors, undefined
# imports) at the moment they're written.
#
# .ts/.tsx/.js/.jsx — already covered by typecheck-changed.sh. Skip here.
# .py — ruff check (and mypy if config exists)
# .go — go vet
# .rs — cargo check (project-scope, only if Cargo.toml exists at or above the file)
# .rb — ruby -wc (parse-check only)
# .sh — shellcheck
#
# Exit 2 → block (checker found a real issue). Stderr explains.
# Exit 0 silent → file ok, or extension not handled, or checker not installed.
#
# Off switches: CLAUDE_SKIP_LANGCHECK=1 (all), CLAUDE_SKIP_RUFF=1, CLAUDE_SKIP_MYPY=1,
#               CLAUDE_SKIP_GOVET=1, CLAUDE_SKIP_CARGO=1, CLAUDE_SKIP_RUBYC=1,
#               CLAUDE_SKIP_SHELLCHECK=1

set -uo pipefail

if [ "${CLAUDE_SKIP_LANGCHECK:-}" = "1" ]; then
  exit 0
fi

input=$(cat)
tool_name=$(jq -r '.tool_name // ""' <<<"$input")
file_path=$(jq -r '.tool_input.file_path // ""' <<<"$input")

if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
  exit 0
fi

# Only run on Write / Edit-class tools.
case "$tool_name" in
  Write|Edit|MultiEdit) ;;
  *) exit 0 ;;
esac

ext="${file_path##*.}"
ext="${ext,,}"   # lowercase

# Print an advisory note to stderr without blocking. Exit 0.
advisory() {
  echo "post-write-langcheck: $*" >&2
}

run_or_block() {
  local label="$1"; shift
  local out
  if ! out=$("$@" 2>&1); then
    {
      echo "post-write-langcheck BLOCK ($label): issues in $file_path"
      echo
      echo "$out" | head -c 4000
      echo
      echo "Fix the reported issues, then continue."
    } >&2
    exit 2
  fi
}

case "$ext" in
  ts|tsx|js|jsx|mjs|cjs)
    # Covered by existing typecheck-changed.sh; nothing to do here.
    exit 0
    ;;
  py)
    if [ "${CLAUDE_SKIP_RUFF:-}" != "1" ] && command -v ruff >/dev/null 2>&1; then
      run_or_block "ruff" ruff check --no-cache "$file_path"
    elif [ "${CLAUDE_SKIP_RUFF:-}" != "1" ]; then
      advisory "ruff not on PATH; skipping (install: pip install ruff)"
    fi
    # Only run mypy if a config file is present at or above the file's directory.
    if [ "${CLAUDE_SKIP_MYPY:-}" != "1" ] && command -v mypy >/dev/null 2>&1; then
      dir=$(dirname "$file_path")
      while [ "$dir" != "/" ] && [ -n "$dir" ]; do
        for marker in mypy.ini setup.cfg pyproject.toml; do
          if [ -f "$dir/$marker" ]; then
            run_or_block "mypy" mypy --no-error-summary --no-color-output "$file_path"
            break 2
          fi
        done
        next=$(dirname "$dir")
        [ "$next" = "$dir" ] && break
        dir="$next"
      done
    fi
    ;;
  go)
    if [ "${CLAUDE_SKIP_GOVET:-}" != "1" ] && command -v go >/dev/null 2>&1; then
      run_or_block "go vet" go vet "$file_path"
    elif [ "${CLAUDE_SKIP_GOVET:-}" != "1" ]; then
      advisory "go not on PATH; skipping"
    fi
    ;;
  rs)
    if [ "${CLAUDE_SKIP_CARGO:-}" != "1" ] && command -v cargo >/dev/null 2>&1; then
      # cargo check operates on the whole crate. Locate Cargo.toml.
      dir=$(dirname "$file_path")
      crate_root=""
      while [ "$dir" != "/" ] && [ -n "$dir" ]; do
        if [ -f "$dir/Cargo.toml" ]; then crate_root="$dir"; break; fi
        next=$(dirname "$dir")
        [ "$next" = "$dir" ] && break
        dir="$next"
      done
      if [ -n "$crate_root" ]; then
        run_or_block "cargo check" bash -c "cd '$crate_root' && cargo check --quiet --message-format short"
      else
        advisory "no Cargo.toml found above $file_path; skipping cargo check"
      fi
    elif [ "${CLAUDE_SKIP_CARGO:-}" != "1" ]; then
      advisory "cargo not on PATH; skipping"
    fi
    ;;
  rb)
    if [ "${CLAUDE_SKIP_RUBYC:-}" != "1" ] && command -v ruby >/dev/null 2>&1; then
      run_or_block "ruby -wc" ruby -wc "$file_path"
    elif [ "${CLAUDE_SKIP_RUBYC:-}" != "1" ]; then
      advisory "ruby not on PATH; skipping"
    fi
    ;;
  sh|bash)
    if [ "${CLAUDE_SKIP_SHELLCHECK:-}" != "1" ] && command -v shellcheck >/dev/null 2>&1; then
      run_or_block "shellcheck" shellcheck "$file_path"
    elif [ "${CLAUDE_SKIP_SHELLCHECK:-}" != "1" ]; then
      advisory "shellcheck not on PATH; skipping (install: scoop install shellcheck OR cargo install shellcheck)"
    fi
    ;;
  *)
    # Extension not handled; silent pass.
    exit 0
    ;;
esac

exit 0
