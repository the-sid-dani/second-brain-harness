# 1-Projects

Active initiatives with a clear deliverable and a defined "done" state.

## Purpose

A project in this workspace is **time-bound work with a specific outcome**. Each project lives at `<workspace.root>/1-Projects/YYYY-MM-<slug>/` and gets a `CLAUDE.md` (status frontmatter) plus an append-only `memory.md` (decision log).

If something will "always be ongoing" (your job role, a hobby, weekly responsibilities) it's *not* a project. This harness intentionally has no "Areas" folder — ongoing rhythms get handled by skills (`/briefing`, `/standup`) or stay in your memory.

## What belongs here

- ✓ "Q3 Pricing Page Redesign" — clear scope, deadline
- ✓ "AI Strategy Doc for Q4 Planning" — finite deliverable
- ✓ "MCP Server for X" — has a "shipped" definition
- ✓ "Hiring: Senior PM (req-0042)" — closes when role is filled
- ✓ "Migrate Customer Data to Snowflake" — has a done state

## What doesn't belong here

- ✗ "Health and fitness" — ongoing, no end-state → personal habit, not workspace material
- ✗ "Daily email triage" — recurring activity → handled by `/briefing`
- ✗ "Random research on LLM pricing" → `3-Resources/research/`
- ✗ "Half-baked idea I'm not sure about" → `0-Inbox/`, triaged via `/inbox-process`
- ✗ A code repo → `2-Coding/<scope>/<name>/` (use `/new-project` with code-repo branch)

## Structure

Each project is scaffolded by `/new-project` and gets exactly two mandatory files:

```
1-Projects/2026-10-q4-pricing-redesign/
├── CLAUDE.md         # status frontmatter (active|paused|done), project-type,
│                     # one-line summary, key links — under 60 lines
└── memory.md         # append-only decision log
                      # (anything else you add — drafts, sub-docs — your call)
```

Everything beyond those two files is project-specific. Add a `drafts/` folder if you're iterating on content. Add `research/` if you're doing project-scoped lit review. The shape is yours.

### `CLAUDE.md` frontmatter (the contract)

```yaml
---
status: active        # active | paused | done
created: YYYY-MM-DD
project-type: design  # design | research | execution | content | meeting | ongoing
stakeholders: [<user.name>]
---
```

The `status:` and `project-type:` fields are read by `/briefing`, `/prune-projects`, and `/archive-project`. Keep them accurate.

### `memory.md` (the decision log)

Append-only. Each entry is a dated block describing decisions, blockers, next actions. Never rewrite history — if you change your mind, append a new entry with the reversal.

```markdown
## 2026-10-15
- Decided: Ship the redesign in two phases
- Blocked: Waiting on copy from marketing
- Next: Sync with Alex on Monday

## 2026-10-16
- Spoke with Alex — copy ETA Wednesday
- ...
```

## How `<assistant.name>` uses this folder

- **`/new-project <slug>`** — scaffolds a new project here with `CLAUDE.md` + `memory.md`
- **`/briefing`** — reads each project's `memory.md` tail + `CLAUDE.md` status to recommend today's highest-leverage work
- **`/find <topic>`** — searches across all project memories for past decisions on a topic
- **`/prune-projects`** — Friday-batch review of stale projects (no activity in 14+ days); archives or revives
- **`/archive-project <slug>`** — moves a completed project to `4-Archive/` and flips status to `done`

## Project lifecycle

1. **Scaffold** — `/new-project` creates the folder + frontmatter. If a similar project already exists, Step 0 of `/new-project` will offer to revive it from `4-Archive/` instead of forking a duplicate.
2. **Work** — append to `memory.md` as decisions land; update `CLAUDE.md` status if it changes (e.g., `active` → `paused`)
3. **Review** — weekly `/briefing` surfaces project state; `/prune-projects` catches stale ones every Friday
4. **Complete** — `/archive-project <slug>` moves it to `4-Archive/` and flips status to `done`. Optional one-paragraph retro appended to `memory.md` before the move.

## Conventions

- **Folder name = `YYYY-MM-<slug>`** — date prefix orders chronologically, slug describes the work in 2-4 words
- **`memory.md` is append-only** — same rule as the daily memory log; never rewrite, only append
- **Keep `CLAUDE.md` under 60 lines** — it's the project's identity card; decisions go in `memory.md`, not here
- **One project per folder** — don't bundle unrelated work; if you find yourself splitting attention, those are two projects

## When to archive

Move to `4-Archive/` (via `/archive-project`) when:
- All deliverables shipped
- Project was killed or descoped
- Inactive for 30+ days with no plan to resume
- Transformed into a code repo (cleaner home in `2-Coding/`)

Always append a "wrap-up" entry to `memory.md` before archiving — what shipped, what didn't, what `<user.name>` learned. Provenance survives.

## Tips

- **Start with the smallest viable scaffold.** A `CLAUDE.md` saying "Get the Q4 pricing page redesigned" + an empty `memory.md` is enough. Add structure as you go.
- **Append every decision, even the small ones.** `memory.md` is what `/briefing` reads to recommend next actions. Thin memory = bad recommendations.
- **Don't let projects rot.** If `<assistant.name>` flags it as stale during `/prune-projects`, either revive (append a "still active because X" entry) or archive. Don't let `1-Projects/` become a graveyard.
