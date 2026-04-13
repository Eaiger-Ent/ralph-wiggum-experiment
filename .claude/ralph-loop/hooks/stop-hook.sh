#!/bin/bash

# Ralph Loop Stop Hook
# Prevents session exit when a ralph-loop is active
# Feeds Claude's output back as input to continue the loop

set -euo pipefail

# Read hook input from stdin (advanced stop hook API)
HOOK_INPUT=$(cat)

# Record start time for duration calculation
HOOK_START_MS=$(date +%s%3N 2>/dev/null || echo "0")

# Write a JSONL telemetry entry
write_telemetry() {
  local outcome="$1"
  local phase="${STATE_PHASE:-unknown}"
  local step="${STATE_STEP:-unknown}"
  local end_ms
  end_ms=$(date +%s%3N 2>/dev/null || echo "0")
  local duration_ms=$(( end_ms - HOOK_START_MS ))

  # Extract token/model metrics from transcript
  local metrics
  metrics=$(extract_transcript_metrics "${TRANSCRIPT_PATH:-}")
  local model tokens_in tokens_out cache_creation_tokens cache_read_tokens
  model=$(echo "$metrics" | jq -r '.model // "unknown"')
  tokens_in=$(echo "$metrics" | jq -r '.tokens_in // 0')
  tokens_out=$(echo "$metrics" | jq -r '.tokens_out // 0')
  cache_creation_tokens=$(echo "$metrics" | jq -r '.cache_creation_tokens // 0')
  cache_read_tokens=$(echo "$metrics" | jq -r '.cache_read_tokens // 0')

  # Calculate cost
  local cost_usd
  cost_usd=$(calculate_cost_usd "$tokens_in" "$tokens_out" "$cache_creation_tokens" "$cache_read_tokens" "$model")

  # Extract repo name from working directory
  local repo_name
  repo_name=$(basename "$(git -C "${CLAUDE_PROJECT_DIR:-$(pwd)}" rev-parse --show-toplevel 2>/dev/null || echo "unknown")" 2>/dev/null || echo "unknown")

  mkdir -p "$HOME/.ralph"
  jq -cn \
    --arg type "iteration" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg session_id "${HOOK_SESSION:-}" \
    --arg repo_name "$repo_name" \
    --arg phase "$phase" \
    --arg step "$step" \
    --arg outcome "$outcome" \
    --arg model "$model" \
    --argjson duration_ms "$duration_ms" \
    --argjson tokens_in "$tokens_in" \
    --argjson tokens_out "$tokens_out" \
    --argjson cache_creation_tokens "$cache_creation_tokens" \
    --argjson cache_read_tokens "$cache_read_tokens" \
    --argjson cost_usd "$cost_usd" \
    '{
      type: $type,
      ts: $ts,
      session_id: $session_id,
      repo_name: $repo_name,
      phase: $phase,
      step: $step,
      model: $model,
      tokens_in: $tokens_in,
      tokens_out: $tokens_out,
      cache_creation_tokens: $cache_creation_tokens,
      cache_read_tokens: $cache_read_tokens,
      cost_usd: $cost_usd,
      duration_ms: $duration_ms,
      outcome: $outcome
    }' >> "$HOME/.ralph/telemetry.jsonl" 2>/dev/null || true
}

# Extract model and token counts from transcript assistant entries
extract_transcript_metrics() {
  local transcript="$1"
  if [[ ! -f "$transcript" ]]; then
    echo '{"model":"unknown","tokens_in":0,"tokens_out":0,"cache_creation_tokens":0,"cache_read_tokens":0}'
    return
  fi

  # Sum token counts across all assistant turns; take model from last assistant entry
  python3 - "$transcript" <<'PYEOF'
import json, sys

transcript_path = sys.argv[1]
totals = {"input_tokens": 0, "output_tokens": 0, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}
model = "unknown"

with open(transcript_path) as f:
    for line in f:
        try:
            obj = json.loads(line)
            if obj.get("type") == "assistant":
                msg = obj.get("message", {})
                if msg.get("model"):
                    model = msg["model"]
                usage = msg.get("usage", {})
                for k in totals:
                    totals[k] += usage.get(k, 0)
        except Exception:
            pass

print(json.dumps({
    "model": model,
    "tokens_in": totals["input_tokens"] + totals["cache_read_input_tokens"],
    "tokens_out": totals["output_tokens"],
    "cache_creation_tokens": totals["cache_creation_input_tokens"],
    "cache_read_tokens": totals["cache_read_input_tokens"]
}))
PYEOF
}

calculate_cost_usd() {
  local tokens_in="$1" tokens_out="$2" cache_creation="$3" cache_read="$4" model="$5"

  python3 - "$tokens_in" "$tokens_out" "$cache_creation" "$cache_read" "$model" <<'PYEOF'
import sys

tokens_in = int(sys.argv[1])
tokens_out = int(sys.argv[2])
cache_creation = int(sys.argv[3])
cache_read = int(sys.argv[4])
model = sys.argv[5]

PRICING = {
    "claude-sonnet-4-6": {"input": 3.00,  "output": 15.00, "cache_write": 3.75,  "cache_read": 0.30},
    "claude-opus-4-6":   {"input": 15.00, "output": 75.00, "cache_write": 18.75, "cache_read": 1.50},
    "claude-haiku-4-5":  {"input": 0.80,  "output": 4.00,  "cache_write": 1.00,  "cache_read": 0.08},
}
# Match on prefix so minor version suffixes still resolve
rates = next((v for k, v in PRICING.items() if model.startswith(k[:20])), PRICING["claude-sonnet-4-6"])

# tokens_in already includes cache_read, so subtract to avoid double-counting
raw_input = max(0, tokens_in - cache_read)
cost = (
    raw_input       * rates["input"]        / 1_000_000 +
    tokens_out      * rates["output"]       / 1_000_000 +
    cache_creation  * rates["cache_write"]  / 1_000_000 +
    cache_read      * rates["cache_read"]   / 1_000_000
)
print(f"{cost:.6f}")
PYEOF
}

# State file lives outside .claude/ to avoid triggering Claude Code's
# sensitive-directory write protection when running with --dangerously-skip-permissions
RALPH_STATE_FILE="$HOME/.ralph/loop-state.md"

if [[ ! -f "$RALPH_STATE_FILE" ]]; then
  # No active loop - allow exit
  exit 0
fi

# Clear any stale completion marker from a previous loop
rm -f /tmp/ralph-state

# Parse markdown frontmatter (YAML between ---) and extract values
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPH_STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
# Extract completion_promise and strip surrounding quotes if present
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')
STATE_PHASE=$(echo "$FRONTMATTER" | grep '^phase:' | sed 's/phase: *//' || echo "unknown")
STATE_STEP=$(echo "$FRONTMATTER" | grep '^step:' | sed 's/step: *//' || echo "unknown")

# Session isolation: the state file is project-scoped, but the Stop hook
# fires in every Claude Code session in that project. If another session
# started the loop, this session must not block (or touch the state file).
# Legacy state files without session_id fall through (preserves old behavior).
STATE_SESSION=$(echo "$FRONTMATTER" | grep '^session_id:' | sed 's/session_id: *//' || true)
HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')
if [[ -n "$STATE_SESSION" ]] && [[ "$STATE_SESSION" != "$HOOK_SESSION" ]]; then
  exit 0
fi

# Validate numeric fields before arithmetic operations
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Ralph loop: State file corrupted" >&2
  echo "   File: $RALPH_STATE_FILE" >&2
  echo "   Problem: 'iteration' field is not a valid number (got: '$ITERATION')" >&2
  echo "" >&2
  echo "   This usually means the state file was manually edited or corrupted." >&2
  echo "   Ralph loop is stopping. Run /ralph-loop again to start fresh." >&2
  write_telemetry "error"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Ralph loop: State file corrupted" >&2
  echo "   File: $RALPH_STATE_FILE" >&2
  echo "   Problem: 'max_iterations' field is not a valid number (got: '$MAX_ITERATIONS')" >&2
  echo "" >&2
  echo "   This usually means the state file was manually edited or corrupted." >&2
  echo "   Ralph loop is stopping. Run /ralph-loop again to start fresh." >&2
  write_telemetry "error"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Check if max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 Ralph loop: Max iterations ($MAX_ITERATIONS) reached."
  write_telemetry "max_iterations"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "⚠️  Ralph loop: Transcript file not found" >&2
  echo "   Expected: $TRANSCRIPT_PATH" >&2
  echo "   This is unusual and may indicate a Claude Code internal issue." >&2
  echo "   Ralph loop is stopping." >&2
  write_telemetry "error"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Read last assistant message from transcript (JSONL format - one JSON per line)
# First check if there are any assistant messages
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "⚠️  Ralph loop: No assistant messages found in transcript" >&2
  echo "   Transcript: $TRANSCRIPT_PATH" >&2
  echo "   This is unusual and may indicate a transcript format issue" >&2
  echo "   Ralph loop is stopping." >&2
  write_telemetry "error"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Extract the most recent assistant text block.
#
# Claude Code writes each content block (text/tool_use/thinking) as its own
# JSONL line, all with role=assistant. So slurp the last N assistant lines,
# flatten to text blocks only, and take the last one.
#
# Capped at the last 100 assistant lines to keep jq's slurp input bounded
# for long-running sessions.
LAST_LINES=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -n 100)
if [[ -z "$LAST_LINES" ]]; then
  echo "⚠️  Ralph loop: Failed to extract assistant messages" >&2
  echo "   Ralph loop is stopping." >&2
  write_telemetry "error"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Parse the recent lines and pull out the final text block.
# `last // ""` yields empty string when no text blocks exist (e.g. a turn
# that is all tool calls). That's fine: empty text means no <promise> tag,
# so the loop simply continues.
# (Briefly disable errexit so a jq failure can be caught by the $? check.)
set +e
LAST_OUTPUT=$(echo "$LAST_LINES" | jq -rs '
  map(.message.content[]? | select(.type == "text") | .text) | last // ""
' 2>&1)
JQ_EXIT=$?
set -e

# Check if jq succeeded
if [[ $JQ_EXIT -ne 0 ]]; then
  echo "⚠️  Ralph loop: Failed to parse assistant message JSON" >&2
  echo "   Error: $LAST_OUTPUT" >&2
  echo "   This may indicate a transcript format issue." >&2
  echo "   Ralph loop is stopping." >&2
  write_telemetry "error"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Check for completion promise (only if set)
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  # Extract text from <promise> tags using Perl for multiline support
  # -0777 slurps entire input, s flag makes . match newlines
  # .*? is non-greedy (takes FIRST tag), whitespace normalized
  # Only attempt extraction if <promise> tags are actually present
  if echo "$LAST_OUTPUT" | grep -q '<promise>'; then
    PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
  else
    PROMISE_TEXT=""
  fi

  # Use = for literal string comparison (not pattern matching)
  # == in [[ ]] does glob pattern matching which breaks with *, ?, [ characters
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "✅ Ralph loop: Detected <promise>$COMPLETION_PROMISE</promise>"
    echo "PIPELINE_DONE" > /tmp/ralph-state
    write_telemetry "DONE"
    rm "$RALPH_STATE_FILE"
    exit 0
  fi

  # Fallback: accept bare DONE on its own line (agent output "Then output exactly: DONE")
  if [[ -z "$PROMISE_TEXT" ]]; then
    LAST_LINE=$(echo "$LAST_OUTPUT" | sed '/^[[:space:]]*$/d' | tail -n 1 | tr -d '[:space:]')
    if [[ "$LAST_LINE" = "$COMPLETION_PROMISE" ]]; then
      echo "✅ Ralph loop: Detected bare '$COMPLETION_PROMISE' (fallback mode)"
      echo "PIPELINE_DONE" > /tmp/ralph-state
      write_telemetry "DONE"
      rm "$RALPH_STATE_FILE"
      exit 0
    fi
  fi
fi

# Not complete - continue loop with SAME PROMPT
NEXT_ITERATION=$((ITERATION + 1))

# Extract prompt (everything after the closing ---)
# Skip first --- line, skip until second --- line, then print everything after
# Use i>=2 instead of i==2 to handle --- in prompt content
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$RALPH_STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "⚠️  Ralph loop: State file corrupted or incomplete" >&2
  echo "   File: $RALPH_STATE_FILE" >&2
  echo "   Problem: No prompt text found" >&2
  echo "" >&2
  echo "   This usually means:" >&2
  echo "     • State file was manually edited" >&2
  echo "     • File was corrupted during writing" >&2
  echo "" >&2
  echo "   Ralph loop is stopping. Run /ralph-loop again to start fresh." >&2
  write_telemetry "error"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Update iteration in frontmatter (portable across macOS and Linux)
# Create temp file, then atomically replace
TEMP_FILE="${RALPH_STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$RALPH_STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$RALPH_STATE_FILE"

# Build system message with iteration count and completion promise info
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="🔄 Ralph iteration $NEXT_ITERATION | To stop: output <promise>$COMPLETION_PROMISE</promise> (ONLY when statement is TRUE - do not lie to exit!)"
else
  SYSTEM_MSG="🔄 Ralph iteration $NEXT_ITERATION | No completion promise set - loop runs infinitely"
fi

# Output JSON to block the stop and feed prompt back
# The "reason" field contains the prompt that will be sent back to Claude
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

# Exit 0 for successful hook execution
exit 0