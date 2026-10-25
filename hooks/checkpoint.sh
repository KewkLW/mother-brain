#!/usr/bin/env bash
# Mother Brain — Stop hook (periodic checkpoint)
# Every N messages (default 15), blocks Claude and demands a vault save.
# The block forces Claude to persist session context before stopping.
#
# Set VAULT_PATH in your hook command. Adjust SAVE_EVERY to taste.

VAULT_PATH="${VAULT_PATH:?Set VAULT_PATH in your hook command}"
SAVE_EVERY="${SAVE_EVERY:-15}"

STATE_DIR="${TMPDIR:-/tmp}/mother-brain-state"
mkdir -p "$STATE_DIR"

INPUT=$(cat)

parse_json() {
  python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('$1','$2'))" <<< "$INPUT" 2>/dev/null
}

STOP_ACTIVE=$(parse_json "stop_hook_active" "false")
if [ "$STOP_ACTIVE" = "True" ] || [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

SESSION_ID=$(parse_json "session_id" "unknown")

COUNT_FILE="$STATE_DIR/${SESSION_ID}_count"
if [ -f "$COUNT_FILE" ]; then
  COUNT=$(cat "$COUNT_FILE")
else
  COUNT=0
fi
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNT_FILE"

if [ "$COUNT" -ge "$SAVE_EVERY" ]; then
  echo "0" > "$COUNT_FILE"
  DATE=$(date +%Y-%m-%d)

  ESCAPED_VAULT=$(printf '%s' "$VAULT_PATH" | sed -e 's|\\|\\\\|g' -e 's|"|\\"|g')

  python3 -c "
import json
print(json.dumps({
    'decision': 'block',
    'reason': 'MOTHER BRAIN CHECKPOINT. Save this session to the vault before stopping:\\n'
              '1. Create ${ESCAPED_VAULT}/Sessions/${DATE}-<topic>.md with frontmatter (wing, tags, created, entities)\\n'
              '2. Include decisions, discoveries, code changes, key quotes (blockquoted)\\n'
              '3. Wikilink EVERY entity -- check ${ESCAPED_VAULT}/_Registry.md for canonical names\\n'
              '4. Update existing entity notes that learned new info\\n'
              '5. Add new entities to _Registry.md if created\\n'
              '6. Then you may stop.'
}))
"
else
  exit 0
fi
