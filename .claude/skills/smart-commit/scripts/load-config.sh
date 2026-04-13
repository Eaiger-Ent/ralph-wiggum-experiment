#!/bin/bash
# Load repository commit configuration
# Returns: JSON with commit type/scope configuration

set -e

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

HAS_COMMITLINT="false"
SCOPE_ENUM="[]"

if [ -f "$REPO_ROOT/.commitlintrc.json" ] && command -v jq >/dev/null 2>&1; then
  HAS_COMMITLINT="true"
  SCOPE_ENUM=$(jq -r '.rules["scope-enum"][2] // []' "$REPO_ROOT/.commitlintrc.json" 2>/dev/null || echo "[]")
fi

# Derive scopes from top-level directories in the repo
AUTO_SCOPES=$(find "$REPO_ROOT" -maxdepth 1 -mindepth 1 -type d \
  ! -name '.git' ! -name '.claude' ! -name '.devcontainer' ! -name 'node_modules' \
  -exec basename {} \; 2>/dev/null | jq -R . | jq -sc . 2>/dev/null || echo '[]')

# Always include common non-code scopes
BASE_SCOPES='["docs","devcontainer","skills","ci","deps"]'
AVAILABLE_SCOPES=$(jq -n --argjson auto "$AUTO_SCOPES" --argjson base "$BASE_SCOPES" '$auto + $base | unique' 2>/dev/null || echo "$BASE_SCOPES")

if [ "$SCOPE_ENUM" != "[]" ]; then
  AVAILABLE_SCOPES="$SCOPE_ENUM"
fi

ALLOWED_TYPES='["feat","fix","docs","test","ci","infra","chore","refactor","perf","revert"]'

cat <<EOF
{
  "repository": {
    "root": "$REPO_ROOT",
    "type": "generic"
  },
  "commitlint": {
    "has_config": $HAS_COMMITLINT
  },
  "scopes": {
    "available": $AVAILABLE_SCOPES
  },
  "types": {
    "allowed": $ALLOWED_TYPES
  }
}
EOF
