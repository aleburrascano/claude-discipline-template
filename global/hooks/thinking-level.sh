#!/bin/bash
# Hook: Contextual Extended Thinking Control
# Event: UserPromptSubmit
# Purpose: Adjust reasoning depth based on prompt complexity/content
# Reads: prompt text, transcript
# Writes: decision on thinking_level (min|standard|max)

set -e

# Read hook input
input=$(cat)
prompt=$(echo "$input" | jq -r '.hookSpecificInput.prompt // empty')

if [ -z "$prompt" ]; then
  exit 0
fi

# Complexity signals that warrant deep thinking
complexity_keywords=(
  "refactor"
  "architecture"
  "design"
  "complex"
  "debug"
  "edge case"
  "bug"
  "security"
  "performance"
  "optimization"
  "algorithm"
)

# Quick keywords (don't need deep thinking)
quick_keywords=(
  "add comment"
  "rename"
  "typo"
  "format"
  "reorder"
  "move file"
)

# Check for quick tasks
for keyword in "${quick_keywords[@]}"; do
  if echo "$prompt" | grep -qi "$keyword"; then
    # Simple task - use minimal thinking
    echo '{
      "continue": true,
      "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "thinkingLevel": "min"
      }
    }'
    exit 0
  fi
done

# Check for complex tasks
complexity_score=0
for keyword in "${complexity_keywords[@]}"; do
  if echo "$prompt" | grep -qi "$keyword"; then
    ((complexity_score++))
  fi
done

# If multiple complexity signals, use max thinking
if [ "$complexity_score" -gt 1 ]; then
  echo '{
    "continue": true,
    "hookSpecificOutput": {
      "hookEventName": "UserPromptSubmit",
      "thinkingLevel": "max"
    }
  }'
  exit 0
fi

# If one complexity signal, use standard
if [ "$complexity_score" -eq 1 ]; then
  echo '{
    "continue": true,
    "hookSpecificOutput": {
      "hookEventName": "UserPromptSubmit",
      "thinkingLevel": "standard"
    }
  }'
  exit 0
fi

# Default: standard thinking
echo '{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "thinkingLevel": "standard"
  }
}'
