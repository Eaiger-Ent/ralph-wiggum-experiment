---
name: adr-new
description: >
  Start a new Architecture Decision Record from a one-line decision statement. Use when you need
  to record a new architectural decision, technology choice, or design constraint. Triggers:
  'new adr', 'create adr', 'record decision', '/adr-new'.
argument-hint: "<kernel — one-line decision statement>"
allowed-tools: Read, Write, Glob
---

# Start a new ADR from a one-line decision statement

**Kernel**: $ARGUMENTS

**Input validation:** If `$ARGUMENTS` is empty or contains only whitespace, stop and emit:

```
Error: No decision statement provided. Usage: /adr-new <one-line decision statement>
```

Do not proceed with an empty kernel.

**Success criteria:** The ADR is complete when:
1. File exists at `docs/adr/NNN-short-description.md` with correct sequential number
2. All six sections are present (Background, Alternatives with ≥2 options, Decision, Consequences, Related ADRs, References)
3. Decision starts with "We will..."
4. No placeholder text remains (e.g. `<Expanded context...>`)

Follow the ADR creation workflow:

## Step 1: Generate Identifier

- Glob `docs/adr/*.md` and find the highest existing number.
- If the Glob returns no results, check whether the `docs/adr/` directory exists at all. If it does not exist, stop and ask the user: "No `docs/adr/` directory found. Should I create it now?" — do not proceed without confirmation.
- If the Glob returns results but the numbers are non-contiguous (gaps detected), use the highest number + 1; do **not** fill gaps.
- Increment the highest number by 1 to get the next sequential number (zero-padded to 3 digits, e.g. `006`).
- Filename format: `docs/adr/NNN-short-description.md`
- **Slug rules:** The `short-description` slug must be: lowercase, hyphen-separated, 3–6 words, letters and hyphens only (no digits, no underscores, no special characters). Example: `use-cloud-run-for-deployments`.
- Title format: `# ADR NNN: Title`

## Step 2: Check for Existing ADR

Before writing, check whether a file with the same number or a very similar slug already exists:

- Run `Glob("docs/adr/NNN-*.md")` for the computed number.
- If a match is found, stop and ask the user to choose:
  - **(a) Open for editing** — read the existing file and proceed with `adr-refine` flow
  - **(b) Choose a different number** — user provides an alternative number; re-check for conflicts
  - **(c) Overwrite** — proceed with writing and replace the existing file

## Step 3: Create the ADR

Create a new file at `docs/adr/NNN-short-description.md` with this structure:

```markdown
# ADR NNN: <Concise Action-Oriented Title — max 10 words>

**Status:** Draft
**Date:** <current date YYYY-MM-DD>

## Background

<Expanded context from the kernel. What problem are we solving? What constraints exist?
What triggered this decision? 2-4 paragraphs.>

## Alternatives Considered

### Option 1: <Name>

<Description>

**Pros:** ...
**Cons:** ...

### Option 2: <Name>

<Description>

**Pros:** ...
**Cons:** ...

## Decision

We will <clear, unambiguous statement of the chosen approach>.

<One paragraph explaining why this option was chosen over the alternatives.>

## Consequences

**Positive outcomes:**

- ...

**Trade-offs and risks:**

- ...

## Related ADRs

- [ADR NNN: Title](NNN-title.md) — <relationship>

## References

- <Only verified, working links>
```

## Style Requirements

- UK English spellings (organisation, behaviour, colour, etc.)
- Formal, professional tone — concise and direct
- Title: imperative mood, max 10 words (e.g. "Use Cloud Run for Orchestrator Deployment")
- Decision: always starts with "We will..."
- No filler words ("basically", "essentially", "obviously")
- No hedging language ("might", "could", "perhaps") in the Decision section
- References: only include links you can verify — no hallucinated URLs

After creating the file, emit a completion confirmation:

```text
ADR created: docs/adr/NNN-short-description.md
Title:       ADR NNN: <Title>
Status:      Draft
Sections:    Background, Alternatives Considered (N options), Decision, Consequences, Related ADRs, References

Next steps: run /adr-refine to iterate, or /adr-review before approving.
```

## Standards and Co-update Partners

The structural rules enforced by this skill (six required sections, "We will..." decision prefix, UK English, placeholder-free output) are shared with the following skills. If any of these rules change, **all listed skills must be updated together**:

| Standard | Shared with |
| --- | --- |
| ADR section structure | `adr-review`, `adr-check` |
| "We will..." decision prefix | `adr-review`, `adr-check` |
| UK English rule | `adr-review` |
