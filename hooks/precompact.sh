#!/usr/bin/env bash
# Mother Brain — PreCompact hook
# Fires before context compression. Blocks the FIRST compact per session
# to prompt a vault save, then lets the retry through.
# State is kept in a per-session marker so we never loop.
#
# Set VAULT_PATH in your hook command.

VAULT_PATH="${VAULT_PATH:?Set VAULT_PATH in your hook command}"
DATE=$(date +%Y-%m-%d)

INPUT=$(cat)
SID=$(printf '%s' "$INPUT" | python3 -c "import sys,json;
try: print(json.load(sys.stdin).get('session_id',''))
except Exception: print('')" 2>/dev/null)
[ -z "$SID" ] && SID="nosession"

MARKER="${TMPDIR:-/tmp}/mother-brain-precompact-${SID}.done"

# Second (or later) compact for this session: allow it through.
if [ -f "$MARKER" ]; then
    rm -f "$MARKER"
    exit 0
fi

# First compact: record the marker and ask for a save.
touch "$MARKER"

ESCAPED_VAULT=$(printf '%s' "$VAULT_PATH" | sed -e 's|\\|\\\\|g' -e 's|"|\\"|g')

python3 -c "
import json
print(json.dumps({
    'decision': 'block',
    'reason': 'Before compacting: save any unsaved context to the vault.\\n'
              '1. Create ${ESCAPED_VAULT}/Sessions/${DATE}-precompact.md with unsaved decisions, discoveries, and code changes\\n'
              '2. Wikilink entities (see ${ESCAPED_VAULT}/_Registry.md)\\n'
              '3. Update any existing notes that changed\\n'
              '4. Then run /compact again -- it will proceed this time.'
}))
"
