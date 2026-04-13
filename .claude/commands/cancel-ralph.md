---
description: "Cancel active Ralph Loop"
allowed-tools: ["Bash(test -f ~/.ralph/loop-state.md:*)", "Bash(rm ~/.ralph/loop-state.md)", "Read"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph

To cancel the Ralph loop:

1. Check if `~/.ralph/loop-state.md` exists using Bash: `test -f ~/.ralph/loop-state.md && echo "EXISTS" || echo "NOT_FOUND"`

2. **If NOT_FOUND**: Say "No active Ralph loop found."

3. **If EXISTS**:
   - Read `~/.ralph/loop-state.md` to get the current iteration number from the `iteration:` field
   - Remove the file using Bash: `rm ~/.ralph/loop-state.md`
   - Report: "Cancelled Ralph loop (was at iteration N)" where N is the iteration value
