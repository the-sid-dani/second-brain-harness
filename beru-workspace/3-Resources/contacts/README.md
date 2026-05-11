# Contacts

Per-person reference directory. One file per person, slug-named (`jordan-chen.md`, `alex-rivera.md`). No date prefix — people aren't time-bounded.

**Locked by decisions #21 and #22 in `beru-workspace/1-Projects/2026-05-second-brain-design/system-design.md` §7.**

## Why this exists

For <assistant.name> to track commitments obsessively (per SOUL.md), it needs to know:
- **Who** the user talks to (identity, role, relationship)
- **What** was discussed and promised (interaction log + open commitments)
- **When** they last interacted (recency for "you haven't talked in a while" surfacing)
- **Context** about them (background, expertise, recurring topics)

Without this, `/briefing`'s "Open commitments by person" section is shallow and `/meeting-prep` can't surface "what did you promise X last time."

## Why Resources, not memory/

Contacts are **reference material** (entity-keyed lookup) — same shape as `meetings/`, `reference/`, `research/`, `design-systems/`. They're NOT "stuff <assistant.name> learns about <user.name>" — that's `memory/` (daily logs, writing-style.md, learned-preferences.md).

The journal of any specific interaction lands in `memory/YYYY-MM-DD.md`. The durable per-person directory lives here.

## Per-file schema

```yaml
---
name: Jordan Chen                     # required — preferred / everyday name
legal_name: Jordan E. Chen            # optional — when preferred ≠ legal
email: jordan@example.com             # required (use 'unknown' if not yet known)
role: Director of Engineering         # required (use 'unknown' if not yet known)
team: Platform Infrastructure         # required — canonical team name (may differ from directory)
department: Engineering               # optional — directory's Department field
division: Technology                  # optional — directory's Division field
company: Acme Corp                    # required (or 'unknown' for personal contacts)
relationship: peer; senior counterpart on shared platform projects   # required — free-form descriptor
status: active                        # required — active | inactive | external | personal
first_logged: 2026-05-01              # required — when contact file created
last_interaction: 2026-05-08          # required — date of last logged interaction (use 'unknown' if not yet known)
reports_to: Sam Patel                 # optional — direct manager per directory
recurring_cadence: weekly 1:1         # optional — natural-language cadence
location: San Francisco, CA           # optional — primary work location
work_phone: '5555550100'              # optional — directory's Work Phone
tags: [direct-collaborator, platform, senior-peer]   # optional
slack_handle: '@jordan'               # optional
timezone: America/Los_Angeles         # optional
linkedin: linkedin.com/in/jordanchen  # optional
---

## About
Free-form context — background, expertise, things <user.name> wants surfaced when this name comes up. Update over time.

## Recurring topics
- Platform architecture
- Roadmap planning
- ...

## Open commitments

### To <name> (<user.name> owes)
- [ ] 2026-05-04 — share architecture doc — by 2026-05-10

### From <name> (owes <user.name>)
- [ ] 2026-05-04 — review platform PR — by 2026-05-12

## Interaction log
### 2026-05-04 — weekly sync
- Topic: Platform architecture, roadmap alignment
- Decisions: agreed on per-service auth pattern
- <user.name> promised: share architecture doc
- Jordan promised: PR review by next Friday

### YYYY-MM-DD — <topic>
- ...
```

## How <assistant.name> uses these

- **`/contact <name>`** (Pass 4 #34) — fuzzy-match → display profile + last interaction + open commitments. Composes `/find` to surface mentions across projects/meetings/research.
- **`/contact-log <name>`** (Pass 4 #35) — append a new interaction entry to the log section; auto-bumps `last_interaction` frontmatter.
- **`/contact-add <name>`** (Pass 4 #35) — scaffold a new contact file from a prompt; optional `--enrich` flag pulls Workspace directory data via `gws-people`.
- **`/contact-audit`** (Pass 4 #36) — scans daily logs + meetings/ for names mentioned ≥2× but missing from contacts/, asks if they should be added.
- **`/briefing`** (Pass 3 #16) — reads contacts/ for the "Open commitments by person" section.
- **`/meeting-prep`** (Pass 3 #17) — reads the relevant contact file before generating prep.
- **`/find`** — already indexes contacts/ as part of resources/ scope (decision #18).

## WikiLinks

Daily logs and project notes reference contacts as `[[contacts/<slug>]]` so `/find` traces the relationship graph. Example in a daily log: "Met with [[contacts/jordan-chen]] re: platform architecture."

## Maintenance

- **Every contact needs `first_logged` + `last_interaction` minimum** in frontmatter for `/contact-audit` to work.
- **Append to the Interaction log; never rewrite.** Same rule as project memory.md.
- **Status `inactive`** when someone leaves the company or stops being relevant — keeps the file for historical record but `/briefing` and `/contact-audit` skip them.
- **Status `external`** for people outside <user.company> in a business context (vendors, candidates, peer-company contacts, partners).
- **Status `personal`** for non-business contacts: friends, family, side-project collaborators, anyone outside the work scope. `/briefing` and other work-context skills should filter `status: personal` out by default. **Privacy note:** personal contact data lives in a git-tracked file — capture only what's appropriate to commit.

## Source of truth

If your organization has an authoritative directory (Workspace directory, HR records, employee export), use it for `role`, `department`, `division`, `location`, `work_phone`, `reports_to`. Directory data may have stale team names — the canonical `team` field stays in the contact file; the directory's `department` is captured separately.
