# research

Topic-keyed research notes. Where ideas, analyses, and "I want to understand X better" exploration lives.

## Purpose

`research/` is for **content you'll come back to as input for future work**. Unlike `reference/` (which is durable lookup), research notes age — what was true about LLM pricing in 2024 isn't in 2026. Date-prefix everything so the snapshot's vintage is obvious.

## What belongs here

- ✓ "Survey of RAG patterns Q4 2026" — research dump
- ✓ "Notes on agentic workflows from <conference>" — conference takeaways
- ✓ "Analysis of LLM pricing trends" — market analysis
- ✓ "Patterns for building tool-use agents" — synthesis of multiple sources
- ✓ Reading notes from a book/paper you want to retain

## What doesn't belong here

- ✗ Active project work → `1-Projects/<slug>/research/` if project-scoped
- ✗ Random link you might read someday → `0-Inbox/`
- ✗ Durable reference doc (org chart, tool inventory) → `reference/`
- ✗ A finished research project that produced a deliverable → archive it to `4-Archive/`
- ✗ Meeting notes → `meetings/`

## Naming convention

```
research/
├── YYYY-MM-<topic-slug>.md             # standalone note
├── YYYY-MM-<topic-slug>/                # folder if you have multiple files
│   ├── notes.md
│   ├── sources.md
│   └── diagrams/
```

The date prefix is **when you wrote the research**, not when the content was true. A 2026-10 note about RAG patterns may still be useful in 2027, but you'll know it's a year old at a glance.

## How `<assistant.name>` uses this folder

- **`/find <topic>`** — searches across `research/` filenames + content; the most common reason to use `/find` is "what have I researched on X?"
- **`/save-resource`** — when `<user.name>` says "save this as a research note on X," routes here with the right naming convention
- **`/thinking-partner`** — when exploring a problem, may surface relevant past research via `/find` as part of clarifying questions
- **`/new-project`** Step 0 — searches research for related work before scaffolding; "you already researched X" → suggests reviving research rather than starting fresh

## Folder vs file

Default to a single `.md` file. Promote to a folder when:
- You have multiple sub-files (notes + extracted quotes + diagrams)
- The research informed a project and now has its own assets
- A single file is getting too long to navigate (>500 lines)

## How research differs from a project

A research note in `research/` is **input**. A research project in `1-Projects/` has a deliverable (a memo, a recommendation, a presentation) and a stakeholder. The promotion path is real: notes here can grow into a research project later via `/new-project` (which Step 0 will surface the existing notes and ask if you want to extend them).

## Tips

- **Write for your future self.** Add a 2-line "Why I cared about this" preamble. In 6 months, you won't remember what you were chasing.
- **Capture sources.** A research note without links to where the claims came from is a vibe note. Include citations.
- **Don't worry about perfect organization.** `/find` is good. Topic-based filenames + the date prefix get you 90% of the way. Don't build a taxonomy in your head; let `/find` traverse.
- **Archive when stale.** If a research note is 2+ years old and no longer informs anything, move it to `4-Archive/` (with the date prefix it's easy to tell). Provenance survives; current view stays clean.

## Maintenance

- **Date prefix is non-negotiable** — without it, you can't tell vintage
- **Title with the topic** — `2026-10-rag-patterns.md` not `2026-10-research-notes.md`. The filename is your index
- **One topic per file/folder** — if a note is sprawling across three topics, split it. `/find` is more useful when each result is narrowly scoped
