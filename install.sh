#!/usr/bin/env bash
set -euo pipefail

# Mother Brain installer
# Installs hooks and skill into your Claude Code configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
HOOKS_DIR="${CLAUDE_DIR}/hooks"
SKILLS_DIR="${CLAUDE_DIR}/skills"

echo "Mother Brain Installer"
echo "======================"
echo ""

# Ask for vault path
if [ -n "${VAULT_PATH:-}" ]; then
    echo "Using VAULT_PATH from environment: $VAULT_PATH"
else
    read -rp "Where is your vault? (absolute path, e.g. /home/you/Obsidian/Vault): " VAULT_PATH
fi

# Validate vault path
if [ ! -d "$VAULT_PATH" ]; then
    echo ""
    read -rp "Directory '$VAULT_PATH' doesn't exist. Create it? [y/N] " CREATE
    if [ "$CREATE" = "y" ] || [ "$CREATE" = "Y" ]; then
        mkdir -p "$VAULT_PATH"
        echo "Created $VAULT_PATH"
    else
        echo "Aborted. Create the directory first, then re-run."
        exit 1
    fi
fi

# Create vault skeleton if empty
if [ ! -f "$VAULT_PATH/_Registry.md" ]; then
    echo ""
    echo "Setting up vault skeleton..."
    mkdir -p "$VAULT_PATH/Sessions"
    mkdir -p "$VAULT_PATH/Projects"
    mkdir -p "$VAULT_PATH/Research"
    mkdir -p "$VAULT_PATH/Tools"
    mkdir -p "$VAULT_PATH/Templates"
    cp "$SCRIPT_DIR/examples/_Registry.md" "$VAULT_PATH/_Registry.md"
    echo "  Created _Registry.md and folders"
fi

# Install hooks
echo ""
echo "Installing hooks..."
mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/hooks/vault-check.sh" "$HOOKS_DIR/"
cp "$SCRIPT_DIR/hooks/checkpoint.sh" "$HOOKS_DIR/"
cp "$SCRIPT_DIR/hooks/stop-reminder.js" "$HOOKS_DIR/"
cp "$SCRIPT_DIR/hooks/precompact.sh" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/vault-check.sh" "$HOOKS_DIR/checkpoint.sh" "$HOOKS_DIR/precompact.sh"
echo "  Copied 4 hooks to $HOOKS_DIR"

# Install skill
echo ""
echo "Installing skill..."
mkdir -p "$SKILLS_DIR/vault"
cp "$SCRIPT_DIR/skills/vault/SKILL.md" "$SKILLS_DIR/vault/"
echo "  Copied vault skill to $SKILLS_DIR/vault/"

# Escape the vault path for JSON
ESCAPED_VAULT=$(printf '%s' "$VAULT_PATH" | sed -e "s|\\\\|\\\\\\\\|g" -e 's|"|\\"|g')

echo ""
echo "============================================================"
echo "Almost done. Add these hooks to your Claude Code settings."
echo ""
echo "Open ~/.claude/settings.json (or settings.local.json) and"
echo "merge the following into the \"hooks\" object:"
echo ""
echo "See examples/settings.json.snippet for the full block, or"
echo "copy-paste the commands below, replacing the VAULT_PATH:"
echo ""
echo "  PreToolUse:"
echo "    VAULT_PATH='${VAULT_PATH}' bash \"\$HOME/.claude/hooks/vault-check.sh\""
echo ""
echo "  Stop (checkpoint):"
echo "    VAULT_PATH='${VAULT_PATH}' bash \"\$HOME/.claude/hooks/checkpoint.sh\""
echo ""
echo "  Stop (end-of-session reminder):"
echo "    VAULT_PATH='${VAULT_PATH}' node \"\$HOME/.claude/hooks/stop-reminder.js\""
echo ""
echo "  PreCompact:"
echo "    VAULT_PATH='${VAULT_PATH}' bash \"\$HOME/.claude/hooks/precompact.sh\""
echo ""
echo "Then start a new Claude Code session. Type /vault to test it."
echo "============================================================"
