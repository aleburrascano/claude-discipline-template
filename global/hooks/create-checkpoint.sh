#!/bin/bash
set -e
input=$(cat)

# Only create checkpoint if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "$input"
  exit 0
fi

# Get the current git status
git_status=$(git status --short 2>/dev/null || true)

# Only checkpoint if there are uncommitted changes
if [ -z "$git_status" ]; then
  echo "$input"
  exit 0
fi

# Create a checkpoint commit with a timestamp
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
checkpoint_msg="checkpoint: ${timestamp} [auto-created by claude-code]"

# Stage all changes
git add -A 2>/dev/null || true

# Create the checkpoint commit (allow empty commits)
git commit --allow-empty -m "$checkpoint_msg" 2>/dev/null || true

echo "$input"
echo ""
echo "📍 Checkpoint created: $checkpoint_msg"
