---
name: skill-review
description: >
  Review skills against the 12-dimension quality rubric. Produces scored table, evidence-backed
  findings, token estimate, and top-3 improvements. Triggers: 'review skill', 'audit skill',
  'how good is X skill', '/skill-review'.
argument-hint: "<skill-name or --all>"
disable-model-invocation: true
allowed-tools: AskUserQuestion, ToolSearch, Read, Glob, Bash
---

# Skill Review

Reviews a Claude Code skill against the project's 12-dimension quality rubric, returning a scored
report with evidence, token estimate, and prioritised improvements.

## Inputs

- **Required:** skill name (e.g. `adr-review`), partial name (e.g. `adr`), or skill file path
- **Optional:** `--all` to audit all skills in batch mode
- **If empty:** ask which skill to review (handled in Step 1)

## Step 1 — Identify the target skill

Check `$ARGUMENTS`:

- **Skill name given** (e.g. `adr-review`, `smart-commit`): resolve to
  `.claude/skills/<name>/SKILL.md`.
- **Partial name given** (e.g. `adr`): run `Glob .claude/skills/<name>*/SKILL.md` to find candidates;
  if multiple match, fetch `AskUserQuestion` (`ToolSearch select:AskUserQuestion`) and ask which one.
- **No args given**: ask:
  > "Which skill would you like me to review? Provide the skill name (e.g. `adr-review`, `smart-commit`)."

If the resolved path does not exist: report "Skill not found at `.claude/skills/<name>/SKILL.md`" and stop.

**Partial or empty artefact handling:**
- If sub-flow files are absent, proceed with SKILL.md only — no error.
- If SKILL.md itself is empty, emit: `ERROR: [skill-name]/SKILL.md is empty — nothing to review.` and stop.

## Step 2 — Read the skill

Read in this order:

1. The target skill's `SKILL.md`.
2. Any sub-flow files in the same directory — read all.
3. Any external reference docs named in the skill — read to estimate their size.

## Step 3 — Score 12 dimensions

For each dimension, evaluate against the binary checklist. Count Y answers and apply the score mapping. If a question cannot be answered Y or N from the skill text alone, answer N.

| ID | Dimension | Checklist questions |
| --- | --- | --- |
| TR | Trigger Clarity | 3 questions — trigger phrases, exclusion clause, self-contained description |
| IN | Input Specification | 3 questions — required inputs listed, optional defaults, missing-input behaviour |
| RC | Rubric Completeness | 3 questions — observable criteria, non-overlapping, fallback rule (assessment); or success/failure criteria (workflow) |
| RS | Reproducibility | 4 questions — no subjective thresholds, observable sources, no forbidden terms, explicit boundary values |
| OA | Output Actionability | 4 questions — evidence quote, exact fix text, enumerated verdicts, selection rules |
| OF | Output Format | 3 questions — example block present, structured not prose, named verdict with finite values |
| TE | Token Efficiency | 3 questions — rule sets extracted, calibration by reference, no duplication |
| EH | Edge Handling | 4 questions — file-not-found, ambiguous input, partial/empty artefact, named error output |
| ID | Idempotency | 3 questions — stated behaviour on re-run, file-write guard, GitHub idempotency marker |
| SC | Standards Currency | 3 questions — source cited, co-update partners listed, shared rubrics not duplicated |
| CV | Calibration | 3 questions — strong example by path, weak example by path, artefacts are real |
| CO | Coherence | 3 questions — shared rubrics from canonical source, listed in relationship map, scoring conventions match |

For every ⚠️ or ❌ dimension, record:
1. **Evidence** — a direct quote from the skill file (or "This section is absent.")
2. **Fix** — the concrete text or structure to add

## Step 4 — Estimate token footprint

```bash
wc -l .claude/skills/<name>/SKILL.md
```

Run the same for any sub-flow files and named external docs. Report:

```
Token estimate
  SKILL.md:          ~<N> lines → ~<N> tokens
  Sub-flows:         ~<N> lines → ~<N> tokens
  External docs:     ~<N> lines → ~<N> tokens  (read per invocation)
  Total per invoke:  ~<N> tokens
```

Rough conversion: 1 line ≈ 10 tokens (conservative estimate for skill prose).

Flag if total exceeds 3,000 tokens as a TE concern.

## Step 5 — Write the report

Output in this exact order:

### Summary table

```
## Skill Review: <name>

| ID | Dimension           | Score | One-line finding                                    |
|----|---------------------|-------|-----------------------------------------------------|
| TR | Trigger Clarity     | ✅    | Trigger phrases listed; no overlap with peers       |
| IN | Input Specification | ⚠️    | Required inputs implied, not explicitly listed      |
...
```

### Per-dimension findings

Write a block **only for ⚠️ and ❌** — skip ✅. Format each as:

```
#### <ID> — <Dimension Name> <emoji>

**Evidence:** "<exact quote>" or "This section is absent."

**Fix:**
<concrete text to add, formatted as it would appear in the skill>
```

### Token footprint

Show the estimate from Step 4.

### Top 3 improvements

List the three highest-impact gaps in priority order. Priority = (severity of gap) × (frequency of skill use). ❌ in RC, RS, or OA always ranks above ⚠️ in any dimension.

### Verdict

```
**Verdict:** Optimised / Needs improvement / Major revision
```

- **Optimised** — all 12 ✅, or at most 2 ⚠️ in low-impact dimensions (ID, SC, CV)
- **Needs improvement** — one or more ❌, or three or more ⚠️
- **Major revision** — multiple ❌ in RC, RS, OA, or OF

## Step 6 — Seal all ❌ dimensions

After the report, apply fixes for every ❌ dimension in sequence without asking between each one:

1. Work through each ❌ dimension using the evidence + fix text from Step 5.
2. Apply with `Edit`.
3. After each edit, re-read the modified section and confirm the dimension would now score ✅ before moving to the next ❌.
4. Do not touch dimensions that scored ✅.

Once all ❌ are cleared, ask:

> "All ❌ dimensions are resolved. Would you like me to work through the ⚠️ dimensions as well, starting with the highest-impact gaps?"

---

## Batch audit mode

**Trigger:** user says "audit all skills", "review all skills", or passes `--all` as argument.

In this mode:
1. Run `Glob .claude/skills/*/SKILL.md` to list all skills.
2. For each skill, run this review as a **sub-agent** (via the `Agent` tool) — one agent per skill, all launched in parallel.
3. Aggregate results into a summary table.
4. Offer to save to `docs/skill-reviews/audit-<YYYY-MM-DD>.md`.

---

## Standards and co-update partners

Related skills that share the same rubric and must be kept in sync:
- **skill-improver** — applies fixes identified by this review
