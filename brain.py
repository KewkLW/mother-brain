#!/usr/bin/env python3
"""brain.py — deterministic vault linter for Mother Brain.

Checks vault notes for structural problems without touching an LLM.
Zero tokens, milliseconds.

Commands:
  lint [path]       — check the vault (or a single file) for problems
  status            — show NEW, CHANGED, DELETED sources since last ingest
  done <raw> <wiki...> — record that <raw> was ingested into <wiki...>
  index             — rebuild _Registry.md from note frontmatter

Adapted from Brucky's brain.py (deterministic second brain linter),
rewritten for Mother Brain's entity-centric vault layout.
"""

import hashlib
import json
import os
import re
import sys
from pathlib import Path

VAULT = Path(os.environ.get("VAULT_PATH", "")).resolve()
MANIFEST = VAULT / ".brain" / "manifest.json"
WIKILINK = re.compile(r"\[\[([^\]|#]+)(?:[#|][^\]]*)?\]\]")
QUOTE = re.compile(r'^>\s*"(.+?)"\s*[—–\-]+\s*(\S+)\s*$', re.MULTILINE)
REQUIRED_FRONTMATTER = {"tags", "created"}
SKIP_NAMES = {"_Registry.md", "index.md", "hot.md", "log.md"}
SKIP_DIRS = {"Templates", ".brain", ".obsidian", ".trash", "raw"}


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()[:16]


def load_manifest():
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text())
    return {}


def save_manifest(m):
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(m, indent=2, sort_keys=True) + "\n")


def vault_notes():
    """All .md files in the vault, skipping system dirs and templates."""
    for p in sorted(VAULT.rglob("*.md")):
        rel = p.relative_to(VAULT)
        if any(part in SKIP_DIRS for part in rel.parts):
            continue
        yield p


def rel(p):
    return str(p.relative_to(VAULT))


def frontmatter(text):
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---", 4)
    if end < 0:
        return None
    fm = {}
    for line in text[4:end].splitlines():
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        fm[k.strip()] = v.strip()
    return fm


def cmd_lint(target=None):
    if not VAULT.is_dir():
        print(f"vault not found: {VAULT}", file=sys.stderr)
        return 1

    errs = []
    names = {}  # stem -> path
    text_cache = {}  # path -> text
    inbound = {}  # stem -> count

    if target:
        tp = Path(target).resolve()
        if not tp.exists():
            print(f"file not found: {target}", file=sys.stderr)
            return 1
        notes = [tp]
    else:
        notes = list(vault_notes())

    # First pass: index all note stems for link resolution
    all_notes = list(vault_notes())
    for p in all_notes:
        names[p.stem.lower()] = p
        inbound.setdefault(p.stem.lower(), 0)

    # Second pass: lint each note
    for p in notes:
        if p.name in SKIP_NAMES:
            continue

        try:
            text = p.read_text(errors="replace")
        except Exception as e:
            errs.append(f"{rel(p)}: unreadable ({e})")
            continue

        text_cache[p] = text

        # Session notes have different required fields
        is_session = "Sessions" in p.parts or (
            p.parent != VAULT and p.parent.name == "Sessions"
        )
        skip_frontmatter = is_session

        fm = frontmatter(text)
        if fm is None and not skip_frontmatter:
            errs.append(f"{rel(p)}: missing frontmatter")
            continue

        if fm is not None and not skip_frontmatter:
            for need in REQUIRED_FRONTMATTER:
                if need not in fm:
                    errs.append(f"{rel(p)}: frontmatter lacks '{need}'")

        # Check wikilinks resolve
        for link_name in WIKILINK.findall(text):
            stem = link_name.strip().lower()
            if stem in names:
                inbound[stem] = inbound.get(stem, 0) + 1
            else:
                errs.append(f"{rel(p)}: broken link [[{link_name}]]")

        # Check quoted claims cite a real file and the quote exists in it
        for q, src in QUOTE.findall(text):
            src_path = VAULT / src
            if not src_path.exists():
                errs.append(f"{rel(p)}: quote cites missing {src}")
            else:
                normalized_quote = " ".join(q.split())
                normalized_source = " ".join(src_path.read_text(errors="replace").split())
                if normalized_quote not in normalized_source:
                    errs.append(
                        f'{rel(p)}: QUOTE NOT IN SOURCE -> "{q[:60]}" ({src})'
                    )

        # Unresolved TODOs (bare TODO, not in a checkbox)
        for i, line in enumerate(text.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("- [ ]"):
                continue  # checkbox is fine
            if "TODO" in stripped and not stripped.startswith("#"):
                errs.append(f"{rel(p)}: unresolved TODO (line {i})")
                break  # one per file is enough

    # Orphan check (only in full-vault mode)
    if not target:
        for stem, path in names.items():
            if path.name in SKIP_NAMES:
                continue
            if path.name == "_Registry.md":
                continue
            # Session notes aren't expected to have inbound links
            if "Sessions" in path.parts:
                continue
            if inbound.get(stem, 0) == 0:
                errs.append(f"{rel(path)}: orphan (no inbound links)")

    # Stale source check against manifest
    manifest = load_manifest()
    for raw_key, entry in manifest.items():
        raw_path = VAULT / raw_key
        if raw_path.exists() and sha(raw_path) != entry.get("sha"):
            pages = ", ".join(entry.get("pages", []))
            errs.append(f"{raw_key}: changed since ingest, pages stale: {pages}")

    for e in errs:
        print(e)

    print(
        f"lint: {len(errs)} problem(s) in {len(notes)} notes",
        file=sys.stderr,
    )
    return 1 if errs else 0


def cmd_status():
    manifest = load_manifest()
    todo = []

    # Check for a raw/ directory (optional, for vaults that use source ingestion)
    raw_dir = VAULT / "raw"
    if not raw_dir.is_dir():
        print("no raw/ directory in vault (source tracking not active)")
        return 0

    for p in sorted(raw_dir.rglob("*")):
        if not p.is_file():
            continue
        key = rel(p)
        if key not in manifest:
            todo.append(f"  NEW       {key}")
        elif manifest[key].get("sha") != sha(p):
            todo.append(f"  CHANGED   {key}")

    for key in sorted(manifest):
        if not (VAULT / key).exists():
            todo.append(f"  DELETED   {key}")

    for line in todo:
        print(line)
    print(f"pending: {len(todo)}", file=sys.stderr)
    return 0


def cmd_done(args):
    if len(args) < 2:
        print("usage: brain.py done <raw-file> <wiki-page...>", file=sys.stderr)
        return 1

    raw_file = VAULT / args[0]
    if not raw_file.exists():
        print(f"no such raw file: {args[0]}", file=sys.stderr)
        return 1

    pages = []
    for page_arg in args[1:]:
        pp = VAULT / page_arg
        if not pp.exists():
            print(f"no such page: {page_arg}", file=sys.stderr)
            return 1
        pages.append(page_arg)

    manifest = load_manifest()
    manifest[rel(raw_file)] = {"sha": sha(raw_file), "pages": pages}
    save_manifest(manifest)
    return 0


def cmd_index():
    rows = []
    for p in vault_notes():
        if p.name in SKIP_NAMES or p.name == "_Registry.md":
            continue
        if "Sessions" in p.parts:
            continue
        fm = frontmatter(p.read_text(errors="replace"))
        title = fm.get("title", p.stem) if fm else p.stem
        updated = fm.get("updated", "?") if fm else "?"
        rows.append(f"- [[{p.stem}]] — {title} ({updated})")

    idx = VAULT / "_AutoIndex.md"
    idx.write_text("# Auto Index\n\n" + "\n".join(sorted(rows)) + "\n")
    print(f"index: {len(rows)} pages", file=sys.stderr)
    return 0


if __name__ == "__main__":
    if not VAULT.is_dir() and len(sys.argv) > 1 and sys.argv[1] != "--help":
        print(
            "VAULT_PATH not set or not a directory. "
            "Export VAULT_PATH=/path/to/vault",
            file=sys.stderr,
        )
        sys.exit(1)

    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    rc = {
        "lint": lambda: cmd_lint(sys.argv[2] if len(sys.argv) > 2 else None),
        "status": cmd_status,
        "done": lambda: cmd_done(sys.argv[2:]),
        "index": cmd_index,
        "--help": lambda: (print(__doc__), 0)[1],
    }.get(cmd, lambda: (print(f"unknown command: {cmd}", file=sys.stderr), 1)[1])()
    sys.exit(rc or 0)
