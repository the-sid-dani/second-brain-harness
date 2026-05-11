# organization-reports

Analytical reports about your organization, team, or work patterns. `<assistant.name>` writes these on request; they're snapshots that age, not durable reference.

## Purpose

Periodically you want to ask `<assistant.name>` something analytical that produces a meaty document — "map out the AI initiatives across the company," "summarize the engineering org structure," "audit my email patterns over the last quarter." Those outputs land here as date-stamped snapshots.

This folder is the catch-all for "agent-generated analysis that's bigger than a brief but smaller than a project."

## What belongs here

- ✓ Org chart syntheses ("team-org-snapshot-2026-Q4.md")
- ✓ Cross-functional initiative maps ("ai-initiatives-across-samba-2026-10.md")
- ✓ Communication pattern audits ("email-volume-by-team-2026-Q3.md")
- ✓ Activity reports ("github-activity-last-90-days.md")
- ✓ Meeting frequency analyses ("meeting-load-by-week-2026.md")
- ✓ Any other agent-generated report that doesn't fit `briefings/` or `meeting-prep/`

## What doesn't belong here

- ✗ A morning briefing → `briefings/`
- ✗ Pre-meeting prep → `meeting-prep/`
- ✗ Raw data → `reference/` (if durable) or `0-Inbox/` (if uncertain)
- ✗ Research notes → `research/`
- ✗ Per-person profiles → `contacts/<slug>.md`
- ✗ Project-specific analyses → that project's folder in `1-Projects/`

## Naming convention

```
organization-reports/
├── YYYY-MM-<topic-slug>.md             # standalone report
└── YYYY-MM-<topic-slug>/                # folder if it has multiple files
    ├── report.md
    ├── data.csv
    └── charts/
```

Date prefix is **when the snapshot was taken** (data vintage matters — an org chart from 2025 isn't current). Topic slug describes what the report is about.

## How `<assistant.name>` uses this folder

- **Manual invocation** — when `<user.name>` asks "give me a report on X" and the answer is too large for the chat window, `<assistant.name>` writes the report here and surfaces the path
- **`/find <topic>`** — searches across reports for past analyses on the topic
- **Re-use as input** — if `<user.name>` asks for an updated version of a past report (e.g., "redo the AI initiatives map for Q4 2027"), the prior report is the starting point

## Examples of what generates reports here

- "Map out all the AI initiatives across <company> and who owns each"
- "Audit my email volume by sender over the last 90 days"
- "Summarize what each team in the engineering org is working on"
- "Pull together a snapshot of who's joined / left / changed roles in the last quarter"
- "Compare meeting load this quarter vs last quarter"

All of these are too big to dump in the chat window and too snapshot-y to belong in `reference/`. They go here.

## Lifecycle

1. **Generate** — `<user.name>` asks for an analytical report; `<assistant.name>` writes it here
2. **Read** — `<user.name>` reviews; may copy excerpts into a deck, presentation, or `1-Projects/<slug>/`
3. **Reference** — future requests for similar reports use the prior version as a starting point
4. **Stale-out** — most reports age out within 6-12 months. Archive to `<workspace.root>/4-Archive/organization-reports/` when no longer relevant

## Maintenance

- **Date prefix is non-negotiable** — without it, you can't tell a current report from a stale one
- **One report per file/folder** — don't bundle unrelated analyses
- **Source the data** — include a "Data sources" section so a future reader knows where the numbers came from (Gmail query, BigQuery, manual count, etc.)
- **Capture the prompt that generated the report** — at the bottom, include "Original request: <quote>" so future re-runs can replay the same analysis

## Tips

- **Treat reports as artifacts of a moment.** They're not living documents. If you want a regularly-updated version, ask `<assistant.name>` to re-generate (new date prefix), don't edit the original.
- **Cross-link from active projects.** If a report informs a project, link to it from the project's `memory.md`: "Analysis came from `[[organization-reports/2026-10-ai-initiatives-map]]`."
- **Don't auto-generate without a request.** This folder fills up fast if `<assistant.name>` writes reports proactively. Reports are heavy outputs — generate on demand.

## Privacy

Org reports often contain sensitive info (compensation, headcount changes, internal initiatives). This folder is git-tracked — be deliberate. If a report shouldn't be committed, either `.gitignore` the file or store it outside the harness.
