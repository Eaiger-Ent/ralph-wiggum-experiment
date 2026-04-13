#!/bin/bash
# Pre-flight checks before commit analysis
# Returns: 0=pass, 1=fatal error, 2=warning (no staged changes)

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

error() { echo -e "${RED}ERROR:${NC} $1" >&2; exit 1; }
warning() { echo -e "${YELLOW}WARNING:${NC} $1" >&2; }
success() { echo -e "${GREEN}✓${NC} $1"; }

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  error "Not a git repository"
fi
success "Git repository detected"

if ! git symbolic-ref -q HEAD > /dev/null 2>&1; then
  error "Detached HEAD state detected. Cannot commit in this state."
fi
success "HEAD is attached to a branch"

CONFLICT_FILES=$(git diff --cached --name-only --diff-filter=U 2>/dev/null || true)
if [ -n "$CONFLICT_FILES" ]; then
  error "Conflict markers detected in staged files:\n$CONFLICT_FILES\n\nResolve conflicts before committing."
fi
success "No merge conflicts detected"

if git diff --cached --quiet 2>/dev/null; then
  warning "No staged changes detected"
  exit 2
fi
success "Staged changes detected"

GIT_DIR=$(git rev-parse --git-dir)
if [ -f "$GIT_DIR/MERGE_HEAD" ]; then
  warning "Repository is in merge state"
elif [ -d "$GIT_DIR/rebase-merge" ] || [ -d "$GIT_DIR/rebase-apply" ]; then
  warning "Repository is in rebase state"
elif [ -f "$GIT_DIR/CHERRY_PICK_HEAD" ]; then
  warning "Repository is in cherry-pick state"
fi

exit 0
