---
name: smart-commit
description: >
  Create a Conventional Commits conformant commit message with AI assistance. Analyses diff,
  stages, commits, and optionally pushes. Triggers: 'commit', 'git commit', '/smart-commit'.
argument-hint: "[--auto] [--all | <files...>]"
disable-model-invocation: true
allowed-tools: AskUserQuestion, Bash, Read, Glob, Grep
---

# Create a Conventional Commits conformant commit message with AI assistance

**Arguments**: $ARGUMENTS

Set this variable once so subsequent script calls are readable:

```bash
SCRIPTS=$(git rev-parse --show-toplevel)/.claude/skills/smart-commit/scripts
```

**Do not use when:** committing to a branch with an active PR in review — use standard git commit to avoid disrupting review history.

## Inputs

| Input | Required | Default | Fallback behaviour |
| --- | --- | --- | --- |
| `--auto` flag | No | omitted | prompt user at Steps 5 and 7 |
| `--all` flag | No | omitted | use currently staged files only |
| `<files...>` (specific paths) | No | omitted | use currently staged files only |
| Both `--all` and `<files...>` | No | N/A | specific paths take precedence; emit warning |

If no arguments are provided, the skill uses whatever is currently staged (`git diff --cached`).
If nothing is staged and `--all` is absent, the skill prompts for file selection (see Step 0).

## Step 0: Pre-flight Checks and File Selection

Before staging: check `git status` — if nothing staged and no untracked files, emit the blocked output from the Output template section and stop.

```bash
bash "$SCRIPTS/pre-flight-check.sh"
```

If exit code is `1` (fatal error), stop and report the error.
If exit code is `2` (no staged changes), prompt the user:
- Run with `--all` to stage all modified files
- Or specify which files to stage

Get working state:

```bash
bash "$SCRIPTS/get-working-state.sh"
```

Parse JSON output for staged/unstaged/untracked files.

Handle file selection based on arguments:

- **No arguments**: use currently staged files
- **`--all`**: `git add -A` (modified, deleted, and untracked files) then proceed — this
  stages everything including new files; `.gitignore` exclusions still apply
- **File paths**: stage only the specified files
- **Both `--all` and specific file paths**: specific file paths take precedence; emit a warning: "Warning: both --all and specific paths provided — staging only the specified paths."

## Step 1: Analyse Changes

```bash
bash "$SCRIPTS/analyse-diff.sh"
```

Parse JSON output for change patterns, statistics, and type/scope suggestions.

## Step 2: Load Configuration

```bash
bash "$SCRIPTS/load-config.sh"
```

Parse JSON for available scopes and allowed commit types.

## Step 3: Detect Breaking Changes

```bash
bash "$SCRIPTS/detect-breaking.sh"
```

Parse JSON for breaking change indicators. If breaking changes detected, note the severity
and ensure the commit message includes the appropriate footer or `!` modifier.

## Step 3.5: Documentation Currency Check

Read `.claude/skills/smart-commit/smart-commit-rules.md` (§Documentation currency signals)
for the full signal→doc mapping. Check whether relevant documentation files are included in
the staged changes. If gaps are identified, present them as context text, then ask:

```text
These files may need updating before committing:
  - <file> — <reason>

Options:
  1. Help me update the docs now (pause commit)
  2. I've already updated the docs — proceed
  3. No documentation updates needed — proceed
```

## Step 3.6: README Quality Check (if applicable)

If README.md is among the staged files, ask:

```text
README.md is staged. Run /readme-check on it first? (yes / no)
```

## Step 4: Compose Commit Message

Read `.claude/skills/smart-commit/smart-commit-rules.md` for the full type-selection table,
scope list, format spec, and worked example. Apply the first matching type row.

Compose a message following Conventional Commits v1.0.0:

```text
<type>[scope]: <description>

[optional body]

[optional footer(s)]
```

## Step 5: Present to Developer

Display the proposed commit message as a code block.

If `--auto` is in the arguments: proceed directly to Step 6 without asking.

Otherwise, use `AskUserQuestion` with two options:

- label: "Commit", description: "Commit with this message"
- label: "Cancel", description: "Abort without committing"

Ask: "Commit with this message?"

If `Cancel`: stop and emit the Aborted output block from the Output template section.

## Step 6: Execute Commit

If confirmed:

```bash
git commit -m "$(cat <<'EOF'
<type>[scope]: <description>

<body if any>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

Display commit hash and branch on success.

## Step 7: Push to Remote

Display the commit hash and branch.

If `--auto` is in the arguments: push immediately without asking.

Otherwise, use `AskUserQuestion` with two options:

- label: "Push", description: "Push to remote"
- label: "Skip", description: "Leave as a local commit"

Ask: "Push to remote?"

If `Push` or `--auto`:

```bash
bash "$SCRIPTS/check-remote-state.sh"
```

Parse JSON:

- **`has_upstream: false`**: `git push -u origin <branch>`
- **`behind: 0`**: `git push`
- **`behind > 0`**: warn the user ("Remote has N commits you don't have locally") and
  offer to pull first — do not force push

Display push result on success.

## Step 8: Offer PR creation (non-main branches only)

If the current branch is not `main` and the push succeeded:

1. **Idempotency check — run before any `gh pr create` call:**
   ```bash
   gh pr list --head "$(git rev-parse --abbrev-ref HEAD)" --state open --json number,url
   ```
   - If the output contains ≥1 entry: skip creation; display the existing PR URL and inform
     the user. Do not prompt for PR creation again.
   - If the output is empty (`[]`): proceed to step 2.

2. Check whether `gh pr create` is likely to work:
   ```bash
   gh auth status 2>&1
   ```
   If the output shows `GITHUB_TOKEN` as the auth method, PAT scope may be limited.

3. If `--auto` is set: attempt `gh pr create` directly and report the result — do not prompt.

4. Otherwise, offer with `AskUserQuestion`:
   - label: "Create PR", description: "Open a pull request on GitHub now"
   - label: "Skip", description: "I'll open the PR manually"

5. If creating the PR (no existing open PR found):
   ```bash
   gh pr create --title "<commit description>" --body "$(cat <<'EOF'
   ## Summary
   <bullet points from commit body>

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```

6. If `gh pr create` fails with `Resource not accessible by personal access token`:
   Report clearly:
   > PR creation failed — the GITHUB_TOKEN in `.devcontainer/.env` needs additional scopes:
   > - **Classic PAT**: requires the `repo` scope
   > - **Fine-grained PAT**: requires **Pull requests: Read and Write** + **Contents: Read and Write**

## Error Handling

- **Empty diff / no staged changes**: emit the Blocked output block and stop — do not proceed to Step 1
- **PR already exists (open)**: detected at Step 8 idempotency check; display existing PR URL and skip creation
- **Merge conflicts in staged files**: block commit, show conflict files
- **Detached HEAD**: block commit with explanation
- **Large changeset (>30 files)**: warn and suggest splitting
- **Pre-commit hook failure**: show hook output, suggest fixes — do NOT use `--no-verify`

## Output template

**Success — committed only:**
```
### Run complete

**Status:** ✅ Success

**Actions taken:**
- Staged: <file list or "--all">
- Committed: "<type>(<scope>): <description>" (<hash>)

**Output:** <branch> — commit <hash>
```

**Blocked — nothing to commit:**
```
### Run blocked

**Status:** ❌ Blocked

**Reason:** WARNING: no staged changes found — nothing to commit.

**Next step:** Stage files with `git add <files>` or re-run with `--all`.
```

**Aborted — user cancelled:**
```
### Run complete

**Status:** ⚠️ Aborted

**No changes made.** User chose Cancel at Step 5 — no commit created.
Re-run is safe — no side effects occurred.
```

## Standards and co-update partners

Commit messages follow Conventional Commits v1.0.0 (<https://www.conventionalcommits.org>).

The scope list is project-specific and is maintained in
`.claude/skills/smart-commit/smart-commit-rules.md` — update that file if new top-level
directories are added.
