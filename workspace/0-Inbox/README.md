# 0-Inbox

The capture zone. Drop anything you're not sure about here — `<assistant.name>` triages it later.

## Purpose

`0-Inbox/` exists because **deciding where something belongs is a separate task from capturing it.** If you stop to figure out "is this a project or a research note or junk?" every time you have a half-formed thought, you'll stop capturing. The Inbox absorbs uncertainty so the rest of the workspace stays clean.

This implements the "Capture before commit" operating principle in `SOUL.md`. Things in `0-Inbox/` haven't earned a `1-Projects/` scaffold yet — they're in the holding pattern until you (or `<assistant.name>`) decide.

## What belongs here

- ✓ A half-formed idea you might develop later ("AI agent for X — explore this")
- ✓ A link you want to read but haven't yet
- ✓ A meeting note that doesn't fit any active project
- ✓ A generated artifact (deck, dashboard, report) without a project owner yet
- ✓ A screenshot or file someone sent you that needs filing
- ✓ "I might want to start a project on Y but I'm not sure yet"

## What doesn't belong here

- ✗ Active project work → `1-Projects/<slug>/` (with proper scaffold)
- ✗ Reference docs you'll re-read → `3-Resources/reference/`
- ✗ Research notes with a clear topic → `3-Resources/research/`
- ✗ Meeting transcripts → `3-Resources/meetings/`
- ✗ Code repos → `2-Coding/<scope>/<name>/`
- ✗ Anything finished → `4-Archive/`

## How `<assistant.name>` uses this folder

- **`/inbox-process`** — Friday triage routine. Walks each item, asks "promote to 1-Projects, file in 3-Resources, archive, or delete?" Empties the Inbox on a weekly cadence.
- **`/new-project`** Step 0 — if `<user.name>` asks to start a project but the topic is vague or exploratory, `/new-project` may suggest capturing to Inbox first rather than scaffolding prematurely.
- **`/find <topic>`** — checks Inbox as part of its search scope. If you captured something here weeks ago about a topic you're now returning to, `/find` surfaces it.

## Capture patterns

The default is a single markdown file: `<workspace.root>/0-Inbox/<slug>.md`. For richer captures, use a folder: `<workspace.root>/0-Inbox/<slug>/` with whatever files inside.

You don't need frontmatter, you don't need structure — Inbox items are deliberately low-ceremony. The whole point is to lower the activation energy for capture.

Examples:
```
0-Inbox/
├── ai-agent-for-customer-support.md       # half-formed idea, one paragraph
├── arxiv-paper-on-retrieval.md            # link + a few notes
├── q4-pricing-page-mockup/                # folder with screenshots + brief
│   ├── mockup.png
│   └── notes.md
└── slack-thread-about-launch-strategy.md  # pasted Slack thread, needs filing
```

## Lifecycle

1. **Capture** — drop the thing in, with whatever name/structure feels right
2. **Wait** — don't decide today; come back on Friday
3. **Triage** — `/inbox-process` walks each item; you decide where it goes
4. **Empty** — Inbox should be near-empty after each triage (target: < 5 items)

## Tips

- **Don't over-think the filename.** `random-thought-about-x.md` is fine. You'll rename or move it during triage.
- **Inbox is NOT a long-term archive.** If something has been sitting here for 30+ days untriaged, it's probably not actually important. `/inbox-process` will surface this.
- **If you find yourself adding structure** (frontmatter, sub-folders, careful filenames), the item is mature enough to be a `1-Projects/` scaffold or `3-Resources/` reference. Promote it now, don't keep polishing it in Inbox.

## Boundary

`<assistant.name>` does NOT auto-process the Inbox. Items only move when `<user.name>` invokes `/inbox-process` (or manually moves them). This is intentional — auto-triage would make filing decisions on `<user.name>`'s behalf, which is too high-stakes for unattended automation.
