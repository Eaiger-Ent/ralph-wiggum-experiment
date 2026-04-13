---
name: skill-improver
description: "Apply audit-backed improvements to a skill. Fixes all flagged dimensions using standard output templates. Triggers: improve skill X, fix skill gaps, apply audit fixes. For scoring use /skill-review."
argument-hint: "skill-name or --all [--audit path/to/audit.md]"
disable-model-invocation: true
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, Agent
---

# Skill Improver

Applies all ⚠️ and ❌ improvements from an audit report to a skill's SKILL.md and sub-flow
files. Does not touch dimensions that already scored ✅.

## Inputs

**Required:** skill name (e.g. `adr-review`), partial name (e.g. `adr`), or `--all`.

**Optional:** `--audit <path>` — specific audit file. Defaults to the most recent
`docs/skill-reviews/audit-*.md`.

**Missing input behaviour:** if no skill name is given, ask:
> "Which skill would you like me to improve? Provide the skill name (e.g. `smart-commit`) or
> `--all` to improve all skills with open gaps."

**Re-run behaviour:** if the skill is run on a skill that has already been improved (all
dimensions ✅ in the loaded audit), it emits "No improvements needed — `<name>` has no
⚠️ or ❌ in the loaded audit." and stops without modifying any files.

## Step 1 — Identify the target

- Resolve to `.claude/skills/<name>/SKILL.md`.
- Partial name: `Glob .claude/skills/<name>*/SKILL.md`; if multiple match, ask which.
- `--all`: jump to Step 6 (batch mode).
- Not found: emit `ERROR: skill not found at .claude/skills/<name>/SKILL.md` and stop.

## Step 2 — Load the audit

1. If `--audit <path>` provided, read that file.
2. Otherwise: `Glob docs/skill-reviews/audit-*.md` — read the most recent (lexicographic sort).
3. Find the section for this skill (search for the skill name as a heading or table row).
4. Extract all ⚠️ and ❌ dimensions with their evidence and fix text.

**Edge cases:**
- No audit file in `docs/skill-reviews/`: emit `ERROR: no audit file found — run /skill-review <name> first.` and stop.
- Skill not in audit: emit "No entry for `<name>` in `<audit-file>`. Run `/skill-review <name>` to generate one." and stop.
- No ⚠️ or ❌ found for skill: emit "No improvements needed — `<name>` has no ⚠️ or ❌ in the loaded audit." and stop.

## Step 3 — Read the skill

Read in this order:
1. `.claude/skills/<name>/SKILL.md`
2. All sub-flow files in the same directory

## Success criteria

The skill run succeeds when all of the following are true:
1. Every ❌ dimension from the audit now scores ✅ on post-fix `/skill-review`.
2. No ⚠️ dimension was made worse (no ⚠️→❌ regressions).
3. All cited file paths in added sections resolve via `Glob` before the edit is saved.

## Step 4 — Apply fixes in priority order

**Order:** ❌ before ⚠️. Within each tier: OA → EH → IN → RC → RS → TE → CV → SC → CO → ID → TR → OF.
**Rule:** do not touch any dimension that scored ✅ in the audit.

For each dimension fix:

- **OA**: Add or replace the `## Output template` section with concrete evidence + fix text + enumerated verdicts.
- **EH**: Add edge-case section covering file-not-found, ambiguous input, partial/empty artefact, named error output.
- **IN**: Add or update `## Inputs` section with Required/Optional/Missing behaviour.
- **RC**: Replace vague descriptors with specific observable elements. Add fallback rule.
- **RS**: Find and replace all instances of "sufficient", "adequate", "appropriate", "reasonable" in scoring criteria with counts, named lists, or explicit boundary values.
- **TE**: Extract stable rule blocks (>20 lines) to `<name>-rules.md`. Replace with `Read` instruction.
- **CV**: Add `## Calibration` section with strong and weak examples by path.
- **SC**: Add `## Standards and co-update partners` section with source citation.
- **TR**: Ensure `description` has ≥2 concrete trigger phrases. Add "do not use when" clause if needed.
- **OF**: Add ≥1 explicit filled-in output example block. Ensure structured output with named verdict.

## Step 5 — Verify with skill-review

After all edits, invoke `/skill-review <skill-name>` on the modified skill. Compare new scores against pre-improvement audit. For any dimension still ⚠️ or ❌, apply targeted fix and re-run. Repeat up to 2 attempts per dimension.

Output final report:

```
## Improvements applied: <skill-name>

| Dimension | Before | After | Change summary |
| --- | --- | --- | --- |
| OA | ❌ | ✅ | Added assessment output template |
| EH | ⚠️ | ✅ | Added file-not-found guard |

**Unchanged (already ✅):** TR, IN, RS, OF, ID, SC, CO

**Verdict:** Needs improvement → Optimised
```

## Step 6 — Batch mode (`--all`)

1. `Glob .claude/skills/*/SKILL.md` to list all skills.
2. Load the most recent audit from `docs/skill-reviews/`.
3. Identify skills with ≥1 ⚠️ or ❌. Skip skills with no open gaps.
4. Launch one sub-agent per skill (via `Agent` tool) to run Steps 1–5 in parallel.
5. Aggregate into a summary table.

## Edge cases

- **Already Optimised:** emit "No improvements needed." and stop.
- **Audit entry present but fix text absent for a dimension:** emit "WARNING: no fix text in audit for `<dimension>` in `<skill-name>` — skipping. Re-run `/skill-review <name>` to regenerate fix text." and skip that dimension.
- **TE extraction target already exists:** append to existing `<name>-rules.md`; do not overwrite.

## Standards and co-update partners

Co-update partners: `skill-review` — shares the 12-dimension rubric. If checklist wording changes, update both `skill-review` and `skill-improver` together.
