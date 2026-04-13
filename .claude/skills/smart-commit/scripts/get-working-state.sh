#!/bin/bash
# Get current working directory state
# Returns: JSON describing staged, unstaged, and untracked files

set -e

to_json_array() {
  if [ -z "$1" ]; then
    echo "[]"
  else
    echo "$1" | jq -R . | jq -s .
  fi
}

STAGED=$(git diff --cached --name-only 2>/dev/null || echo "")
STAGED_STATUS=$(git diff --cached --name-status 2>/dev/null || echo "")
UNSTAGED=$(git diff --name-only 2>/dev/null || echo "")
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null || echo "")

count_lines() {
  if [ -z "$1" ]; then echo 0; else echo "$1" | wc -l | tr -d ' '; fi
}

STAGED_COUNT=$(count_lines "$STAGED")
UNSTAGED_COUNT=$(count_lines "$UNSTAGED")
UNTRACKED_COUNT=$(count_lines "$UNTRACKED")

STAGED_ADDED=$(echo "$STAGED_STATUS" | grep "^A" | cut -f2- || echo "")
STAGED_MODIFIED=$(echo "$STAGED_STATUS" | grep "^M" | cut -f2- || echo "")
STAGED_DELETED=$(echo "$STAGED_STATUS" | grep "^D" | cut -f2- || echo "")
STAGED_RENAMED=$(echo "$STAGED_STATUS" | grep "^R" | cut -f2- || echo "")

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

HAS_UPSTREAM="false"
if git rev-parse --abbrev-ref @{u} > /dev/null 2>&1; then
  HAS_UPSTREAM="true"
fi

cat <<EOF
{
  "branch": "$CURRENT_BRANCH",
  "has_upstream": $HAS_UPSTREAM,
  "staged": {
    "files": $(to_json_array "$STAGED"),
    "count": $STAGED_COUNT,
    "added": $(to_json_array "$STAGED_ADDED"),
    "modified": $(to_json_array "$STAGED_MODIFIED"),
    "deleted": $(to_json_array "$STAGED_DELETED"),
    "renamed": $(to_json_array "$STAGED_RENAMED")
  },
  "unstaged": {
    "files": $(to_json_array "$UNSTAGED"),
    "count": $UNSTAGED_COUNT
  },
  "untracked": {
    "files": $(to_json_array "$UNTRACKED"),
    "count": $UNTRACKED_COUNT
  }
}
EOF
