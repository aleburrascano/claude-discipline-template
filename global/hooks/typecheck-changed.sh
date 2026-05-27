#!/bin/bash
set -e
input=$(cat)

# Extract changed files from the tool result
# Look for TypeScript/JavaScript files that were modified
changed_files=$(echo "$input" | grep -E '\.(ts|tsx|js|jsx)$' 2>/dev/null | head -20 || true)

if [ -z "$changed_files" ]; then
  echo "$input"
  exit 0
fi

# Check if TypeScript is available
if ! command -v tsc &> /dev/null; then
  echo "$input"
  exit 0
fi

# Run typecheck on changed files
tsc_output=$(tsc --noEmit 2>&1 || true)

if [ -n "$tsc_output" ]; then
  echo "$input"
  echo ""
  echo "⚠️  TypeScript errors detected:"
  echo "$tsc_output"
else
  echo "$input"
fi
