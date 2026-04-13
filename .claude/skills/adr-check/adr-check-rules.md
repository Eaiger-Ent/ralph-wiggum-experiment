## Step 2 Checklist — ADR completeness rules

**Format and Naming**:

- [ ] File is in `docs/adr/` directory
- [ ] Filename follows `NNN-short-description.md` format (three-digit zero-padded number)
- [ ] Title follows `# ADR NNN: Title` format
- [ ] Number in title matches number in filename

**Status and Date**:

- [ ] `**Status:**` field is present (`Draft`, `Proposed`, `Accepted`, `Superseded`, or `Deprecated`)
- [ ] `**Date:**` field is present in `YYYY-MM-DD` format

**Required Sections**:

- [ ] `## Background` section present and non-empty
- [ ] `## Alternatives Considered` section present with at least 2 options
- [ ] Each alternative has both pros and cons listed
- [ ] `## Decision` section present and starts with "We will..."
- [ ] `## Consequences` section present with both positive outcomes and trade-offs
- [ ] `## Related ADRs` section present (may state "None" if genuinely standalone)
- [ ] `## References` section present (may be empty if no external links)

**Content Quality**:

- [ ] Background provides sufficient context (Context section must contain ≥3 complete sentences or ≥150 characters)
- [ ] Decision is clear and unambiguous — no hedging language
- [ ] Consequences are specific, not vague ("may improve performance" is too vague)

**Technical Accuracy**:

- [ ] No obviously hallucinated URLs in References section
- [ ] Technology names match what is actually used in the project

**Style**:

- [ ] UK English spellings throughout
- [ ] No filler words ("basically", "essentially", "obviously")
