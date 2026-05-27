#!/bin/bash
# session-common-ground.sh — SessionStart hook (Layer 4)
#
# When a session starts in a directory containing code, inject the common-ground
# protocol via additionalContext so Claude surfaces its assumptions before any work.
# Honors CLAUDE.md rule "don't rely on implicit skill activation" — the hook does
# the work, no slash command needed.
#
# Off switch: CLAUDE_SKIP_COMMON_GROUND=1
# Skip if a fresh common-ground.md (modified <14 days) already exists in cwd.

set -uo pipefail

input=$(cat)

if [ "${CLAUDE_SKIP_COMMON_GROUND:-}" = "1" ]; then
  echo '{}'
  exit 0
fi

cwd=$(jq -r '.cwd // ""' <<<"$input")
if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
  echo '{}'
  exit 0
fi

# Code-project heuristic: any of these markers in cwd or one level down.
is_code_project=0
for marker in package.json pyproject.toml setup.py Cargo.toml go.mod pom.xml build.gradle Gemfile composer.json *.csproj *.sln; do
  if compgen -G "$cwd/$marker" >/dev/null 2>&1; then
    is_code_project=1
    break
  fi
done

if [ "$is_code_project" -eq 0 ]; then
  echo '{}'
  exit 0
fi

# If a recently-validated common-ground.md exists, skip.
cg_file="$cwd/common-ground.md"
if [ -f "$cg_file" ]; then
  if find "$cg_file" -mtime -14 2>/dev/null | grep -q .; then
    echo '{}'
    exit 0
  fi
fi

reminder='Code-project session. Before non-trivial work, surface hidden assumptions across: Architecture, Tooling, Constraints, Domain. Tag each [ESTABLISHED] (read files this session), [WORKING] (convention default), or [OPEN] (not yet validated). Wait for user confirmation before acting. Persist confirmed assumptions to common-ground.md. Skip for trivial work (typo, single-file edit, quick lookup).'

jq -n --arg ctx "$reminder" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
