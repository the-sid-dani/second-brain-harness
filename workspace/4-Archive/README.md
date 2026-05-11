# 4-Archive

Completed or inactive work. **Move, never delete** — provenance matters; storage is cheap.

## Purpose

`4-Archive/` is the long-term memory of the workspace. When a project finishes (or gets killed), it moves here with its `CLAUDE.md` status flipped to `done`. When research goes stale, it moves here. When a code repo stops being actively developed, the index row stays but the repo may move to `2-Coding/archive/`.

This folder exists because **deleting kills context**. Six months from now, "did I ever work on X?" should always be answerable. The answer might be "yes, here's what we shipped and why we stopped" — but it's never "no record exists."

## What belongs here

- ✓ Completed projects (`/archive-project` moves them here)
- ✓ Killed/descoped projects (still archive, with a "why killed" entry in `memory.md`)
- ✓ Stale research that no longer informs anything current
- ✓ Old briefings (>1 year — optional housekeeping)
- ✓ Snapshots that have been superseded (e.g., past org-chart versions)

## What doesn't belong here

- ✗ Active projects → `1-Projects/`
- ✗ Currently-relevant reference docs → `3-Resources/reference/` (don't archive things you'll re-read soon)
- ✗ Code repos still under development → `2-Coding/<scope>/`
- ✗ A project that's "paused" — keep in `1-Projects/` with `status: paused` frontmatter; archive only when truly done

## Structure

Archived projects keep their original folder structure — moved as-is:

```
4-Archive/
├── 2025-11-ai-task-force-planning/    # original YYYY-MM-slug preserved
│   ├── CLAUDE.md                       # status: done (auto-flipped by /archive-project)
│   ├── memory.md                       # full history retained
│   └── (whatever else was in the project folder)
├── 2026-01-q1-qbr-prep/
├── briefings/                          # optional: old briefings archived in bulk
│   └── 2024/
└── research/                           # optional: stale research moved here
    └── 2024-08-old-llm-pricing-analysis.md
```

## How `<assistant.name>` uses this folder

- **`/archive-project <slug>`** — primary write path. Moves `<workspace.root>/1-Projects/<slug>/` to here, flips `status:` frontmatter, optionally appends a retro paragraph to `memory.md`
- **`/find <topic>`** — searches archive as part of its scope. This is the killer feature: "have I done something like this before?" gets the right answer 18 months later
- **`/new-project`** Step 0 — searches archive for matches before scaffolding. If a similar project exists in archive, offers to **revive** (move back to `1-Projects/`, flip status to `active`, append `revived: <date> — <reason>` to `memory.md`) instead of creating a duplicate
- **`/prune-projects`** — Friday review may suggest archiving stale projects (no activity in 30+ days)

## Lifecycle: archive vs revive

The flow is two-way:

**Archive** (from `1-Projects/` to `4-Archive/`):
```
/archive-project 2026-10-q4-pricing
→ mv 1-Projects/2026-10-q4-pricing/ → 4-Archive/2026-10-q4-pricing/
→ flip frontmatter: status: active → status: done
→ append retro paragraph to memory.md (optional)
```

**Revive** (from `4-Archive/` back to `1-Projects/`):
```
(manual — no skill yet, but cheap and well-documented)
mv 4-Archive/2026-10-q4-pricing/ 1-Projects/2026-10-q4-pricing/
edit frontmatter: status: done → status: active
append to memory.md: "revived: 2027-03-15 — vendor came back with new pricing"
```

Reviving preserves the lineage in one folder rather than creating a `<topic>-revival` sibling that fragments history. This is enforced as an Operating Principle in `SOUL.md`: "Revive before scaffold."

## What's NOT here (intentional)

This folder is NOT a trash can. Don't move things here just to declutter — that's what `0-Inbox/` is for during triage. The threshold for "this belongs in archive" is **"work that had a defined end state and reached it (or was killed)"** — not "stuff I don't need right now."

A paused project with `status: paused` stays in `1-Projects/`. A research note you might use next month stays in `research/`. The archive is for things that closed out.

## Tips

- **Archive with intent.** When `/archive-project` asks for an optional retro, write one. A 3-sentence retro in `memory.md` ("What shipped: X. What didn't: Y. Lesson: Z.") is the most valuable artifact in the workspace 6 months later.
- **Trust `/find` over folder navigation.** Don't manually browse the archive looking for something — `/find <topic>` is faster and won't miss things in unexpected sub-trees.
- **Don't reorganize the archive.** Re-naming or moving folders inside archive breaks the lineage. Add notes if you must annotate; never restructure.
- **Storage is cheap.** Don't agonize over what to archive vs delete. Default to archive.

## Boundary

`<assistant.name>` does not delete from `4-Archive/`. The only "remove" operations are:
- Manual user `rm` (rare; basically only for accidentally-archived sensitive content)
- Manual user `mv` back to `1-Projects/` for revival

Even then, history retention is the priority. If you're tempted to delete from archive, ask why — usually the better answer is to move the sensitive file elsewhere and leave the project structure intact.
