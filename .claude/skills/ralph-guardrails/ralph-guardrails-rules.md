## Git commit failure rules — non-negotiable

A `git commit` has failed if it exits non-zero, regardless of what any surrounding output says.

When a commit fails:

1. **Diagnose** — read the full error (hook failure, dirty state, merge conflict, etc.)
2. **Fix** — resolve the root cause (e.g. stage missing files, fix a pre-commit hook error, remove protected files from the staged set)
3. **Re-run** — confirm the commit succeeds before proceeding
4. **Escalate** — if you cannot fix after two attempts, stop and report exactly what failed

**Never:**
- Emit `DONE` when a deliverable commit has not succeeded
- Continue to the next task after a failed commit without retrying
- Assume the work is "committed enough" because the files exist on disk

**If a commit failure cannot be resolved**, log it to `<phase-dir>/concerns.md` under the relevant step heading before stopping:

```markdown
## <step-id> — <YYYY-MM-DD>

**Category:** harness-error
**Prompt section:** commit
**What I encountered:** `git commit` exited non-zero — <paste the error output>
**What I did:** <what you tried>
**Suggested fix:** <what should change in the harness or skill>
```
