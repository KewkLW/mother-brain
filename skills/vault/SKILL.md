---
name: vault
description: "Mother Brain vault workflow. Use before saving project context, session discoveries, decisions, status updates, or work-in-progress context to the Obsidian vault instead of auto-memory. Also use for /vault manual invocations, save-this requests, and remember-this-about-project requests."
user-invocable: true
---

# Mother Brain — Vault Workflow

The vault is your persistent knowledge base. **Information not in the vault is effectively lost between sessions.** Auto-memory is ephemeral; the vault is permanent.

## Core rule

**Writing `project_*.md` in auto-memory is a red flag.** Project knowledge (facts, discoveries, decisions, status, findings) belongs in the vault. Auto-memory is for user prefs, feedback rules, and at most one-line pointers back to the vault.

| Belongs in auto-memory | Belongs in the vault |
|---|---|
| User prefs (`user_*.md`) | Project facts, current status, discoveries |
| Feedback rules (`feedback_*.md`) | Findings, research notes |
| Open follow-ups index | Decisions and their reasoning |
| One-line project pointers | Session logs |

## Finding your vault

The vault path is set via `VAULT_PATH` in the hook commands (see `examples/settings.json.snippet`). If you need it in this skill, read the `VAULT_PATH` from the hook config in `~/.claude/settings.json`, or check for the `_Registry.md` file to locate the vault root.

## Vault structure

```
your-vault/
├── _Registry.md          — canonical note names, CHECK THIS FIRST
├── Projects/             — project notes, organized by domain
├── Research/             — ongoing research topics
├── Tools/                — tooling and integrations
├── Sessions/             — date-stamped session logs
├── Templates/            — note templates
└── ...                   — add folders as needed for your domains
```

## Workflow (do every step)

### 1. Find the canonical note
Read the vault's `_Registry.md` first. Look for the existing entity under its section. Use the **exact** canonical name in `[[wikilinks]]`. Never invent a variant.

If the entity is new: pick the right folder, create a new note, and append it to `_Registry.md` under the matching section.

### 2. Read the existing note before writing
Never blind-overwrite. Read the note, understand its current structure, and append where appropriate. Typically a dated bullet under a "Status" or "Findings" section.

### 3. Append with date-stamps and wikilinks
- Dated additions: `- (YYYY-MM-DD) what happened` (use today's real date, not relative)
- Wrap every entity mention in `[[double brackets]]`: people, projects, tools, hardware, locations, CVEs. Never bare-reference
- Example: `- (2026-04-10) [[Auth Service]] token refresh rewrite: switched from opaque to JWT, fixes [[Mobile App]] login timeout`

### 4. Create a session log for long/complex sessions
Path: `your-vault/Sessions/YYYY-MM-DD-topic.md`
```markdown
---
wing: sessions
tags: [session, relevant-tags]
created: YYYY-MM-DD
entities: [Entity1, Entity2]
---

# YYYY-MM-DD — Topic

Links: [[Entity1]], [[Entity2]]

## What Happened
[why this session happened, what was accomplished]

## Key Discoveries
- detail with [[wikilinks]]

## Decisions
- what was decided and why

## What's Next
- [ ] next step
```
Then link this session from the main entity notes.

### 5. Collapse auto-memory to a pointer
If there's existing rich content in auto-memory `project_<name>.md`, the content belongs in the vault. After moving it, reduce the auto-memory file to a one-line pointer:

```markdown
---
name: <Entity> (pointer)
description: Pointer to the canonical vault note
metadata:
  type: reference
---

See `your-vault/<Folder>/<Entity>.md` — vault note is the source of truth.
```

## Note template (new vault note)

```markdown
---
tags: [project|tool|research]
status: active|paused|done
created: YYYY-MM-DD
updated: YYYY-MM-DD
entities: [Related1, Related2]
---

# <Entity>

Links: [[Related1]], [[Related2]]

## What this is
One paragraph: what it is and why it exists.

## Current status
- (YYYY-MM-DD) latest bullet
- (YYYY-MM-DD) earlier bullet

## Key findings / decisions
- ...

## Open questions
- [ ] ...

## Sessions
- [[YYYY-MM-DD-topic]]
```

## Linter (brain.py)

Mother Brain includes a deterministic linter that checks vault health without using any LLM. Zero tokens, milliseconds. It runs automatically after every vault write via the `post-vault-lint.sh` hook.

### What it checks
- Every note has frontmatter with `tags` and `created`
- Every `[[wikilink]]` resolves to an existing note
- Every quoted claim (blockquote with `— source` attribution) exists verbatim in the cited file
- No orphan notes (notes with zero inbound links, excluding Sessions/)
- No bare `TODO` outside checkboxes
- Source files changed after ingest are flagged with their stale pages

### Manual commands
Run from the vault root with `VAULT_PATH` set:

```bash
VAULT_PATH=/path/to/vault python3 brain.py lint          # full vault check
VAULT_PATH=/path/to/vault python3 brain.py lint file.md   # single file
VAULT_PATH=/path/to/vault python3 brain.py status         # show pending ingests
VAULT_PATH=/path/to/vault python3 brain.py done raw/source.md wiki/page1.md wiki/page2.md
VAULT_PATH=/path/to/vault python3 brain.py index          # rebuild auto-index
```

### Quote attribution format
When citing a source verbatim, use this format so the linter can verify the quote exists:

```markdown
> "The exact words from the source" — path/to/source.md
```

The linter normalizes whitespace and checks that the quoted text appears in the source file. If the source changes, the linter flags the quoting pages as stale.

### Source provenance (optional)
If your vault has a `raw/` directory for source documents, `brain.py status` tracks which sources are NEW, CHANGED, or DELETED since they were last ingested. After Claude ingests a source into wiki pages, record it with `brain.py done <raw-file> <page...>`, which stores a SHA hash. When the source changes later, the linter flags the derived pages as stale.

## Common pitfalls

1. **Bare-referencing entities** (writing `Beatport` instead of `[[Beatport]]`). Breaks cross-linking and graph navigation.
2. **Skipping `_Registry.md`** and inventing note names. Always check the registry first.
3. **Overwriting notes wholesale.** Append, don't replace.
4. **Saving relative dates** ("yesterday", "last week"). Always resolve to `YYYY-MM-DD`.
5. **Writing `project_*.md` in auto-memory.** If you catch yourself doing this, stop. Use this workflow instead.
6. **Unattributed quotes.** If you cite a source, use the blockquote attribution format so the linter can verify it.

## Invocation

- **Manually:** `/vault [entity]` — run through the workflow for the named entity
- **Auto-triggered:** when the user says "save this", "remember this about X", "note that", or when you're about to persist anything non-ephemeral about a project
- **Forced:** the `vault-check.sh` hook injects a reminder on any `project_*.md` auto-memory write
- **Lint:** runs automatically after every vault write via `post-vault-lint.sh`. Fix any issues it reports before moving on.
