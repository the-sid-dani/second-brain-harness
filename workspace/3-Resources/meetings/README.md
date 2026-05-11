# meetings

Meeting transcripts and summaries — the raw input that other skills (`/briefing`, `/meeting-prep`) read to ground their work in what was actually said.

## Purpose

Memory is fragile. A transcript or AI-generated summary captures the actual exchange so `<assistant.name>` can cross-reference what was said weeks later. This folder holds the **raw inputs** — synthesis (briefings, prep docs) lives next door at `briefings/` and `meeting-prep/`.

## What belongs here

- ✓ Tactiq full-text transcripts (downloaded from the Tactiq folder in Drive)
- ✓ Gemini AI-generated meeting summaries (downloaded from Google Meet recordings)
- ✓ Manual notes from a meeting (your own jot during/after)
- ✓ Slack thread exports from a structured conversation that functioned as a meeting

## What doesn't belong here

- ✗ Pre-meeting prep → `meeting-prep/` (next door)
- ✗ Post-meeting briefings → `briefings/`
- ✗ Action items extracted from a meeting that became a project → into that project's `memory.md`
- ✗ A contact's interaction log → `contacts/<slug>.md` `## Interaction log` section

## Naming convention

```
meetings/
├── YYYY-MM-DD-<meeting-name>-tactiq.md            # full transcript
├── YYYY-MM-DD-<meeting-name>-gemini.md            # AI summary (Google Meet)
└── YYYY-MM-DD-<meeting-name>-notes.md             # your own notes
```

The suffix (`-tactiq` / `-gemini` / `-notes`) signals the source, which matters because Gemini summaries are pre-condensed (faster to skim, but less detail) while Tactiq transcripts are verbatim (more detail, slower to read).

## How `<assistant.name>` uses this folder

- **`/briefing`** — optionally cross-references `meetings/` for the "Notes & cross-references" section when today's calendar mentions topics with prior transcripts
- **`/meeting-prep <meeting>`** (planned) — reads relevant past transcripts for the same recurring meeting, surfaces "what was discussed last time," "what you promised," "follow-ups"
- **`/find <topic>`** — searches transcripts for prior mentions; the chief-of-staff value of "what did we decide about X two months ago?" lives here
- **`/contact-log`** (manual mode) — when you log an interaction with someone, you may reference a transcript in this folder for context

## Source priority (when both exist)

If both a Gemini summary AND a Tactiq transcript exist for the same meeting, **prefer the Gemini summary for skimming** and **drop into the Tactiq transcript only when you need verbatim detail**. Gemini extracts action items and decisions automatically; Tactiq is the source of truth for "did so-and-so actually say X."

`/meeting-prep` follows this rule by default — Gemini first, fall back to Tactiq if no summary exists.

## Where to download from

The Configuration section in root `CLAUDE.md` may have your organization's Drive folder IDs for meeting transcripts and recordings. See `CLAUDE.md` for the canonical IDs.

For Samba employees: Tactiq transcripts and Gemini recordings are in fixed Drive folders documented in TOOLS.md.

For other organizations: download manually from your meeting tool (Otter, Fireflies, Riverside, etc.) and drop the file here following the naming convention.

## Lifecycle

1. **Capture** — drop the transcript here right after the meeting (or on a weekly batch sync from Drive)
2. **Reference** — `<assistant.name>` reads it as part of `/briefing`, `/meeting-prep`, `/find`
3. **Extract** — if a meeting produced action items or decisions that belong to an active project, append them to that project's `memory.md`
4. **Retain** — transcripts stay here indefinitely; they're searchable history. Don't delete

## Privacy note

Meeting transcripts often contain confidential business information (compensation, customer names, internal strategy, personnel matters). This folder is git-tracked — be deliberate about what you commit. If a transcript contains material that shouldn't live in version control, redact or summarize before saving here, OR add a `.gitignore` entry for that file.

## Tips

- **Batch your downloads.** Pulling transcripts one at a time is friction. Pick a weekly cadence (Friday afternoon) and bulk-sync the past week's transcripts from Drive.
- **Don't rewrite transcripts.** If a transcript misspells a name or attributes a quote to the wrong person, leave it — that's how the tool captured it. Add corrections as a separate `<meeting-name>-notes.md` file alongside.
- **Cross-link transcripts from project memory.** When a decision in `1-Projects/<slug>/memory.md` came out of a specific meeting, link to the transcript: `Decision came from [[meetings/2026-10-15-pricing-sync-tactiq]]`. `/find` will trace these links later.
