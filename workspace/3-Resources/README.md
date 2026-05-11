# 3-Resources

Reference material — durable docs you re-read, lookup-by-entity (contacts, design systems), pre-condensed inputs (meeting transcripts), and synthesis outputs (briefings, meeting prep, organization reports).

## Purpose

`3-Resources/` is the layer between **transient capture** (`0-Inbox/`) and **active work** (`1-Projects/`). Things here have proven they're worth keeping but don't have a deadline or deliverable attached. The pattern: if you'll look it up again in a month, it lives here.

## Layout

```
<workspace.root>/3-Resources/
├── briefings/              # /briefing outputs (morning briefs)
├── contacts/               # per-person reference (one file per person)
├── design-systems/         # 73 brand presets for /design-* skills
├── meetings/               # meeting transcripts (Tactiq, Gemini, manual)
├── meeting-prep/           # /meeting-prep outputs (planned skill)
├── organization-reports/   # /organize and analytical reports
├── reference/              # durable docs (employee directory, tool inventory)
├── research/               # research notes by topic
├── templates/              # project + persona templates + project-query.sh
└── code-projects.md        # index of repos in 2-Coding/ (gitignored folder)
```

Each subfolder has its own README explaining what belongs there and how `<assistant.name>` uses it. Read those before filing.

## Subfolder one-liners

| Folder | What it holds | Pattern |
|--------|---------------|---------|
| `briefings/` | Output of `/briefing` — daily morning briefs | Agent-written; re-read by user; consumed by future briefings |
| `contacts/` | Per-person profiles + interaction logs | Entity-keyed lookup (one file per person) |
| `design-systems/` | 73 brand presets (Apple, Linear, Stripe, etc.) | Pick one via `/use-design <brand>` |
| `meetings/` | Raw transcripts | User-collected; consumed by `/briefing` + `/meeting-prep` |
| `meeting-prep/` | Pre-meeting briefs | Agent-written; consumed before each meeting |
| `organization-reports/` | Org analytics, team breakdowns | Agent-written; periodic refreshes |
| `reference/` | Durable docs (employee directory, tool inventory) | User-curated; rarely changes |
| `research/` | Research notes by topic | User-written; grows over time |
| `templates/` | Scaffold templates + `project-query.sh` | Used by skills, edited rarely |
| `code-projects.md` | Index of `2-Coding/` repos | Maintained by `/new-project` + `/sync-indexes` |

## What belongs in 3-Resources (vs elsewhere)

- ✓ A reference doc you'll re-read for years (org chart, tool inventory) → `reference/`
- ✓ A research note on a topic that may inform future projects (LLM pricing trends, RAG patterns) → `research/`
- ✓ A meeting transcript → `meetings/`
- ✓ A contact you'll want to look up → `contacts/<slug>.md` (use `/contact-add`)
- ✓ Agent-generated synthesis (briefing, meeting prep, org report) → respective subfolder

## What doesn't belong here

- ✗ Active project work → `1-Projects/<slug>/`
- ✗ Half-formed captures → `0-Inbox/`
- ✗ Code → `2-Coding/<scope>/<repo>/`
- ✗ Finished projects → `4-Archive/`

## How `<assistant.name>` uses this folder

- **`/find <topic>`** — searches across `research/`, `reference/`, `meetings/`, `contacts/`, and `briefings/` for prior work on a topic
- **`/save-resource`** — files a resource into the right subfolder (asks you which one, defaults sensibly)
- **`/briefing`** — writes to `briefings/`; reads from `contacts/`, `meetings/` (optional cross-ref)
- **`/contact <name>`** — reads from `contacts/`
- **`/contact-log <name>`** — appends to a contact's interaction log
- **`/contact-add`** / **`/contact-research`** / **`/contact-audit`** (planned) — write to `contacts/`
- **`/meeting-prep`** (planned) — reads from `meetings/` + `contacts/`; writes to `meeting-prep/`
- **`/use-design <brand>`** — copies a brand from `design-systems/<brand>/DESIGN.md` to the root `DESIGN.md` (active brand for the workspace)

## Pattern: "synthesis next to source"

Notice that `meetings/` (raw transcripts) and `meeting-prep/` (agent-written prep docs) are siblings — same for `briefings/` next to the calendar/email/Slack feeders. This is intentional: keeping synthesis output near its source makes "go back and re-read both" a one-folder navigation, not a hunt across the workspace.

## Conventions

- **Per-subfolder naming rules are documented in each subfolder's README** (e.g., `contacts/` uses person-slugs; `briefings/` uses `morning-briefing-YYYY-MM-DD.md`)
- **Reference files use kebab-case slugs** — `employee-directory.xlsx`, `tool-inventory.md`
- **No date prefix in `reference/`** — these are timeless lookups; the file IS the resource
- **Date prefix in `research/`** — research notes age out; `2026-10-llm-pricing-analysis.md` shows when the snapshot was taken

## When in doubt

If you're not sure which subfolder something belongs in, use `/save-resource` — it asks the right routing questions. Or drop the file in `0-Inbox/` and let `/inbox-process` sort it on Friday.
