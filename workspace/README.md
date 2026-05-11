# Workspace

The PARA-style work area for everything you do with `<assistant.name>` — projects, code, research, meeting transcripts, briefings, archive. This README is the entry-point for understanding the folder layout.

## Layout

```
<workspace.root>/
├── 0-Inbox/         # ad-hoc / not-yet-decided capture zone
├── 1-Projects/      # active projects (YYYY-MM-slug/ with CLAUDE.md + memory.md)
├── 2-Coding/        # code repos (gitignored): work/personal/forks/archive
├── 3-Resources/     # reference layer: templates, meetings, reference, research,
│                    # contacts, design-systems, briefings, meeting-prep,
│                    # organization-reports
└── 4-Archive/       # completed / inactive (move, never delete)
```

Each folder has its own README explaining what belongs there and how `<assistant.name>` uses it.

## Why PARA

PARA is a personal-knowledge-management system invented by Tiago Forte — **P**rojects, **A**reas, **R**esources, **A**rchive. The "Areas" slot is intentionally absent here because ongoing rhythms (your job role, weekly responsibilities) get handled by skills (`/briefing`, `/standup`) rather than a folder. The numeric prefixes (`0-Inbox`, `1-Projects`, etc.) keep things in logical order in your file browser.

## The 30-second navigation guide

| You want to... | Go here |
|----------------|---------|
| Capture a half-formed idea you might revisit | `0-Inbox/` |
| Work on a time-bound deliverable | `1-Projects/<slug>/` |
| Spin up a new code repo | `2-Coding/<scope>/<name>/` |
| File a meeting transcript | `3-Resources/meetings/` |
| Read past briefings | `3-Resources/briefings/` |
| Save research / reference docs | `3-Resources/research/` or `3-Resources/reference/` |
| Look up a person | `3-Resources/contacts/<slug>.md` |
| Find finished work | `4-Archive/` |

## How `<assistant.name>` uses this layout

`<assistant.name>` reads the Configuration section in root `CLAUDE.md` to resolve `<workspace.root>` (this folder), `<workspace.projects>` (`1-Projects/`), etc. The skills don't hardcode paths — they reference tokens, so the layout adapts when you fork the harness and rename folders.

Skills that span this whole layout:
- **`/find <topic>`** — searches across active projects, archive, code repos, and research for prior work on a topic. Use this BEFORE scaffolding anything new (Operating Principle: "connect before create").
- **`/briefing`** — composes today's brief by reading each active project's `memory.md` tail, plus optional signals from external tools (email, calendar, messaging, issue-tracking, code-hosting — whichever you have configured).
- **`/inbox-process`** — Friday triage of `0-Inbox/`; promotes things to `1-Projects/` or files them in `3-Resources/`.
- **`/prune-projects`** — Friday review of stale `1-Projects/` (no activity in 14+ days); archives or revives.

## Two memory locations (don't conflate)

- **Auto-memory** at `~/.claude/projects/<cwd-hash>/memory/` — per-machine, managed by Claude Code. Indexed by `MEMORY.md` (uppercase). Lives outside this folder.
- **Project memory** at `<workspace.root>/../memory/` — git-tracked, curated by you + `<assistant.name>`. Daily logs (`memory/YYYY-MM-DD.md`), writing-style notes, learned preferences.

See the repo-root `README.md` for the full dual-folder explanation.

## Conventions

- **Folder names use `YYYY-MM-<slug>`** in `1-Projects/` and `4-Archive/` — date prefix orders chronologically; slug describes the work
- **`memory.md` is append-only** in every project folder — never rewrite prior entries
- **Never delete** — move to `4-Archive/`. Provenance matters; storage is cheap
- **Status frontmatter** (`status: active | paused | done`) on every project's `CLAUDE.md` is the contract that `/briefing`, `/prune-projects`, and `/archive-project` read

## When in doubt

Read the README in the specific subfolder. If you're not sure where something belongs, put it in `0-Inbox/` and run `/inbox-process` on Friday. Capturing first and triaging later beats agonizing over the "right" location.
