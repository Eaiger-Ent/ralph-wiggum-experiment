#!/usr/bin/env bash
# Runs on the host before container start.
# Fetches secrets from macOS Keychain into .devcontainer/.env for container injection.
#
# To store your API key in the Keychain, run once on your Mac:
#   security add-generic-password -a "$USER" -s "RALPH_WIGGUM_ANTHROPIC_API_KEY" -w "sk-ant-..."
#
# Optional secrets (add to Keychain to enable):
#   security add-generic-password -a "$USER" -s "RALPH_WIGGUM_GITHUB_TOKEN" -w "ghp_..."
#   security add-generic-password -a "$USER" -s "RALPH_WIGGUM_GIT_AUTHOR_NAME" -w "Your Name"
#   security add-generic-password -a "$USER" -s "RALPH_WIGGUM_GIT_AUTHOR_EMAIL" -w "you@example.com"
set -e

echo "==> Fetching secrets from Keychain..."

ANTHROPIC_API_KEY=$(security find-generic-password -a "$USER" -s "RALPH_WIGGUM_ANTHROPIC_API_KEY" -w 2>/dev/null) || {
  echo "  ✗ RALPH_WIGGUM_ANTHROPIC_API_KEY not found in Keychain"
  echo "    Run: security add-generic-password -a \"\$USER\" -s \"RALPH_WIGGUM_ANTHROPIC_API_KEY\" -w \"sk-ant-...\""
  exit 1
}

echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" > .devcontainer/.env
echo "  ✓ ANTHROPIC_API_KEY written"

# Optional: GitHub token
GITHUB_TOKEN=$(security find-generic-password -a "$USER" -s "RALPH_WIGGUM_GITHUB_TOKEN" -w 2>/dev/null) || true
if [ -n "$GITHUB_TOKEN" ]; then
  echo "GITHUB_TOKEN=${GITHUB_TOKEN}" >> .devcontainer/.env
  echo "  ✓ GITHUB_TOKEN written"
fi

# Optional: Git identity (pre-configures git inside the container)
GIT_AUTHOR_NAME=$(security find-generic-password -a "$USER" -s "RALPH_WIGGUM_GIT_AUTHOR_NAME" -w 2>/dev/null) || true
GIT_AUTHOR_EMAIL=$(security find-generic-password -a "$USER" -s "RALPH_WIGGUM_GIT_AUTHOR_EMAIL" -w 2>/dev/null) || true
if [ -n "$GIT_AUTHOR_NAME" ]; then
  echo "GIT_AUTHOR_NAME=${GIT_AUTHOR_NAME}" >> .devcontainer/.env
  echo "GIT_COMMITTER_NAME=${GIT_AUTHOR_NAME}" >> .devcontainer/.env
  echo "  ✓ GIT_AUTHOR_NAME written"
fi
if [ -n "$GIT_AUTHOR_EMAIL" ]; then
  echo "GIT_AUTHOR_EMAIL=${GIT_AUTHOR_EMAIL}" >> .devcontainer/.env
  echo "GIT_COMMITTER_EMAIL=${GIT_AUTHOR_EMAIL}" >> .devcontainer/.env
  echo "  ✓ GIT_AUTHOR_EMAIL written"
fi

echo "  ✓ Secrets written to .devcontainer/.env"
