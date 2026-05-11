# memory

Curated, git-tracked memory. "Folder B" in the dual-folder memory model.

## Purpose

This folder is **`<assistant.name>`'s long-term notebook on the work and on `<user.name>`** — daily logs of what shipped and decisions made, writing-style notes for matching tone, learned preferences worth committing to git so they survive across machines.

It's distinct from the per-machine auto-memory at `~/.claude/projects/<cwd-hash>/memory/` (Folder A — managed by Claude Code, indexed by `MEMORY.md` uppercase). Both load at session start.

## Two memory folders, two roles

| | Folder A (auto-memory) | Folder B (this folder) |
|---|---|---|
| **Location** | `~/.claude/projects/<cwd-hash>/memory/` | `<workspace.root>/../memory/` |
| **In git?** | ❌ No — per-machine | ✅ Yes — curated, syncs across machines |
| **Index file** | `MEMORY.md` (uppercase) | `memory.md` (lowercase) |
| **Who writes** | Claude Code automatically | `<user.name>` + `<assistant.name>` (you both curate) |
| **What lives there** | Live preferences, facts, "always do X" rules | Daily journal entries, writing style, learned preferences |
| **Lifecycle** | Continuously updated by Claude | Append-only daily logs, deliberate curation |

**Save rule:** A live correction or "do X / not Y" rule? Folder A. A daily journal entry or curated long-form? Folder B (this folder).

## What belongs here

- ✓ `memory.md` (lowercase) — index of project memory contents; under 200 lines
- ✓ `YYYY-MM-DD.md` — daily logs. Append-only end-of-session summaries, decisions worth keeping
- ✓ `writing-style.md` — `<user.name>`'s writing style profile (referenced before drafting QBRs/PRDs/strategic docs)
- ✓ `learned-preferences.md` — durable preferences committed to git
- ✓ Other curated long-form: communication patterns, decision-making rubrics, voice samples

## What doesn't belong here

- ✗ Project-specific memory → `<workspace.root>/1-Projects/<slug>/memory.md`
- ✗ Live "do this / not that" preferences → Folder A (auto-memory)
- ✗ Reference docs → `<workspace.root>/3-Resources/reference/`
- ✗ Random thoughts → `<workspace.root>/0-Inbox/`

## Naming convention

```
memory/
├── memory.md                    # lowercase — index of this folder
├── YYYY-MM-DD.md                # daily logs, one file per day
├── writing-style.md             # style profile, lives at root
├── learned-preferences.md       # curated preferences, lives at root
└── (other long-form, kebab-case filenames)
```

## How `<assistant.name>` uses this folder

- **Session start** — both `memory.md` (this folder's index) AND `MEMORY.md` (Folder A index) load automatically. `<assistant.name>` orients from both.
- **Daily logs** — at end of session, `<assistant.name>` may append a summary to today's `YYYY-MM-DD.md` if there's a meaningful decision to retain
- **Writing tasks** — when drafting in `<user.name>`'s voice (QBRs, PRDs, exec memos), `<assistant.name>` reads `writing-style.md` first
- **`/find <topic>`** — searches this folder for prior decisions; daily logs are especially useful for "what was I thinking last quarter?"

## Daily log structure

```markdown
# YYYY-MM-DD

## What I worked on
- Shipped X
- Made decision Y in [project]
- Spoke with [person] about Z

## Decisions worth remembering
- Decided: <decision>
  - Because: <reasoning>
  - Will revisit: <when, if ever>

## Open threads
- Waiting on X from <person>
- Still chasing Y

## Notes for tomorrow
- First thing: <action>
```

The structure is loose; the rule is **append-only**. Don't rewrite past days. If you change your mind, note the reversal in a future day's log.

## `memory.md` (the index)

This file lists what's in the folder. Keep it under 200 lines. When the folder gets too sprawling, the index helps `<assistant.name>` know what's available without reading every file.

Example structure:

```markdown
# Memory Index

## Daily logs
- [2026-10-15](2026-10-15.md) — Pricing redesign kickoff, decided two-phase ship
- [2026-10-16](2026-10-16.md) — Sync with Alex; copy ETA Wednesday
- ...

## Curated long-form
- [writing-style.md](writing-style.md) — voice profile for QBRs/PRDs
- [learned-preferences.md](learned-preferences.md) — durable do/don't rules
```

## Lifecycle

- **Capture** — append to today's `YYYY-MM-DD.md` during/after work sessions
- **Curate** — periodically (monthly?), extract durable patterns into `learned-preferences.md` or `writing-style.md`
- **Index** — update `memory.md` index when adding a new long-form file
- **Retain** — never delete daily logs. They're history. `/find` traverses them.

## Privacy

This folder is **git-tracked** by default — daily logs and writing-style notes sync across machines. That means everything here goes to your git remote.

If a daily log entry has content that shouldn't be committed (someone shared confidential info, a piece of personal context), either:
- Redact before saving
- Save it to Folder A (auto-memory, not git-tracked) instead

The dual-folder model exists partly so curated git-tracked memory can stay clean while ephemeral live preferences stay local.

## Tips

- **Append daily, even if it's "no shipping today."** Gaps in the log are losses.
- **Decisions over status.** The value isn't "what I did today" — it's "what I decided and why." Bias toward decisions in your log entries.
- **Don't over-curate.** Daily logs can be rough; `writing-style.md` and `learned-preferences.md` are the curated layer. Don't try to make every daily entry publication-quality.
- **Periodic compression.** If three months of daily logs all say "kept pushing on the Q4 redesign," extract the patterns into a curated long-form file and let the daily logs stand as raw record.

## Boundary

`<assistant.name>` does not auto-rewrite or compress this folder. Curation is deliberate, not automated. The risk of losing context outweighs the convenience of tidiness.
