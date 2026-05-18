---
name: save-resource
description: Saves content into `<workspace.root>/<workspace.resources>/<type>/...` with the right convention per type — research → `YYYY-MM-<topic>-research/`, reference flat, meetings → `YYYY-MM-DD-<topic>.md`. Use whenever the user wants to file something into Resources — phrases like "save this to research", "file this in reference", "this is a meeting note", "promote this to resources", "save the X file in inbox to <type>", "/save-resource". Handles three sources: file path in invocation, Inbox candidate, or chat content. Trigger broadly on save/file/promote language for reference material.
allowed-tools: Read Write Bash AskUserQuestion
---

# save-resource

Workhorse for getting things into Resources. Input is a source (file or content) + type + topic; output is a file at the canonical destination per decision #16 in system-design.md §7.

**Before you begin: read the Configuration section in root CLAUDE.md.** Path tokens like `<workspace.resources>` resolve to whatever's defined there — don't hardcode.

## Why this exists

Resources is two-level (`<workspace.resources>/<type>/<content>`) and each type has a different convention — research uses `YYYY-MM-<topic>-research/` folders, reference is flat, meetings is `YYYY-MM-DD-<topic>.md`. Doing this by hand means the user has to remember which type uses which convention. The skill enforces it.

This also means Inbox doesn't graveyard. The Inbox→Resources flow has a one-step path (`/save-resource`) instead of "manually decide where it goes, mkdir if needed, mv it, hope you got the naming right". Without it, items pile up in 0-Inbox forever (research finding from §2 constraint #1).

The skill also accepts CHAT CONTENT as a source, not just paths. If the user pastes notes and says "save this to research/X", the skill writes a new file at the destination — no Inbox round-trip required.

## When to use

Trigger phrases (intentionally broad — over-trigger rather than miss):
- "save this to research" / "save this in reference" / "save this meeting note"
- "promote this to resources" / "this belongs in resources/<type>"
- "file this as <type>" / "save the X file in inbox to <type>"
- "save <thing> as a <type>" / "this is a meeting note for X"
- "/save-resource"

Do NOT trigger for:
- New project creation — that's `/new-project` (which has a `code-repo` branch for repos)
- Memory updates within an existing project — append directly to that project's `memory.md`
- Outputs <assistant.name> generates have dedicated subdirs inside Resources: briefings → `<workspace.resources>/briefings/`, meeting-prep → `<workspace.resources>/meeting-prep/`, organization-reports → `<workspace.resources>/organization-reports/`. `/save-resource` is for *user-supplied* reference material (links, articles, snippets) — those land in `<workspace.resources>/research/` or `<workspace.resources>/reference/`.

## Process

The skill is interactive. The interactive prompts only fire when the user runs the skill themselves; subagent runs invoke with answers pre-extracted.

### Step 1: Identify the source

Three cases, in order of how to detect:

1. **Path provided in invocation** — e.g., "save 0-Inbox/vendor-invoices-2025/ to reference" or "save the file at <path>". Extract the path. Verify it exists with `[ -e "$path" ]` before proceeding. Both files and folders are valid sources.

2. **Generic reference to inbox content** — e.g., "save the show-and-tell file in inbox to research". Run `ls <workspace.inbox>/` to find candidates. If exactly one item matches the user's hint substring, use it. If multiple match, ask via `AskUserQuestion` to disambiguate. If Inbox is empty, error: *"Inbox is empty — drop something in `<workspace.inbox>/` first."*

3. **Content in chat** — e.g., user pastes notes (or refers to "this content above"), says "save this to research/X". Treat the chat content as the source; the skill will `Write` it to the destination as a new file. Useful for chat-derived knowledge that never lived in Inbox.

If the source is unclear, ask in plain chat: *"What should I save? Path to a file/folder, or just paste the content here."*

### Step 2: Get the type

`AskUserQuestion` with these choices:

- `research` — multi-file research projects (date-prefixed topic folders)
- `reference` — flat reference docs (CSVs, employee directory, vendor lists)
- `meetings` — single date-prefixed file per meeting
- `other` — free-text custom subfolder (next chat message)

If the user already specified the type in the invocation ("save this **to research**"), extract and skip the question.

**Refuse `templates`** — that subfolder is system-managed (used by `/new-project`), not for user content. If the user says "save this template", redirect: *"`<workspace.resources>/templates/` is system-managed by `/new-project`. To add a new template, edit it manually there. If you want to save the file as reference docs instead, pick `reference`."*

### Step 3: Get the topic / filename

Branches by type:

**`research`:** ask in plain chat: *"What's the topic? I'll prefix it with YYYY-MM and add a `-research` suffix."* Slugify the answer (lowercase, hyphens, strip non-alphanum-hyphen). Today's date prefix: `date +%Y-%m`.
- Example: "Anthropic admin API capabilities" → `2026-05-anthropic-admin-api-capabilities-research`
- The folder name becomes the topic identifier; multiple files can live inside.

**`reference`:** if source is a file with a sensible name, use that name; else ask: *"What's the filename? (e.g., `vendor-list-2025.csv`, `employee-directory.csv`)"*. Preserve the file extension.

**`meetings`:** ask in plain chat: *"Who or what was the meeting about? I'll prefix with YYYY-MM-DD."* Construct `YYYY-MM-DD-<topic>.md`. If the source has a date in its name (e.g., `2026-04-30-show-and-tell.md`), use that date; else today's date.
- Example: "1on1 with Alex" on 2026-05-05 → `2026-05-05-alex-1on1.md`

**`other`:** ask for both the subfolder name AND filename: *"What's the subfolder name? (e.g., `writing-style`, `voice`, `team-handbook`)"*, then *"What's the filename?"*.

### Step 4: Compute the destination path

Use root CLAUDE.md's `<workspace.root>` and `<workspace.resources>` values. Resolve to a concrete path:

| Type | Resolved destination |
|------|----------------------|
| `research` | `<workspace.root>/<workspace.resources>/research/YYYY-MM-<topic>-research/<filename>` |
| `reference` | `<workspace.root>/<workspace.resources>/reference/<filename>` |
| `meetings` | `<workspace.root>/<workspace.resources>/meetings/YYYY-MM-DD-<topic>.md` |
| `other` | `<workspace.root>/<workspace.resources>/<custom-type>/<filename>` |

For research with multiple files at once (source is a folder, not a single file), the folder content goes inside the topic folder: e.g., `0-Inbox/vendor-invoices-2025/{a.pdf,b.pdf}` saved to research with topic "vendor-invoices" → `<resources>/research/2026-05-vendor-invoices-research/{a.pdf,b.pdf}`.

For reference with a folder source, the folder lands directly under `reference/`: `0-Inbox/vendor-invoices-2025/` → `<resources>/reference/vendor-invoices-2025/`. (Keep the original folder name for reference; it's already the natural identifier.)

### Step 5: Confirm

Print the plan and ask `AskUserQuestion` (yes/no):

```
Will save:
  Source: <path or "chat content">
  Type:   <type>
  Dest:   <resolved destination>

Proceed?
```

This is the bail-out point. If no, ask what to change (type, topic, filename) and retry from the relevant step.

### Step 6: Handle existing destination

Don't overwrite silently:

- **Research, topic folder already exists:** ask via `AskUserQuestion`: "*Topic folder already exists. Add to it (place the source inside the existing folder), or pick a different topic name?*". If "add to it", validate the specific filename doesn't already exist inside; if it does, ask "*overwrite, rename, or abort?*".

- **Reference / meetings / other, file already exists:** ask "*File already exists. Overwrite, rename (provide new name), or abort?*".

The default safe answer for these is "abort" — better to make the user choose explicitly than to overwrite.

### Step 7: Execute the move/write

For each case:

```bash
# Source is a file already on disk:
mkdir -p "<destination-parent>"          # ensures parent exists (esp. research's topic folder)
mv "<source-path>" "<destination-path>"  # atomic, preserves mtimes

# Source is a folder already on disk:
mkdir -p "<destination-parent>"
mv "<source-folder>" "<destination-folder>"

# Source is chat content (no path):
mkdir -p "<destination-parent>"
# Use Write tool to create the file with content
```

Use `mv` for files/folders already on disk (atomic, mtimes preserved — important since memory of when the user added something matters for context). Use the `Write` tool for chat content (the file didn't exist before).

### Step 8: Confirm to user

```
✅ Saved: <destination relative to workspace.root>
  Type:   <type>
  Source: <source>

Find it later: ls <workspace.root>/<workspace.resources>/<type>/
```

For research, also print the topic folder so the user can `cd` in:

```
Topic folder: <workspace.root>/<workspace.resources>/research/<YYYY-MM-topic-research>/
```

Stop. Don't auto-update any index file (no INDEX exists for Resources per decision #15), don't propose related actions, don't auto-commit.

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Source path doesn't exist | Typo, file already moved | Show `ls <workspace.inbox>/` and re-prompt |
| Inbox empty when user said "save inbox content" | Nothing to save | Tell the user, suggest dropping a file in first |
| Type is `templates` | Misunderstanding (templates are system-managed) | Helpful redirect — see Step 2 |
| Destination conflict (folder/file exists) | Same topic name reused, or same filename | Ask via `AskUserQuestion` — overwrite/rename/abort |
| Topic slugifies to empty | All special chars | Re-prompt: "*That topic didn't slugify cleanly — try one with letters/numbers*" |
| Configuration values missing | Fresh fork without `/bootstrap` run | Error: "*Configuration section in root CLAUDE.md not populated. Run `/bootstrap` (TBD) or fill it in manually first.*" |
| `mv` fails | Permissions, cross-device, etc. | Surface stderr, abort. Don't fall back to `cp+rm` (loses atomicity) |
| `AskUserQuestion` not available (subagent context) | Worker subagents lack the tool | Pre-extract answers from invocation prompt; skip every `AskUserQuestion` call |

## Output format

Final user-facing message after success:

**Reference / meetings / other (single file):**
```
✅ Saved: <workspace.resources>/<type>/<filename>
  Type:   <type>
  Source: <source>

Find it later: ls <workspace.root>/<workspace.resources>/<type>/
```

**Research (with topic folder):**
```
✅ Saved: <workspace.resources>/research/<YYYY-MM-topic-research>/<filename>
  Type:   research
  Topic:  <YYYY-MM-topic-research>
  Source: <source>

Topic folder: <workspace.root>/<workspace.resources>/research/<YYYY-MM-topic-research>/
Find it later: ls <workspace.root>/<workspace.resources>/research/
```

Use these formats consistently — `/inbox-process` (Pass 2f item 15b) and any future audit skill will look for "Saved:" lines in transcripts.
