# Ralph-Wiggum Experiment

A devcontainer for experimenting with the
[Ralph-Wiggum](https://awesomeclaude.ai/ralph-wiggum) iterative AI development
methodology using Claude Code.

## What is Ralph-Wiggum?

Ralph-Wiggum is a simple iterative loop technique: feed an AI agent a prompt,
let it work, repeat until done. Named after the Simpsons character for its
persistent, unfazed approach. The methodology prioritises writing good prompts
over relying on model quality alone.

## Getting Started

### Prerequisites

- [VS Code](https://code.visualstudio.com/) with the
  [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
  extension, **or**
- [GitHub Codespaces](https://github.com/features/codespaces)

### Open in a devcontainer

1. Clone the repo and open the folder in VS Code
2. When prompted, click **Reopen in Container**
3. Wait for the `postCreateCommand` to finish — this installs Claude Code CLI
   and the ralph-loop plugin automatically

Or open directly in Codespaces:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/WhoMe192/ralph-wiggum-experiment)

### Authenticate Claude Code

After the container is ready, authenticate:

```bash
claude
```

Follow the prompts to log in with your Anthropic account.

## Usage

### Run a Ralph-Wiggum loop

```bash
claude /ralph-loop:ralph-loop "<your prompt here>" \
  --max-iterations 10 \
  --completion-promise "DONE"
```

Example:

```bash
claude /ralph-loop:ralph-loop \
  "Build a CLI tool that fetches weather for a given city using a free API. Signal completion by printing DONE." \
  --max-iterations 15 \
  --completion-promise "DONE"
```

### Stop a running loop

```bash
claude /ralph-loop:cancel-ralph
```

### Get help

```bash
claude /ralph-loop:help
```

## Tips

- Set `--max-iterations` to avoid runaway loops (10–20 is a good starting point)
- Make your `--completion-promise` an exact phrase your prompt instructs the
  model to output when finished
- Write clear, specific prompts — the methodology rewards prompt quality

## References

- <https://awesomeclaude.ai/ralph-wiggum>
- <https://ghuntley.com/ralph/>
