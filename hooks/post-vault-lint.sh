#!/usr/bin/env bash
# Mother Brain — PostToolUse hook
# After any Edit/Write to the vault, runs the linter on the changed file.
# Exit code 2 can't undo the edit (tool already ran), but the error text
# lands in Claude's context as a correction signal.
#
# Set VAULT_PATH in your hook command.

VAULT_PATH="${VAULT_PATH:?Set VAULT_PATH in your hook command}"

INPUT=$(cat)

FILE_PATH=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {})
    print(ti.get('file_path', ''))
except: print('')
" 2>/dev/null)

[ -z "$FILE_PATH" ] && exit 0

# Only lint if the file is inside the vault
case "$FILE_PATH" in
  "$VAULT_PATH"/*.md)
    ;;
  *)
    exit 0
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRAIN="${SCRIPT_DIR}/../brain.py"
# Fall back to a copy next to the hooks
[ ! -f "$BRAIN" ] && BRAIN="${SCRIPT_DIR}/brain.py"
# Fall back to the installed location
[ ! -f "$BRAIN" ] && BRAIN="${HOME}/.claude/hooks/brain.py"

if [ ! -f "$BRAIN" ]; then
  exit 0
fi

OUTPUT=$(VAULT_PATH="$VAULT_PATH" python3 "$BRAIN" lint "$FILE_PATH" 2>/dev/null)
RC=$?

if [ $RC -ne 0 ] && [ -n "$OUTPUT" ]; then
  python3 -c "
import json, sys
output = sys.stdin.read().strip()
print(json.dumps({
    'hookSpecificOutput': {
        'additionalContext': 'Mother Brain lint:\\n' + output + '\\nFix these before moving on.'
    }
}))
" <<< "$OUTPUT"
fi

exit 0
