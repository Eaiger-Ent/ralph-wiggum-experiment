# Claude Code + Ralph-Wiggum Devcontainer Template

A ready-to-go devcontainer template with [Claude Code](https://claude.ai/claude-code)
and the [Ralph-Wiggum](https://awesomeclaude.ai/ralph-wiggum) iterative loop plugin
pre-installed. Clone it, open the devcontainer, and run `/init-project` to configure
it for your project.

## Quick Start

### 1. Create your repo from this template

Click **"Use this template"** on GitHub, or:

```bash
gh repo create my-project --template WhoMe192/ralph-wiggum-experiment --clone
cd my-project
```

### 2. Open in a devcontainer

- **VS Code:** Open the folder → click **Reopen in Container** when prompted
- **Codespaces:** [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/WhoMe192/ralph-wiggum-experiment)

The container automatically installs Claude Code CLI, the ralph-loop plugin,
and GitHub CLI.

### 3. Store your Anthropic API key in the macOS Keychain

The container reads your API key from the macOS Keychain before it starts,
so you never need to paste secrets into the terminal. Run this once on your Mac:

```bash
security add-generic-password -a "$USER" \
  -s "RALPH_WIGGUM_ANTHROPIC_API_KEY" \
  -w "sk-ant-..."
```

On every subsequent container start, `fetch-secrets.sh` retrieves the key automatically
and injects it as `ANTHROPIC_API_KEY` inside the container.

> **Note:** If the key is not found in the Keychain, the container will fail
> to start and print instructions to add it.

### 4. Authenticate GitHub CLI (optional)

```bash
gh auth login
```

Claude Code auth is handled by the API key above — no interactive login needed.

### 5. Initialise your project

Inside Claude Code, run:

```text
/init-project
```

The skill asks a few questions and then:

- Sets the devcontainer name, base image, forwarded ports, and VS Code extensions
- Adds the `node` devcontainer feature if needed (so Claude Code installs
  correctly on non-Node stacks)
- Populates `README.md` with your project name, description, and Codespaces badge
- Populates `CLAUDE.md` with your tech stack, overview, and build/test/run commands
- Extends `.gitignore` with stack-specific entries
- Sets GitHub repo description and visibility via `gh repo edit`
- Removes the one-time `init.sh` script
- Commits everything in one structured commit

## What's Included

| Component | Purpose |
| --------- | ------- |
| Claude Code CLI | AI-assisted development from the terminal |
| Ralph-Loop plugin | [Ralph-Wiggum](https://awesomeclaude.ai/ralph-wiggum) iterative loop methodology |
| GitHub CLI (`gh`) | Repo, PR, and issue management |
| `/init-project` skill | Interactive one-time project setup (see above) |
| `CLAUDE.md` | Claude conventions; pre-populated by `/init-project` |
| `.gitignore` | Base ignore rules; extended per-stack by `/init-project` |
| Auth check script | Reminds you to log in on every container start |

## Using Ralph-Wiggum

Once authenticated, start a loop:

```bash
claude /ralph-loop "<your prompt>" \
  --max-iterations 10 \
  --completion-promise "DONE"
```

Other commands: `/cancel-ralph` (stop a loop),
`/ralph-help` (usage info).

## Customising the Tech Stack

`/init-project` handles the most common stacks interactively. For manual changes,
edit `.devcontainer/devcontainer.json`:

- **Base image** — swap `javascript-node:22` for Python, Go, Rust, etc.
  (options in comments)
- **Forwarded ports** — add ports your app needs
- **VS Code extensions** — add language-specific extensions

## References

- [Ralph-Wiggum methodology](https://awesomeclaude.ai/ralph-wiggum)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Dev Containers specification](https://containers.dev/)
