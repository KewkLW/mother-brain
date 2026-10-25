#!/usr/bin/env node
/**
 * Mother Brain — Stop hook (end-of-session reminder)
 *
 * Fires at most ONCE per session, and only when:
 *   - the session was substantive (>=1 file edit/write, or >=8 tool calls), AND
 *   - no vault file was actually written this session (checks for Write/Edit
 *     tool calls targeting the vault path, not just mentions of the path).
 *
 * Set VAULT_PATH in your hook command.
 */
const fs = require('fs');
const os = require('os');
const path = require('path');

const VAULT_PATH = process.env.VAULT_PATH;
if (!VAULT_PATH) {
  process.stderr.write('Mother Brain stop-reminder: VAULT_PATH not set\n');
  process.exit(0);
}

function main() {
  let input = {};
  try { input = JSON.parse(fs.readFileSync(0, 'utf8') || '{}'); } catch { /* ignore */ }

  if (input.stop_hook_active) return;

  const sessionId = String(input.session_id || 'nosession').replace(/[^a-zA-Z0-9_-]/g, '');
  const stateDir = path.join(process.env.XDG_STATE_HOME || path.join(os.homedir(), '.local', 'state'), 'mother-brain');
  try { fs.mkdirSync(stateDir, { recursive: true }); } catch { /* ignore */ }
  const sentinel = path.join(stateDir, `reminded-${sessionId}`);
  if (fs.existsSync(sentinel)) return;

  const tp = input.transcript_path;
  if (!tp || !fs.existsSync(tp)) return;

  let text = '';
  try { text = fs.readFileSync(tp, 'utf8'); } catch { return; }

  // Check if a file was actually written TO the vault (not just the path mentioned in hook output).
  // Look for Write/Edit tool calls where file_path contains the vault path.
  const vaultEscaped = VAULT_PATH.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const writeToVault = new RegExp(`"file_path"\\s*:\\s*"[^"]*${vaultEscaped}`, 'i');
  const vaultSkill = /"skill"\s*:\s*"vault"/i;
  if (writeToVault.test(text) || vaultSkill.test(text)) return;

  // Substantive-work signals.
  const toolUses = (text.match(/"type"\s*:\s*"tool_use"/g) || []).length;
  const edits = (text.match(/"name"\s*:\s*"(Edit|Write|NotebookEdit)"/g) || []).length;
  if (edits < 1 && toolUses < 8) return;

  // Nudge once.
  try { fs.writeFileSync(sentinel, String(Date.now())); } catch { /* best effort */ }

  const reason =
    `Before ending: this session did substantive work but nothing has been saved to the vault yet ` +
    `(${VAULT_PATH}). Persist it now via the /vault workflow: read _Registry.md for the canonical note name, ` +
    `append dated bullets with [[wikilinks]] to the relevant note(s), and add a Sessions/ log ` +
    `if the work was complex. Then collapse any auto-memory to a one-line pointer. ` +
    `If this turn genuinely had nothing worth persisting, just stop.`;

  process.stdout.write(JSON.stringify({ decision: 'block', reason }));
}

main();
