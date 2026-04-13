---
name: ralph-guardrails
description: >
  Guardrails for safe ralph-loop execution. Use when running ralph-loop or working on
  PROMPT.md-driven tasks. Enforces protected files, pre-flight checks, phase gates,
  verification checklist, and error handling rules.
allowed-tools: Bash, Read, Glob, Grep
---

# Ralph Loop Guardrails

Guardrails for safe execution of ralph-loop automation sessions in this repo.

## Input specification

**Inputs:** None — this skill is invoked automatically at the start of a ralph-loop run. No user arguments are required.

**PROMPT.md guard:** Before running pre-flight checks, confirm the target phase prompt exists:

```bash
ls <phase-dir>/*.md 2>/dev/null | head -1
```

- If no `.md` file is found in the phase directory, stop: "No phase prompt found in `<phase-dir>/`. Cannot begin guardrails without a prompt file."
- If multiple step files exist but `00-pipeline.md` is absent, warn: "Warning: `00-pipeline.md` not found — `/ralph-pipeline` will not be able to run this phase."

## Pre-flight checks — run at the start of every iteration

Before doing any work, verify the following. If any check fails, fix it before proceeding — do not skip ahead.

1. **Tools present** — check only tools relevant to this project: `gh` (always), `git` (always), and any project-specific tools (e.g. `tofu`, `gcloud`, `uv`) only if referenced in the phase
2. **GCP credentials** — confirm `gcloud auth application-default print-access-token` succeeds if this is a GCP-enabled project and any infra work is planned; skip if gcloud is not used
3. **Git state clean** — run `git status`; if unexpected uncommitted changes exist from a prior iteration, investigate before adding more
4. **Tofu state consistent** — if `.tf` files exist in this project, run `tofu validate` before making changes; skip if OpenTofu is not used

Log a one-line summary of pre-flight results (e.g. `✓ pre-flight passed` or `✗ pre-flight: gcloud not authenticated`) before starting work.

## Phase gates — run between major phases

When the prompt describes multiple phases or deliverables, treat each phase as a gate:

1. Complete all work for the current phase
2. Run the relevant gate check (see below)
3. Log `✓ gate passed: <phase name>` or `✗ gate failed: <phase name> — <reason>` before moving to the next phase
4. If a gate fails, retry that phase up to **2 times** with a different approach before escalating

**Gate checks by deliverable type:**

| Deliverable | Gate check |
| --- | --- |
| Terraform / OpenTofu files | `tofu validate` (skip if not used in this project) |
| Shell scripts | `bash -n <script>` + confirm executable bit |
| Python files | `python3 -m py_compile <file>` |
| Markdown / docs | File is non-empty and referenced from CLAUDE.md or a runbook |
| Secrets / config | No placeholder values remain (`grep -rE 'REPLACE_ME\|YOUR_\|TODO'`) |

## Protected files — never edit during a ralph-loop run

- `~/.ralph/loop-state.md` — loop state, managed exclusively by the stop hook shell script
- `.claude/settings.json` — Claude Code configuration, not a deliverable
- `PROMPT.md`, `PROMPT2.md`, `PROMPT3.md`, `PROMPT4.md` — loop input prompts, not outputs

If completing a task appears to require modifying any of these files, stop and ask the user instead.

## Verification checklist before signaling completion

Before outputting the completion promise (`<promise>DONE</promise>` or equivalent), confirm ALL of the following are true:

1. All files listed as deliverables in the prompt exist and are non-empty
2. `tofu validate` passes if any `.tf` files were created or modified (skip if not used)
3. Any shell scripts created are executable (`chmod +x`) and pass `bash -n` syntax check
4. CLAUDE.md and any runbooks reference the new deliverables
5. No placeholder values (e.g. `REPLACE_ME`, `YOUR_`) remain in committed files

Output the completion promise only when every check passes. Do not output it to escape the loop.

## Git commit failure rules — non-negotiable

Read `.claude/skills/ralph-guardrails/ralph-guardrails-rules.md`

## Test failure rules — non-negotiable

A test has failed if its command exits non-zero **or** produces error output, regardless of what any surrounding `echo` statements say.

When a test fails:

1. **Diagnose** — read the full output; identify the exact root cause (missing package, wrong path, syntax error, etc.)
2. **Fix** — correct the code, config, or environment
3. **Re-run** — confirm the test now passes before proceeding
4. **Escalate** — if you cannot fix the failure after two attempts, stop immediately and report: what test failed, the exact error, and what you tried

**Never:**
- Proceed past a failing test without fixing it
- Treat a test error as "not yet" or "skipped"
- Suppress errors with `2>/dev/null` unless an explicit `[ -f <file> ]` guard fires first so only "file absent" is silenced
- Assume a test passed because the final `echo` line printed something plausible

## Error handling without touching loop state

If a command fails or a dependency is missing:

1. Diagnose the root cause before retrying
2. Fix the underlying issue (install missing tool, correct a path, etc.)
3. Do not edit `~/.ralph/loop-state.md` to work around the error
4. If the same approach has already failed once, try a different method rather than retrying identically
5. If stuck after two attempts, output a clear description of the blocker so the user can intervene on the next iteration

## Pre-flight output format

After running pre-flight checks, emit a summary using this template:

```text
Pre-flight — <phase-dir>
  ✓ tools:       gh, git found
  ✓ git-state:   clean (no unexpected changes)
✓ pre-flight passed — beginning phase work
```

If any check fails, use ✗ for the failing line and stop:

```text
  ✗ git-state:   unexpected uncommitted changes detected
✗ pre-flight failed — fix the issue above before proceeding
```

## Standards and co-update partners

Guardrail rules (pre-flight checks, gate checks, verification checklist) apply to every ralph-loop run. If any rule changes, the following skills must be co-updated:

| Standard | Shared with |
| --- | --- |
| Pre-flight check list (tools, git state) | `ralph-preflight` — also checks environment before pipeline runs |
| Phase gate checks by deliverable type | Any pipeline orchestration skills that run in this project |
| Verification checklist (all deliverables exist, no placeholder values) | Skills that generate prompts or phase definitions |

## Idempotency

Running the pre-flight checks on an already-clean environment produces the same `✓ pre-flight passed` output. No files are modified during pre-flight or gate checks.
