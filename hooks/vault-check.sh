#!/usr/bin/env bash
# Mother Brain — PreToolUse hook
# Fires when Claude tries to Write a project_*.md into an auto-memory directory.
# Injects a soft reminder to use the vault instead. Does NOT approve or block.
#
# Set VAULT_PATH in your hook command (see install.sh).

INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', ''))
except: print('')
" 2>/dev/null)

[ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "write" ] && [ "$TOOL_NAME" != "Edit" ] && [ "$TOOL_NAME" != "edit" ] && exit 0

FILE_PATH=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {})
    print(ti.get('file_path', ''))
except: print('')
" 2>/dev/null)

case "$FILE_PATH" in
  *[/\\]memory[/\\]project_*.md)
    VAULT="${VAULT_PATH:-your vault}"
    printf '{"hookSpecificOutput":{"additionalContext":"Mother Brain: you are writing a project_*.md file into auto-memory. Project knowledge belongs in the vault at %s. Use the /vault skill or write directly to the vault instead. Auto-memory should contain at most a one-line pointer back to the vault note."}}' "$VAULT"
    ;;
  *)
    exit 0
    ;;
esac
