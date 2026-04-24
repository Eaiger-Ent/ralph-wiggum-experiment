# Secrets Reference

Secrets are stored in the macOS Keychain and injected into the devcontainer at
start time by `.devcontainer/fetch-secrets.sh`. They are never committed to the
repo.

> **Codespaces / Linux:** set secrets as Codespace or repository secrets in
> GitHub instead; the Keychain commands below are macOS-only.

## How project-specific overrides work

Every secret has a **generic** Keychain entry reused across all ralph-based
projects, and an optional **project-specific** override.

The override key is formed by prefixing the secret name with the repo directory
name in `UPPER_SNAKE_CASE`:

```
<REPO_SLUG>_<SECRET_NAME>
```

For example, if your repo directory is `ralph-wiggum-experiment`, the prefix is
`RALPH_WIGGUM_EXPERIMENT`, so the override for `ANTHROPIC_API_KEY` is
`RALPH_WIGGUM_EXPERIMENT_ANTHROPIC_API_KEY`.

`fetch-secrets.sh` tries the prefixed key first; if it is absent, the generic key
is used. This lets you point one cloned repo at a different credential without
touching the shared one.

## Supported secrets

| Keychain service name | Required | Purpose |
| --------------------- | -------- | ------- |
| `CLAUDE_OAUTH_TOKEN` | **One of the two Claude credentials is required** | Claude Code OAuth token (subscription billing, preferred) |
| `ANTHROPIC_API_KEY` | **One of the two Claude credentials is required** | Anthropic API key (pay-per-token fallback) |
| `GITHUB_TOKEN` | Optional | GitHub CLI authentication |
| `GIT_AUTHOR_NAME` | Optional | Git author name inside the container |
| `GIT_AUTHOR_EMAIL` | Optional | Git author email inside the container |

## Adding a secret

```bash
security add-generic-password -a "$USER" -s "<SERVICE_NAME>" -w "<VALUE>"
```

Examples:

```bash
# Claude OAuth token (preferred)
security add-generic-password -a "$USER" -s "CLAUDE_OAUTH_TOKEN" -w "sk-ant-oat01-..."

# Anthropic API key (fallback)
security add-generic-password -a "$USER" -s "ANTHROPIC_API_KEY" -w "sk-ant-..."

# GitHub token
security add-generic-password -a "$USER" -s "GITHUB_TOKEN" -w "ghp_..."

# Git identity
security add-generic-password -a "$USER" -s "GIT_AUTHOR_NAME" -w "Your Name"
security add-generic-password -a "$USER" -s "GIT_AUTHOR_EMAIL" -w "you@example.com"
```

For a project-specific override, prefix the service name with your repo slug:

```bash
security add-generic-password -a "$USER" \
  -s "RALPH_WIGGUM_EXPERIMENT_ANTHROPIC_API_KEY" \
  -w "sk-ant-..."
```

## Updating a secret

macOS will error if you try to add a key that already exists. Use `-U` to update:

```bash
security add-generic-password -U -a "$USER" -s "<SERVICE_NAME>" -w "<NEW_VALUE>"
```

## Checking a secret

Print the stored value (the terminal will prompt for Keychain access):

```bash
security find-generic-password -a "$USER" -s "<SERVICE_NAME>" -w
```

To verify all secrets that `fetch-secrets.sh` will pick up without starting the
container, run the script from the repo root:

```bash
bash .devcontainer/fetch-secrets.sh
```

Each resolved secret prints which Keychain service name was used, e.g.:

```
  ✓ CLAUDE_CODE_OAUTH_TOKEN written (subscription billing) [RALPH_WIGGUM_EXPERIMENT_CLAUDE_OAUTH_TOKEN]
  ✓ GITHUB_TOKEN written [GITHUB_TOKEN]
```

## Removing a secret

```bash
security delete-generic-password -a "$USER" -s "<SERVICE_NAME>"
```
