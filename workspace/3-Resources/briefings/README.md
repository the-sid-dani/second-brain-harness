# briefings

Output of `/briefing` — daily morning briefs. `<assistant.name>` writes here; `<user.name>` reads.

## Purpose

The morning brief is the single highest-value moment of `<assistant.name>`'s day. It composes whatever signal sources are configured (email, calendar, messaging, issue-tracking, code-hosting) PLUS local sources (`contacts/`, active projects, `USER.md` priority signals) into a structured document that surfaces what needs attention today and recommends what to ship.

Briefings live in this folder so you can re-read past ones (consumed by future `/briefing` runs as recency context, and useful for "what was I working on three weeks ago?").

## Naming convention

```
briefings/
├── morning-briefing-YYYY-MM-DD.md          # canonical one-per-day brief
└── morning-briefing-YYYY-MM-DD-HHMM.md     # collision file when re-run same day
```

Re-running `/briefing` on the same day produces a timestamped file rather than overwriting (Tiger T1 — preserves what you may have already read or edited).

## What belongs here

- ✓ Morning briefs (`/briefing` output)
- ✓ Re-run briefs from the same day (with `-HHMM` suffix)
- ✓ Manually-edited briefs (you can annotate a brief after reading; they stay here)

## What doesn't belong here

- ✗ Meeting prep → `meeting-prep/` (next door)
- ✗ Weekly/monthly digests → planned `/weekly-digest` skill will write elsewhere
- ✗ Standup notes → planned `/standup` skill will write to its own folder
- ✗ Raw transcripts → `meetings/`

## How `<assistant.name>` uses this folder

- **`/briefing`** — writes here at the start of the workflow; reads recent briefs (last 7 days) as recency context to avoid recommending the same thing two days in a row
- **`/find <topic>`** — searches across briefings for past mentions; useful for "what was I prioritizing in October?"
- **`/save-resource`** — won't route here; briefings are agent-generated, not user-captured

## Brief structure (what's inside each file)

Each brief follows a stable section order so downstream tooling (planned `/weekly-digest`, `/standup`) can parse it:

1. `# Morning brief — YYYY-MM-DD` (H1)
2. `## What needs you today` — top 5-7 urgent items (from email + calendar + Jira + Slack mentions)
3. `## Calendar at a glance` — today's events
4. `## Today's work from your projects` — per-project synthesis with status emoji
5. `## Slack digest` (if Slack MCP configured)
6. `## Jira queue` (if Atlassian MCP configured)
7. `## Open commitments by person` — from `contacts/` (personal contacts filtered out)
8. `## Recent shipped` — last 7 days of GitHub PRs (if `gh` CLI configured)
9. `## Notes & cross-references` — optional
10. `## Tools used` — transparency footer listing composed vs not-configured sources

Sections backed by tools you don't have configured are silently omitted from the body but documented in the `## Tools used` footer.

## Maintenance

- **Don't delete past briefings.** They're cheap to keep and provide historical context. `/find` searches them.
- **Archive on a cadence if the folder gets crowded.** After a year or so, move older briefings to `<workspace.root>/4-Archive/briefings/YYYY/` to keep this folder navigable.
- **The format may evolve.** As new skills get built (`/standup`, `/weekly-digest`), the brief structure may add sections. Old briefs stay in their original format; new briefs use new format. No retroactive rewrites.

## Privacy note

Briefings synthesize signal from email, calendar, messaging — they will contain whatever sensitive content was in those sources. This folder is git-tracked. Either:
- Trust that the harness git remote is private/secure, OR
- Add this folder to `.gitignore` if briefings shouldn't be committed

The default ships git-tracked because most users want briefings to sync across machines.

## Tips

- **Read the brief, then close it.** The brief's job is to orient you — don't try to read every section linearly. Look at "Top 3 from What needs you today" + the project synthesis recommendation, then act.
- **Don't ask `<assistant.name>` to re-explain the brief.** If a section is unclear, look at the `## Tools used` footer to see what was composed vs skipped — often "unclear" means a section was sparse because a tool errored.
- **Use the brief as a starting point, not a script.** The recommendation "highest-leverage work today is X" is opinionated; if you disagree, do something else. `<assistant.name>` recommends; `<user.name>` decides.
