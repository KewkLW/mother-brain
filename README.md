# Mother Brain

A persistent knowledge system for [Claude Code](https://claude.com/claude-code) that keeps your project knowledge in an Obsidian vault (or any markdown-based PKM) instead of letting it scatter into auto-memory.

Claude Code's built-in memory is scoped per working directory, fragmented across projects, and invisible to your real notes. Mother Brain fixes that with five hooks, one skill, and a deterministic linter that make Claude treat your vault as the single source of truth.

## TL;DR

Tell your agent:

> Clone https://github.com/KewkLW/mother-brain and run `./install.sh`. Point it at my vault.

That's it. The installer copies five hooks, one skill, and a linter into your Claude Code config, asks for your vault path, and creates the folder structure if it doesn't exist. Next session, Claude saves to your vault instead of auto-memory. No MCP server, no daemon, no dependencies beyond bash, python3, and node.

## What it does

**The problem:** Claude Code saves memories in per-directory sandboxes. If you work across multiple projects, your knowledge fragments. If you use Obsidian (or Logseq, Foam, plain markdown), Claude ignores it and writes `project_foo.md` files you'll never find again.

**The fix:** Five hooks that form a behavioral forcing function, a deterministic linter that catches structural errors without burning tokens, and a skill that teaches Claude the vault workflow.

| Hook | Event | What it does |
|------|-------|-------------|
| `vault-check.sh` | PreToolUse | Catches `project_*.md` writes to auto-memory. Reminds Claude to use the vault instead |
| `checkpoint.sh` | Stop | Every 15 messages, blocks Claude and forces a vault save with session notes, wikilinks, and entity registry updates |
| `stop-reminder.js` | Stop | At end of session, checks if substantive work happened without a vault save. Blocks once to prompt logging |
| `precompact.sh` | PreCompact | Before context compression, blocks once to save anything that would be lost |
| `post-vault-lint.sh` | PostToolUse | After any Edit/Write to the vault, runs `brain.py lint` on the changed file. Broken links, missing frontmatter, and unverified quotes surface immediately |

The `/vault` skill auto-triggers when Claude is about to persist project knowledge, walking it through: check the entity registry, read the existing note, append with dated bullets and `[[wikilinks]]`, create a session log if the work was complex.

A deterministic linter (`brain.py`) verifies every vault write: frontmatter, wikilinks, quote attribution, orphans, and stale sources. It runs after every edit via the `post-vault-lint.sh` hook. Zero tokens, milliseconds.

## Why hooks instead of a prompt rule

We tried telling Claude "always save to the vault" in a feedback memory. It ignored the rule because:

1. Auto-memory's system prompt instructions are ~200 lines of prescriptive detail. One line saying "use the vault instead" loses every time.
2. Claude reads the index entry but never opens the referenced feedback file.
3. Nothing in the harness intercepted a write to enforce the rule.

Hooks are enforced by the harness, not recalled by the model. They can't be forgotten.

## The philosophy

One skill file that teaches the model to use tools it already has, instead of wrapping those tools in an MCP layer.

Claude Code can already read files, write files, run shell commands, and search your filesystem. It doesn't need a 25 MB server with 207 tool definitions to do those things through a proxy. It needs a short note that says "here's the workflow, here are the traps, here's the fastest command for each situation." Mother Brain is that note for knowledge management: no server, no daemon, no tool definitions. Just hooks that enforce the workflow and a skill that teaches it.

This is the same pattern behind [leanrea](https://github.com/aicodeking/leanrea) (reverse engineering with plain CLI tools instead of an MCP server) and it works for the same reason: the model is already capable. The bottleneck is directing that capability, not adding more tools.

## Requirements

- `bash`
- `python3`
- `node` (v18+)
- [Claude Code](https://claude.com/claude-code)
- A markdown vault (Obsidian, Logseq, Foam, or a plain folder)

## Install

```bash
git clone https://github.com/KewkLW/mother-brain.git
cd mother-brain
./install.sh
```

The installer will:
1. Ask for your vault path
2. Create the vault skeleton if it doesn't exist (`_Registry.md`, `Sessions/`, etc.)
3. Copy hooks and skill to `~/.claude/hooks/` and `~/.claude/skills/vault/`
4. Print the settings.json snippet to add to your Claude Code config

Then merge the hook commands into `~/.claude/settings.json` (or `settings.local.json`). See `examples/settings.json.snippet` for the full block.

## Vault structure

```
your-vault/
├── _Registry.md     — canonical entity names. Claude checks this first
├── Sessions/        — dated session logs (auto-created by hooks)
├── Projects/        — project notes with status, findings, decisions
├── Research/        — ongoing research topics
├── Tools/           — tooling and integrations
└── ...              — organize however you want
```

### The Registry

`_Registry.md` is the index. Every entity gets one canonical name. Claude checks it before creating or linking any note, preventing duplicates (`[[beatport]]` vs `[[Beatport]]` vs `[[Beatport CLI]]`).

```markdown
# Entity Registry

## Projects
- [[My App]] — main project, repo at ~/projects/my-app
- [[Side Project]] — weekend experiment, paused

## Tools
- [[ComfyUI]] — local image gen, custom nodes
```

### Session notes

Every substantive session gets a log in `Sessions/`. The hooks enforce this. Format:

```markdown
---
wing: sessions
tags: [session, my-app, auth]
created: 2026-01-15
entities: [My App, Auth System]
---

# Auth Rewrite

Links: [[My App]], [[Auth System]]

## What Happened
Rewrote auth middleware to JWT. [[Alice]] flagged cookies as a mobile blocker.

## Decisions
- JWT with 15-min access tokens, 7-day refresh tokens
- Keep Redis for rate limiting only
```

### Entity notes

Each project, tool, or concept gets one note. Append-only with dated bullets. See `examples/entity-note.md`.

## How it works in practice

1. You start a Claude Code session and do work
2. Every 15 messages, `checkpoint.sh` blocks and forces a save
3. If you try to stop without saving, `stop-reminder.js` catches it
4. If context is about to compress, `precompact.sh` saves first
5. If Claude reaches for auto-memory, `vault-check.sh` redirects it
6. After every vault write, `post-vault-lint.sh` runs `brain.py` on the changed file
7. `/vault` gives Claude the full workflow: registry, wikilinks, templates

The result: your Obsidian vault becomes a living knowledge base that grows with every Claude session. Cross-linked, searchable, with a full timeline of what happened and why.

## The linter (brain.py)

A 95-line Python script (standard library only, no AI) that checks vault health deterministically. Runs automatically after every vault write via the PostToolUse hook.

What it catches:
- Missing or incomplete frontmatter (`tags`, `created`)
- Broken `[[wikilinks]]` that don't resolve to any note
- Quoted claims that don't exist verbatim in the cited source file
- Orphan notes with zero inbound links
- Bare `TODO` markers outside checkboxes
- Source files that changed after their last ingest (stale derived pages)

### Manual usage

```bash
VAULT_PATH=/path/to/vault python3 brain.py lint          # full vault check
VAULT_PATH=/path/to/vault python3 brain.py lint note.md   # single file
VAULT_PATH=/path/to/vault python3 brain.py status         # pending ingests
VAULT_PATH=/path/to/vault python3 brain.py done raw/src.md Projects/App.md  # record ingest
VAULT_PATH=/path/to/vault python3 brain.py index          # rebuild auto-index
```

### Quote verification

When a note quotes a source, use this format:

```markdown
> "The exact words from the source" — path/to/source.md
```

The linter normalizes whitespace and checks that the quoted text appears in the cited file. If the source changes after ingest, the linter flags the derived pages as stale. This is the single most valuable check: it catches hallucinated citations that a model would never catch on its own.

### Source provenance (optional)

If your vault has a `raw/` directory for source documents, `brain.py status` tracks which sources are NEW, CHANGED, or DELETED since last ingest. After ingestion, `brain.py done <raw> <pages...>` records the source hash and its derived pages. When the source changes, the linter flags the pages for re-ingestion.

## Configuration

### Change checkpoint frequency

Set `SAVE_EVERY` in your hook command:

```json
"command": "VAULT_PATH='/path/to/vault' SAVE_EVERY=20 bash \"$HOME/.claude/hooks/checkpoint.sh\""
```

### Works with any markdown PKM

Mother Brain is built for Obsidian but works with any markdown-based system. The `[[wikilinks]]` are standard across Obsidian, Logseq, Foam, and Dendron. If your PKM doesn't support wikilinks, Claude will still create well-structured markdown notes with relative links.

### Works with OpenAI Codex

The vault workflow is agent-agnostic. The skill and hooks are designed for Claude Code's harness, but the vault structure, registry pattern, and session note format work with any AI coding tool that can read and write files. An OpenAI Codex agent config is included at `agents/openai.yaml`.

## FAQ

**Does this replace Claude Code's auto-memory?**
No. Auto-memory still handles user preferences, feedback rules, and ephemeral state. Mother Brain redirects *project knowledge* (facts, decisions, discoveries, status) to your vault where it belongs.

**Can I use this with an existing Obsidian vault?**
Yes. The installer creates a `_Registry.md` and `Sessions/` folder. Everything else is additive. Your existing notes are untouched.

**What if I don't use Obsidian?**
Any folder of markdown files works. The hooks and skill only need a path to a directory. Obsidian, Logseq, Foam, VS Code with markdown preview, or a plain directory you `grep` through.

**Does it work on Windows?**
Yes, via WSL or Git Bash. The hooks handle both path separators. Set `VAULT_PATH` with forward slashes or escaped backslashes.

## License

AGPL-3.0. Copyright 2026 Kewk.
