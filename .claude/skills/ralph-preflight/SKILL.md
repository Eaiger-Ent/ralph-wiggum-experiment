---
name: ralph-preflight
description: >
  Validate a phase directory before implementation. Checks CLI tools, auth, secrets, and
  architecture conflicts. Produces a structured report; halts if any blockers are found.
  Triggers: 'preflight', 'pre-flight', 'check phase', '/ralph-preflight'.
argument-hint: "<phase-directory-path>"
---

**Do not invoke after phase implementation begins; use ralph-guardrails for in-progress phases.**

Running `/ralph-preflight` before starting a pipeline prevents costly mid-run failures caused by missing CLI auth, unset secrets, or changes that conflict with architectural constraints documented in `CLAUDE.md`. Without a preflight step, these issues are only discovered when a step fails — after time and tokens have already been spent. This skill parses the phase directory, checks environment readiness, scans for architectural conflicts, and produces a structured report. If any blockers are found the report is shown and execution stops — the pipeline should not be started until all blockers are resolved.

---

## Step 1 — Parse the phase directory

```bash
ls <phase-directory>/
```

**Missing file guards:**
- If `<phase-directory>/` does not exist: stop and report "Phase directory `<phase-directory>` not found. Check the path and try again."
- If `00-pipeline.md` is absent from the directory: stop and report "No `00-pipeline.md` found in `<phase-directory>`. This directory is not a valid phase — create a pipeline manifest first."
- If `00-pipeline.md` exists but is empty (0 bytes): stop and report "`00-pipeline.md` is empty — the phase is not yet configured."

Read `00-pipeline.md` and all numbered step `.md` files in the phase directory (exclude `concerns.md`, `README.md`).

From `00-pipeline.md`, extract:
- The `produces` list for every step — these are the deliverable file paths
- Any `requires` tokens — inter-step dependencies

From each step `.md` file, extract:
- **Deliverable file paths** — from `produces` tokens and any `| File |` deliverables tables
- **Referenced CLI tools** — grep for occurrences of: `gh`, `gcloud`, `node`, `npm`, `tofu`, `uv`, `git`
- **External dependencies** — note any mentions of external services
- **Protected files** — extract any "Must NOT be modified" or "No changes to" scope sections

Build three lists before proceeding:
1. `deliverables[]` — all file paths that will be created or modified
2. `required_tools[]` — deduplicated set of CLI tools referenced
3. `env_vars[]` — all `process.env.VARIABLE_NAME` and `$VARIABLE_NAME` patterns found in step files

---

## Step 2 — Environment checks

For each tool in `required_tools[]`, run the check command and classify as READY or BLOCKED.

| Tool | Check command | Expected output | Classification |
| --- | --- | --- | --- |
| `gh` | `gh auth status` | `Logged in to github.com` | READY / BLOCKED |
| `gcloud` | `gcloud auth list --filter=status:ACTIVE --format="value(account)"` | non-empty account | READY / BLOCKED |
| `node` | `node --version` | `v18` or higher | READY / BLOCKED |
| `npm` | `npm --version` | any version string | READY / BLOCKED |
| `git` | `git status` | exit code 0 | READY / BLOCKED |
| `tofu` | `tofu version` | any output — **only check if this is an infra phase** | READY / BLOCKED |
| `uv` | `uv --version` | any output — **only check if this is a Python phase** | READY / BLOCKED |

Only check tools that appear in `required_tools[]` or are referenced in the phase's step files. Skip tools not referenced (mark as ⬜ SKIPPED).

For each entry in `env_vars[]`, check presence without logging the value:
```bash
test -n "${VARIABLE_NAME}" && echo "SET" || echo "UNSET"
```

- `SET` → classify as ✅ READY
- `UNSET` → classify as ⛔ BLOCKED; include a remediation step such as: "Set `VARIABLE_NAME` in your shell environment or `.env` file before running the pipeline."

---

## Step 3 — Architecture conflict scan

Read `CLAUDE.md`.

For each path in `deliverables[]`, run these checks:

```bash
# Does the deliverable appear in a "No changes to" section?
grep -n "No changes to" CLAUDE.md | grep -i "<deliverable-basename>"

# Does the deliverable modify .claude/settings.json?
# If yes → warn: guard narrowing constraint — do not widen existing guards
```

Classify each finding:
- **Match in "No changes to" section** → ⚠️ RISK — architectural conflict; include the matched line
- **`.claude/settings.json` in deliverables** → ⚠️ RISK — do not widen existing permission guards
- **No conflicts found** → ✅ READY

---

## Step 4 — Produce report

After completing all checks, produce a structured report:

```
═══════════════════════════════════════════════════════════
RALPH PREFLIGHT — <phase-directory>
═══════════════════════════════════════════════════════════

ENVIRONMENT CHECKS
──────────────────
✅ READY    gh             Logged in to github.com as user@example.com
✅ READY    git            On branch main, clean working tree
⬜ SKIPPED  gcloud         Not referenced by this phase
⬜ SKIPPED  tofu           Not referenced by this phase

SECRET / ENV VAR CHECKS
────────────────────────
✅ READY    ANTHROPIC_API_KEY   SET

DELIVERABLES
─────────────
✅ READY    .claude/skills/my-skill/SKILL.md    (new file — path is writable)

ARCHITECTURE CONFLICTS
───────────────────────
✅ READY    No conflicts found in CLAUDE.md

═══════════════════════════════════════════════════════════
✅  ALL CLEAR — Pipeline is ready to run.
═══════════════════════════════════════════════════════════
```

If blockers exist:
```
═══════════════════════════════════════════════════════════
⛔  BLOCKED — 1 blocker found. Resolve before running the pipeline.
═══════════════════════════════════════════════════════════
```

---

## Step 5 — Halt on blockers

If any item is classified as ⛔ BLOCKED:
1. Present the full report
2. State clearly: "Pipeline is blocked. Resolve the items marked ⛔ BLOCKED above, then re-run `/ralph-preflight` before starting."
3. **Stop here.** Do not proceed with any implementation.

If no blockers (only ✅ READY, ⬜ SKIPPED, or ⚠️ RISK):
1. Present the full report
2. State: "All checks passed. The pipeline can proceed."
3. ⚠️ RISK items are advisory: highlight them but do not block

---

## Idempotency

Re-running on the same phase directory with unchanged environment state produces an identical report. This skill is read-only — no files are written, no external state is modified.

## Quality rules

- **Never log the value of environment variables** — report `SET` or `UNSET` only
- **All checks must be local** — do not invoke `curl`, `wget`, or any remote call during preflight
- **Report completeness** — every deliverable must appear in the report
- **Remediation steps** — every ⛔ BLOCKED item must include a concrete remediation instruction

## Standards and co-update partners

| Standard | Shared with |
| --- | --- |
| CLI tool presence checks | `ralph-guardrails` — runs identical pre-flight checks at each ralph-loop iteration |
