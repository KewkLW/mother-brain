#!/usr/bin/env node
/**
 * Mother Brain — Stop hook (end-of-session reminder)
 *
 * Fires at most ONCE per session, and only when:
 *   - the session was substantive (>=1 file edit/write, or >=8 tool calls), AND
 *   - no vault write has happened this session yet.
 *
 * Reads the Stop-hook JSON on stdin: { stop_hook_active, transcript_path, session_id, ... }
 * On a nudge it returns {"decision":"block","reason":...} so the agent keeps
 * going and logs; the per-session sentinel + stop_hook_active guard prevent loops.
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
  const sentinel = path.join(os.tmpdir(), `mother-brain-reminded-${sessionId}`);
  if (fs.existsSync(sentinel)) return;

  const tp = input.transcript_path;
  if (!tp || !fs.existsSync(tp)) return;

  let text = '';
  try { text = fs.readFileSync(tp, 'utf8'); } catch { return; }

  // Already logged this session? Check for vault path writes or /vault skill invocation.
  const vaultPattern = new RegExp(VAULT_PATH.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
  const vaultSkill = /"skill"\s*:\s*"vault"/i;
  if (vaultPattern.test(text) || vaultSkill.test(text)) return;

  // Substantive-work signals.
  const toolUses = (text.match(/"type"\s*:\s*"tool_use"/g) || []).length;
  const edits = (text.match(/"name"\s*:\s*"(Edit|Write|NotebookEdit)"/g) || []).length;
  if (edits < 1 && toolUses < 8) return;

  // Nudge once.
  try { fs.writeFileSync(sentinel, String(Date.now())); } catch { /* best effort */ }

  const reason =
    `Before ending: this session did substantive work but nothing has been logged to the vault yet ` +
    `(${VAULT_PATH}). Persist it now via the /vault workflow: read _Registry.md for the canonical note name, ` +
    `append dated bullets with [[wikilinks]] to the relevant note(s), and add a Sessions/ log ` +
    `if the work was complex. Then collapse any auto-memory to a one-line pointer. ` +
    `If this turn genuinely had nothing worth persisting, just stop.`;

  process.stdout.write(JSON.stringify({ decision: 'block', reason }));
}

main();
