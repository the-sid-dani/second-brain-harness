# reference

Durable lookup material — the org chart, the tool inventory, the employee directory, the canonical CSVs and spreadsheets you'll re-read for months or years.

## Purpose

`reference/` is for **content that ages slowly**. If you're going to re-read this file in 3 months and it'll still be roughly right, it belongs here. Research notes (which age quickly) go in `research/` instead.

## What belongs here

- ✓ Employee directory exports (CSV/Excel from HR)
- ✓ Tool inventory (what CLIs / MCPs / services are in your stack)
- ✓ Org chart snapshots
- ✓ Standardized templates that aren't `templates/` material (e.g., a one-pager template you reuse for proposals)
- ✓ Canonical configuration references (e.g., the list of priority Slack channels you watch)
- ✓ Glossaries — internal acronym lists, jargon translations

## What doesn't belong here

- ✗ Time-bounded research notes → `research/`
- ✗ Per-person info → `contacts/<slug>.md`
- ✗ Meeting transcripts → `meetings/`
- ✗ Project-specific docs → that project's folder in `1-Projects/`
- ✗ Scaffold templates used by skills → `templates/`

## Examples

```
reference/
├── employee-directory.xlsx              # HR export, updated quarterly
├── tool-inventory.md                    # what's in your stack + verification probes
├── samba-org-chart-2026-q4.md           # org snapshot with date suffix
├── acronyms-glossary.md                 # internal jargon (PAM, MSci, etc.)
├── proposal-template-one-pager.md       # reusable structure
└── priority-slack-channels.md           # canonical channel list (also in USER.md)
```

## Naming convention

- **Timeless docs**: no date prefix — `employee-directory.xlsx`, `tool-inventory.md`
- **Snapshots that age**: date suffix — `samba-org-chart-2026-q4.md` (so you can keep multiple snapshots and tell them apart)
- **Use kebab-case** — `tool-inventory.md` not `Tool Inventory.md`

## How `<assistant.name>` uses this folder

- **`/find <topic>`** — searches `reference/` content as part of its search scope. The employee directory is especially useful: "who's the EM for the data team?" → `/find data team EM` may surface the directory entry.
- **`/contact-add`** / **`/contact-research`** (planned) — when adding a new contact, may pull seed data from `employee-directory.xlsx` if the person is in your org
- **`/briefing`** Step 0 — reads `USER.md` "Priority Slack Channels" section; that list can also live as a standalone `reference/priority-slack-channels.md` if you'd rather keep `USER.md` lean
- **Manual reads** — when `<user.name>` asks "what tools do I have configured?" or "who's on Jordan's team?", `<assistant.name>` reads files here directly

## Maintenance

- **Refresh on a cadence.** The employee directory ages — re-export quarterly. Org chart changes — snapshot on org-change events.
- **Date-suffix snapshots** so you can keep history. Keep the latest as the un-dated canonical (e.g., `employee-directory.xlsx` is latest; older versions get archived to `4-Archive/<date>/`).
- **Don't let stale snapshots accumulate.** If you have 12 monthly org-chart snapshots, archive 11 and keep one quarter's worth in `reference/`. Provenance survives in `4-Archive/`.

## Privacy

Some reference content is sensitive (employee directory, compensation grids, internal contact info). This folder is git-tracked — be deliberate. If a file shouldn't be in version control, add it to `.gitignore` or store it outside the harness entirely.

## Tips

- **Cross-reference from CLAUDE.md.** If a tool inventory or org chart is load-bearing for the workspace, link to it from root `CLAUDE.md` so `<assistant.name>` knows to read it.
- **Pre-condense for `<assistant.name>`.** A 50-row CSV is slow to read. If you have a "top 10 contacts to keep top-of-mind" subset, extract that into a tighter file (`top-contacts.md`) for fast `/briefing` reads.
- **One source of truth per fact.** If the org chart says X but the directory says Y, pick one as canonical and link the other to it. Drift between reference docs is the silent killer.
