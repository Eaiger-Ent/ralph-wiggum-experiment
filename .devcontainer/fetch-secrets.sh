#!/usr/bin/env bash
# Runs on the host before container start.
# Fetches secrets from macOS Keychain into .devcontainer/.env for container injection.
#
# Keychain service names are generic (no per-repo prefix) so a single host-side
# credential store is reused across every ralph-based project.
#
# Per-project overrides: prefix any secret name with the repo slug in UPPER_SNAKE_CASE.
# The prefixed key takes precedence over the generic one, letting you override a single
# project without touching the shared credential.
#
# Example: directory "ralph-wiggum-experiment" → prefix RALPH_WIGGUM_EXPERIMENT
#   RALPH_WIGGUM_EXPERIMENT_CLAUDE_OAUTH_TOKEN overrides CLAUDE_OAUTH_TOKEN for this repo.
#
# Claude Code auth — OAuth token preferred (subscription billing),
# API key is the pay-per-token fallback. Store one or both:
#   security add-generic-password -a "$USER" -s "CLAUDE_OAUTH_TOKEN"   -w "sk-ant-oat01-..."
#   security add-generic-password -a "$USER" -s "ANTHROPIC_API_KEY"    -w "sk-ant-..."
#
# Optional secrets:
#   security add-generic-password -a "$USER" -s "GITHUB_TOKEN"      -w "ghp_..."
#   security add-generic-password -a "$USER" -s "GIT_AUTHOR_NAME"   -w "Your Name"
#   security add-generic-password -a "$USER" -s "GIT_AUTHOR_EMAIL"  -w "you@example.com"
set -e

echo "==> Fetching secrets from Keychain..."

: > .devcontainer/.env

# Derive prefix from directory name: "ralph-wiggum-experiment" → "RALPH_WIGGUM_EXPERIMENT"
PROJECT_PREFIX=$(basename "$PWD" | tr '[:lower:]-' '[:upper:]_')

# Fetch secret: tries ${PROJECT_PREFIX}_${1} first, then ${1}.
# Sets LAST_SECRET_KEY to the Keychain service name that was resolved.
fetch_secret() {
  local name="$1"
  local prefixed="${PROJECT_PREFIX}_${name}"
  local value
  value=$(security find-generic-password -a "$USER" -s "$prefixed" -w 2>/dev/null) || true
  if [ -n "$value" ]; then
    LAST_SECRET_KEY="$prefixed"
    printf '%s' "$value"
    return
  fi
  value=$(security find-generic-password -a "$USER" -s "$name" -w 2>/dev/null) || true
  LAST_SECRET_KEY="$name"
  printf '%s' "$value"
}

CLAUDE_CODE_OAUTH_TOKEN=$(fetch_secret "CLAUDE_OAUTH_TOKEN")
if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
  echo "CLAUDE_CODE_OAUTH_TOKEN=${CLAUDE_CODE_OAUTH_TOKEN}" >> .devcontainer/.env
  echo "  ✓ CLAUDE_CODE_OAUTH_TOKEN written (subscription billing) [${LAST_SECRET_KEY}]"
fi

ANTHROPIC_API_KEY=$(fetch_secret "ANTHROPIC_API_KEY")
if [ -n "$ANTHROPIC_API_KEY" ]; then
  echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" >> .devcontainer/.env
  echo "  ✓ ANTHROPIC_API_KEY written (pay-per-token fallback) [${LAST_SECRET_KEY}]"
fi

if [ -z "$CLAUDE_CODE_OAUTH_TOKEN" ] && [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "  ✗ No Claude credential found in Keychain"
  echo "    Store one (OAuth preferred):"
  echo "      security add-generic-password -a \"\$USER\" -s \"CLAUDE_OAUTH_TOKEN\" -w \"sk-ant-oat01-...\""
  echo "      security add-generic-password -a \"\$USER\" -s \"ANTHROPIC_API_KEY\"  -w \"sk-ant-...\""
  exit 1
fi

# Optional: GitHub token
GITHUB_TOKEN=$(fetch_secret "GITHUB_TOKEN")
if [ -n "$GITHUB_TOKEN" ]; then
  echo "GITHUB_TOKEN=${GITHUB_TOKEN}" >> .devcontainer/.env
  echo "  ✓ GITHUB_TOKEN written [${LAST_SECRET_KEY}]"
fi

# Optional: Git identity (pre-configures git inside the container)
GIT_AUTHOR_NAME=$(fetch_secret "GIT_AUTHOR_NAME")
GIT_AUTHOR_EMAIL=$(fetch_secret "GIT_AUTHOR_EMAIL")
if [ -n "$GIT_AUTHOR_NAME" ]; then
  echo "GIT_AUTHOR_NAME=${GIT_AUTHOR_NAME}" >> .devcontainer/.env
  echo "GIT_COMMITTER_NAME=${GIT_AUTHOR_NAME}" >> .devcontainer/.env
  echo "  ✓ GIT_AUTHOR_NAME written [${LAST_SECRET_KEY}]"
fi
if [ -n "$GIT_AUTHOR_EMAIL" ]; then
  echo "GIT_AUTHOR_EMAIL=${GIT_AUTHOR_EMAIL}" >> .devcontainer/.env
  echo "GIT_COMMITTER_EMAIL=${GIT_AUTHOR_EMAIL}" >> .devcontainer/.env
  echo "  ✓ GIT_AUTHOR_EMAIL written [${LAST_SECRET_KEY}]"
fi

echo "  ✓ Secrets written to .devcontainer/.env"
