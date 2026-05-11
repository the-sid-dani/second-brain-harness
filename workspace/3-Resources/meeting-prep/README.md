# meeting-prep

Pre-meeting briefs. `<assistant.name>` writes these before each meeting so `<user.name>` walks in oriented.

## Purpose

Walking into a meeting cold means missing context, repeating questions, and forgetting prior commitments. A pre-meeting brief from `<assistant.name>` pulls the relevant context — past transcripts, open commitments, related projects — into a tight document `<user.name>` reads in 60 seconds before the meeting starts.

This folder is the sibling of `meetings/` (which holds raw transcripts) by design — synthesis next to source.

## What belongs here

- ✓ `/meeting-prep <meeting-name>` outputs (when that skill ships)
- ✓ Manual pre-meeting notes you wrote yourself
- ✓ Meeting-specific research dumps (compiled by `<assistant.name>` on request)

## What doesn't belong here

- ✗ Post-meeting recaps → those go in the relevant project's `memory.md`, or in `briefings/` if cross-cutting
- ✗ Raw transcripts → `meetings/`
- ✗ Per-person standing context → `contacts/<slug>.md`
- ✗ Project-specific docs → `<workspace.root>/1-Projects/<slug>/`

## Naming convention

```
meeting-prep/
└── YYYY-MM-DD-<meeting-name>.md
```

Date prefix is **the meeting date**, not when the prep was written. That way the file naturally lives near the corresponding transcript in `meetings/YYYY-MM-DD-<meeting-name>-*.md`.

## How `<assistant.name>` uses this folder

- **`/meeting-prep <meeting>`** (planned) — writes here. Composes from:
  - The relevant `contacts/<slug>.md` files (attendees)
  - Past transcripts in `meetings/` for the same recurring meeting
  - Active projects relevant to the meeting topic (via `/find`)
  - Open commitments from `contacts/<slug>.md` "Open commitments" sections
- **`/briefing`** — may reference upcoming meeting-prep docs in its "Calendar at a glance" section ("you have prep for the 2pm sync — read it now")
- **`/find <topic>`** — searches meeting-prep for past briefs on the same topic

## Brief structure (what's inside each file)

When `/meeting-prep` ships, each brief will follow a stable shape:

1. `# Meeting prep — <meeting-name> — YYYY-MM-DD` (H1)
2. `## Attendees` — names, roles, link to `contacts/<slug>.md` per attendee
3. `## What was discussed last time` — pulled from prior transcripts for recurring meetings
4. `## What you (or they) promised` — open commitments from contact files, scoped to attendees
5. `## Related active projects` — relevant `1-Projects/<slug>/` with one-line status
6. `## Suggested agenda items` — opinionated; what `<assistant.name>` thinks should be raised
7. `## Open questions` — things `<user.name>` should resolve in the meeting
8. `## Tools used` — transparency footer

## Lifecycle

1. **Generate** — `/meeting-prep <meeting>` is invoked before the meeting (manually, or scheduled via a hook)
2. **Read** — `<user.name>` skims the prep right before the meeting
3. **Annotate** — optionally add notes to the prep file during/after the meeting
4. **Reference** — the prep doc may be linked from the post-meeting decisions in `1-Projects/<slug>/memory.md`

## Tips

- **Don't over-prep.** A 60-second-read brief beats a 5-minute-read brief. If the prep is bloated, `<user.name>` won't read it.
- **Lean on commitments.** The single most useful section is "what you (or they) promised" — it's what tracking commitments obsessively (SOUL.md) buys you.
- **Cross-link from the brief.** The pre-meeting brief should link to relevant prior transcripts in `meetings/`. Don't reproduce content; reference it.

## Status

The `/meeting-prep` skill is **planned** (Pass 3 of the second-brain redesign, after `/briefing`'s generalization pattern is proven). Until it ships, this folder is empty by design — drop manual prep notes here following the naming convention if you want to start building the habit before the skill exists.
