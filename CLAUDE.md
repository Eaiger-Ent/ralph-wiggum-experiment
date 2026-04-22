# [Your Project Name]

<!-- This file gives Claude Code context about your project.
     Fill in the sections below so Claude can assist you more effectively.
     Delete any sections that aren't relevant. -->

## Overview

<!-- What does this project do? What problem does it solve? -->

## Tech Stack

<!-- e.g. Node.js 22, TypeScript, React, PostgreSQL -->

## Project Structure

<!-- Describe the key directories and their purpose -->

## Development

### Build

```bash
# e.g. npm run build
```

### Test

```bash
# e.g. npm test
```

### Run

```bash
# e.g. npm start
```

## Conventions

<!-- Code style, naming conventions, patterns to follow -->

## Important Notes

<!-- Anything Claude should know: gotchas, constraints, external dependencies -->

## Devcontainer

- After container rebuilds, CLI tools (gcloud, gh, claude, tofu) may need reconfiguration.
- Always verify tool availability with `which <tool>` or `<tool> --version` before running commands that depend on them.
- Prefer apt-based installs over curl scripts or devcontainer features for gcloud and similar CLI tools — feature-based and curl installs have historically failed in this environment.

## Ralph Loop

This repo uses a ralph-loop automation mechanism.

- Do NOT modify ralph-loop config or state files unless explicitly asked.
- When running ralph-loop prompts, complete all verification checks before signaling completion.
- If a loop phase fails, log the error and surface it to the user — do not attempt to fix the loop mechanism itself.

## Skills

All skills are provided by the [ee-skills marketplace](https://github.com/Eaiger-Ent/ee-skills)
via Claude Code plugins. There are no local skill overrides in `.claude/skills/`.

To update skills to latest: `claude plugin update --scope project`
To add a new ee-skill: `claude plugin install --scope project <plugin-name>`
To contribute a local improvement back: `/submit-amendment <skill-name>`

### Installed ee-skills plugins

| Plugin | Skills provided | Category |
| --- | --- | --- |
| `ralph-loop` | `/ralph-loop`, `/cancel-ralph`, `/ralph-help` | Productivity |
| `ralph-pipeline` | `ralph-pipeline`, `ralph-guardrails`, `ralph-preflight`, `ralph-prompt-create`, `ralph-prompt-review`, `ralph-prompt-auto`, `ralph-parallel-subagents`, `phase-sync`, `phase-batch-plan` | Development |
| `adr-toolkit` | `adr-new`, `adr-check`, `adr-review`, `adr-approve`, `adr-refine`, `adr-status`, `adr-consistency` | Development |
| `skill-quality` | `skill-quality`, `skill-review`, `skill-improver` | Workflow |
| `issue-workflow` | `issue-readiness-check`, `issue-refine` | Workflow |
| `corpus` | `corpus-sync`, `corpus-query` | Workflow |
| `devcontainer-check` | `devcontainer-check` | Productivity |
| `fix-ci` | `fix-ci` | Productivity (GCP Cloud Build only) |
| `gherkin` | `gherkin` | Development |
| `likec4` | `likec4` | Development |
| `readme-check` | `readme-check` | Productivity |
| `settings-hygiene` | `settings-hygiene` | Workflow |
| `smart-commit` | `smart-commit` | Productivity |
| `ee-skills-manage` | `sync-skills`, `replace-with-marketplace`, `update-skills` | Workflow |
| `ee-skills-contribute` | `/submit-amendment` | Workflow |

### Optional dependencies

- `uv` + Python 3.13 + `duckdb` — required by `corpus-sync` / `corpus-query` (see `pyproject.toml`)
- `gh` — required by `issue-readiness-check`, `issue-refine`, `ralph-prompt-auto`, `phase-batch-plan`

### Skills requiring project customisation

- `ralph-prompt-auto` — reads this file's `## Tech Stack` section to classify phase type
- `fix-ci` — GCP Cloud Build only. Requires `CLAUDE_GCP_PROJECT` and `CLAUDE_GCP_REGION`

### GCP configuration (only if this project deploys to GCP)

| Env var | Used by | Required |
| --- | --- | --- |
| `CLAUDE_GCP_PROJECT` | `fix-ci`, `ralph-pipeline` | if invoking either skill |
| `CLAUDE_GCP_REGION` | `fix-ci`, `ralph-pipeline` | if invoking either skill |
| `CLAUDE_UAT_TRIGGER` | `ralph-pipeline` UAT step | only for UAT flow |
| `CLAUDE_UAT_SECRET` | `ralph-pipeline` secret lookup | only for UAT flow |
