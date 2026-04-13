# Smart Commit — Commit Message Rules

Referenced from `SKILL.md` Step 3.5 and Step 4. Read this file once; do not re-read per run.

---

## Commit type selection

Use the first matching row:

| Condition | Type |
| --- | --- |
| New user-visible capability added | `feat` |
| Broken behaviour corrected | `fix` |
| Only `.md` / doc files changed | `docs` |
| Only test files changed (no production code) | `test` |
| Only CI workflow files changed | `ci` |
| Only infrastructure files changed | `infra` |
| Code restructured with no behaviour change | `refactor` |
| Dependencies, config, or housekeeping | `chore` |

## Scope suggestions

Derived from directory structure; update this file if new top-level directories are added:

- `docs` — changes in `docs/`
- `devcontainer` — changes in `.devcontainer/`
- `skills` — changes in `.claude/skills/`

Add project-specific scopes here as needed (e.g. `api`, `frontend`, `infra`).

## Message format

```
<type>[scope]: <description>

[optional body]

[optional footer(s)]
```

**Description guidelines:**
- Imperative mood, lowercase, no period, 50-72 chars

**Body guidelines:**
- Wrap at 72 chars; explain why and what

**Footer guidelines:**
- Issue references, breaking change notes

## Breaking changes

- Add `!` after type/scope (e.g. `feat(api)!: remove endpoint`)
- Or add `BREAKING CHANGE:` footer with migration notes

## Worked example

A diff that modifies `src/auth.ts` to fix a null-check and adds a test in
`src/__tests__/` -> type = `fix` (broken behaviour corrected), scope = `auth` (or inferred from the primary directory), description = `correct null check in token refresh`.

## Documentation currency signals

Check the diff for these patterns and note files that may need updating:

| Signal in diff | Possibly affected doc |
| --- | --- |
| New/changed routes or endpoints | `README.md` or `docs/architecture.md` |
| New environment variables | README setup section |
| Changes to `.devcontainer/` | `CLAUDE.md` or `README.md` |
| Architectural changes | offer `/adr-new` |
| Breaking changes | `docs/` migration notes |
