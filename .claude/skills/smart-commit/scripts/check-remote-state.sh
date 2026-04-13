#!/bin/bash
# Check remote state relative to upstream branch
# Returns: JSON with divergence info (behind/ahead counts)
# Note: does NOT use set -e — git fetch may fail gracefully

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "")

if [ -z "$UPSTREAM" ]; then
  cat <<EOF
{
  "has_upstream": false,
  "behind": 0,
  "ahead": 0,
  "branch": "$BRANCH",
  "upstream": "",
  "fetch_ok": false
}
EOF
  exit 0
fi

FETCH_OK=true
if ! git fetch --quiet 2>/dev/null; then
  FETCH_OK=false
fi

BEHIND=$(git rev-list HEAD..@{u} --count 2>/dev/null || echo "0")
AHEAD=$(git rev-list @{u}..HEAD --count 2>/dev/null || echo "0")

cat <<EOF
{
  "has_upstream": true,
  "behind": $BEHIND,
  "ahead": $AHEAD,
  "branch": "$BRANCH",
  "upstream": "$UPSTREAM",
  "fetch_ok": $FETCH_OK
}
EOF
