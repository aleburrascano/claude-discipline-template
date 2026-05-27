#!/bin/bash
set -e
input=$(cat)

# Detect test runner based on project files
test_cmd=""

if [ -f "package.json" ]; then
  # Try npm test
  if grep -q '"test"' package.json 2>/dev/null; then
    test_cmd="npm test"
  fi
elif [ -f "Cargo.toml" ]; then
  test_cmd="cargo test"
elif [ -f "pytest.ini" ] || [ -f "setup.py" ]; then
  test_cmd="pytest"
elif [ -f "go.mod" ]; then
  test_cmd="go test ./..."
fi

if [ -z "$test_cmd" ]; then
  echo "$input"
  exit 0
fi

# Run tests
test_output=$(eval "$test_cmd" 2>&1 || true)

if echo "$test_output" | grep -qE "(FAIL|failed|error)" 2>/dev/null; then
  echo "$input"
  echo ""
  echo "❌ Tests failed after this change:"
  echo "$test_output" | tail -30
else
  echo "$input"
  echo ""
  echo "✅ Tests passed"
fi
