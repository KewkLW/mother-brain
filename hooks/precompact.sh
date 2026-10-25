#!/usr/bin/env bash
# Mother Brain — PreCompact hook
# Fires before context compression. Blocks the FIRST compact per session
# to prompt a vault save, then lets all subsequent compacts through.
#
# Set VAULT_PATH in your hook command.

VAULT_PATH="${VAULT_PATH:?Set VAULT_PATH in your hook command}"
DATE=$(date +%Y-%m-%d)

INPUT=$(cat)
SID=$(printf '%s' "$INPUT" | python3 -c "import sys,json;
try: print(json.load(sys.stdin).get('session_id',''))
except Exception: print('')" 2>/dev/null)
[ -z "$SID" ] && SID="nosession"
SID=$(printf '%s' "$SID" | tr -cd 'A-Za-z0-9_-')

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mother-brain"
mkdir -p "$STATE_DIR"
MARKER="$STATE_DIR/precompact-${SID}.done"

# Already prompted this session: let it through (don't delete marker).
if [ -f "$MARKER" ]; then
    exit 0
fi

# First compact: record the marker and ask for a save.
touch "$MARKER"

export DATE
python3 -c '
import json, os
vault = os.environ["VAULT_PATH"]
date = os.environ["DATE"]
print(json.dumps({
    "decision": "block",
    "reason": f"Before compacting: save any unsaved context to the vault.\n"
              f"1. Create {vault}/Sessions/{date}-precompact.md with unsaved decisions, discoveries, and code changes\n"
              f"2. Wikilink entities (see {vault}/_Registry.md)\n"
              f"3. Update any existing notes that changed\n"
              f"4. Then run /compact again -- it will proceed this time."
}))
'
