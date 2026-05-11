---
name: contact-log
description: Write-mode skill — append a new interaction entry to a matched contact's `## Interaction log` section in `<workspace.root>/<workspace.resources>/contacts/<slug>.md` and auto-bump the `last_interaction` frontmatter to today's date. Append-only via Edit (never Write — preserves prior entries + About / Recurring topics / Open commitments sections). Reuses `/contact`'s fuzzy-match priority order. Use when <user.name> wants to record an interaction — phrases like "/contact-log <name>", "log my meeting with X", "just talked to <name>", "record my call with X". Mutation, single-source, and no-fabrication invariants live in SKILL.md body.
allowed-tools: Read Edit Bash AskUserQuestion Skill
---

# contact-log

Write-mode entity-keyed mutation. Append a new interaction entry to a matched contact's `## Interaction log` section, auto-bump `last_interaction` frontmatter. Append-only — never rewrites prior entries, never touches About / Recurring topics / Open commitments.

**Before you begin: read the Configuration section in root CLAUDE.md.** Path tokens like `<workspace.resources>` resolve from there — don't hardcode.

## Why this exists

Without `/contact-log`, a contact file is a static address book — populated once, then frozen. The Chief-of-Staff function (track who said what when) needs interaction history to compound. Each conversation adds a line; over months that line-set becomes the answer to "what did I promise <name> last time?" and "when did we last sync?"

`/contact-log` is the write counterpart to `/contact` (read). Together they make the contacts directory **alive** — entity-keyed read AND entity-keyed append, with the locked schema preserved across both.

The schema (frontmatter fields, body sections, WikiLinks pattern, status enum) is defined in `<workspace.root>/<workspace.resources>/contacts/README.md` — read that first if you need schema details. This skill references the schema; it does not reproduce it.

## When to use

Trigger phrases (write-mode signals — broad on purpose):

- "/contact-log <name>" / "/contact-log"
- "log my 1:1 with <name>" / "log my meeting with <name>" / "log my call with <name>"
- "append interaction with <name>" / "record my chat with <name>"
- "I just talked to <name>" / "just spoke with <name>, log it" / "had a sync with <name>"
- "wrote/promised/agreed with <name> — log it"

The verb is the signal. Read-mode verbs ("who is", "what's my context with", "remind me about", "tell me about") fire `/contact` instead. Mutation verbs ("log", "append", "record", "talked-to", "spoke with") fire this skill.

Do NOT trigger for:
- Read-only recall of a person — that's `/contact`. Phrases like "who is X again?", "context on Y".
- Scaffolding a brand-new contact (no file exists yet) — that's `/contact-add` (planned, Pass 4 #35).
- Updating a frontmatter field other than `last_interaction` (e.g., correcting a role, changing status) — that's `/contact-update` (planned, Pass 4 #36).
- Writing to the daily log — `/contact-log` does NOT touch `memory/YYYY-MM-DD.md`. <user.name> writes the day's narrative to memory/ separately.

## Mutation invariants (load-bearing — DO NOT VIOLATE)

These are the premortem T2 + E1 mitigations baked into the skill spec. Violating any of them is a regression.

- **Use `Edit` for the append. NEVER `Write`.** `Write` replaces the entire file content and would destroy prior interaction entries, About blurbs, Recurring topics, and Open commitments. This skill performs **two** `Edit` calls per invocation: one for the `last_interaction` frontmatter bump, one for the new `### YYYY-MM-DD — <topic>` block insertion.
- **Stable insertion anchor.** Insert the new entry directly **below the `## Interaction log` heading** (so newest-first, easy to scan), or **after the last existing log entry** (so chronological, append-only). Pick whichever produces a more reliable Edit `old_string` on the actual file content. Default convention: **insert immediately under `## Interaction log` heading** so the most recent entry surfaces first when `/contact` reads.
- **Only `last_interaction` mutates in frontmatter.** Every other field — `name`, `email`, `role`, `team`, `company`, `relationship`, `status`, `first_logged`, `legal_name`, `reports_to`, `recurring_cadence`, `tags`, `slack_handle`, `timezone`, `linkedin`, `location`, `department`, `division`, `work_phone` — stays byte-identical. If the user wants to update a non-`last_interaction` field, refer them to `/contact-update` (planned).
- **Body sections About / Recurring topics / Open commitments are READ-ONLY here.** Do not regenerate them. Do not "improve" them. Do not summarize prior interactions into them. Their content is byte-identical post-write.
- **Prior `## Interaction log` entries are READ-ONLY.** Don't merge, don't summarize, don't reformat. The new entry is purely additive.
- **Schema-violation guard.** If the contact file has no `## Interaction log` heading, abort with an error. Do NOT auto-create the section — that's a schema decision <user.name> should make explicitly. Suggest fixing the file or running `/contact-update` (planned) to repair the schema.

## Single-source rule (no daily-log write)

Per premortem E1: this skill writes **ONLY** to the contact file at `<workspace.root>/<workspace.resources>/contacts/<slug>.md`. It does **NOT** also append to `memory/YYYY-MM-DD.md`.

- Daily log = the day's narrative, written by <user.name> (and, with permission, by <assistant.name>).
- Contact file = the per-person interaction journal, mutated only by this skill (and `/contact-add`, `/contact-update` when those ship).
- WikiLinks (`[[contacts/<slug>]]`) cross-reference between them so `/find` traces the relationship graph. If <user.name> wants today's daily log to mention the interaction, they write that themselves — don't auto-mirror it from here.

This decision is locked. If a future skill needs both surfaces written together, it composes both — but the primitive each surface uses stays single-target.

## Process

### Step 1: Match the name

Extract the name from the invocation. Examples:
- `/contact-log omar` → query = `omar`
- `log my 1:1 with omar` → query = `omar`
- `just talked to michela, log it` → query = `michela`
- `/contact-log` (no name) → ask in plain chat: *"Which contact should I log against?"*

Compose `/contact <query>` to identify the target — reuse the locked priority order from `<workspace.root>/.claude/skills/contact/SKILL.md` Step 3 (exact slug > slug-stem-match > `name` token-level > `legal_name` token-level > prefix > substring; substring against `legal_name` is intentionally excluded). Don't reimplement the algorithm here; compose.

Outcomes:
- **Single match** → continue to Step 2 with the matched slug + file path.
- **Multi-match** → use `AskUserQuestion` (multiSelect: false) with one option per candidate, labeled `<name> — <role>, <team> · <relationship>`. Once <user.name> picks, continue to Step 2 with the chosen slug.
- **No match** → abort gracefully:
  ```
  No contact named "<query>" in <workspace.root>/<workspace.resources>/contacts/.

  Options:
  - Add them: /contact-add <query>   (coming soon — Pass 4 #35)
  - Check spelling: ls <workspace.root>/<workspace.resources>/contacts/
  ```
  Do NOT create a new file. Do NOT fabricate a profile. Stop.

### Step 2: Collect the interaction details

Use `AskUserQuestion` for the topic, then plain chat for the body — the topic is short enough for a structured prompt, but the body needs free-form prose that doesn't fit `AskUserQuestion`'s multi-choice shape.

Topic prompt (`AskUserQuestion`, free-text via "Other" if needed, or skip and ask in plain chat):

```
What was the interaction? One-line summary — becomes the entry heading.
e.g., "weekly sync", "1:1 catchup", "MCP architecture review", "quick chat re: Q3 planning"
```

Body prompt (plain chat, after topic):

```
Any decisions, commitments, or notes? Bullet form is fine. If nothing memorable, just say "quick chat" or "nothing material".
```

**No-fabrication invariant.** If <user.name> says "nothing happened" / "just a quick chat" / "no notes" — accept it. Write a minimal entry with just the topic heading and a body line like `- (no specific decisions or commitments)`. Don't invent specifics, don't extrapolate from `recurring_topics`, don't synthesize from prior log entries. **Sparse input → sparse entry.**

If <user.name> declines to provide a topic at all (cancels or returns empty), abort cleanly: *"Nothing logged. Run /contact-log again when you're ready."*

### Step 3: Read the contact file

```
Read tool on <workspace.root>/<workspace.resources>/contacts/<slug>.md
```

Verify the file has a `## Interaction log` heading (literal exact match — case-sensitive, no trailing whitespace difference). If missing, abort:

```
Schema violation: <slug>.md has no `## Interaction log` section.
Per <workspace.root>/<workspace.resources>/contacts/README.md, this is a required body section.
Fix the file's schema first (add `## Interaction log` heading), then re-run /contact-log.
```

Do NOT auto-create the section — that's a schema decision the user must make explicitly.

### Step 4: Compose the new entry

Today's date in `YYYY-MM-DD` format. Format:

```
### YYYY-MM-DD — <topic from Step 2>
<body from Step 2, formatted as bullets — one bullet per line, prefixed with "- ">
```

Example minimal entry (sparse input):

```
### 2026-05-06 — quick catchup
- (no specific decisions or commitments)
```

Example normal entry:

```
### 2026-05-06 — weekly sync
- Topic: MCP architecture, AI Task Force roadmap
- Decisions: agreed on per-server auth pattern
- <user.name> promised: share admin API doc by 2026-05-10
- <name> promised: PR review by next Friday
```

The format mirrors `<workspace.root>/<workspace.resources>/contacts/README.md`'s schema example. Use bullets, not prose paragraphs — `/contact` parses bullets when surfacing recent interactions.

### Step 5: Insert via Edit (NOT Write) — two operations

**Edit #1: Bump `last_interaction` frontmatter.**

```
Edit tool with:
  old_string: "last_interaction: <current-value>"
  new_string: "last_interaction: <today YYYY-MM-DD>"
```

The current value comes from the file Read in Step 3. It might be `unknown` (for never-logged-before) or a prior date like `2026-05-04`. Use the literal current value as `old_string` so the Edit is unambiguous.

**Edit #2: Insert new entry under `## Interaction log` heading.**

The cleanest anchor is the literal `## Interaction log` heading line plus the line immediately following it (whatever that is — a blank line, a placeholder like `*(directory-enriched ... Real interaction history begins on next /contact-log call.)*`, or an existing `### YYYY-MM-DD — ...` entry).

```
Edit tool with:
  old_string: "## Interaction log\n\n<next-line-verbatim>"
  new_string: "## Interaction log\n\n<new-entry-block>\n\n<next-line-verbatim>"
```

Where `<new-entry-block>` is the composed entry from Step 4. This inserts the new entry directly below the heading, pushing the prior next-line down — newest-first ordering.

**If either Edit fails** (e.g., file changed between Read and Edit, anchor not found, ambiguous match), abort and report the error verbatim. **Never fall back to `Write`.** A failed Edit is a signal that the file isn't in the state we expected — re-prompting <user.name> is correct, silently overwriting is not.

### Step 6: Verify and report

Read the file again briefly (Read tool) to confirm:
1. `last_interaction:` is now today's date.
2. The new `### YYYY-MM-DD — <topic>` block is present under `## Interaction log`.
3. Prior entries (if any) are still present unchanged.

Then report to <user.name>:

```
Logged interaction with <name> at <workspace.root>/<workspace.resources>/contacts/<slug>.md.
  Entry:           ### <YYYY-MM-DD> — <topic>
  last_interaction: bumped to <YYYY-MM-DD>
```

Stop. Do not auto-update any index file (no INDEX exists for contacts). Do not auto-commit. Do not write to `memory/YYYY-MM-DD.md` (single-source rule). Do not propose unrelated next actions.

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| No contact found by name | Typo, contact not yet scaffolded | Graceful no-match message; suggest `/contact-add` (planned). No file mutation. |
| Multi-match (2+ candidates) | Query is ambiguous | `AskUserQuestion` disambiguation per Step 1. If `AskUserQuestion` unavailable (subagent context), list candidates inline and stop — caller re-invokes with a more specific query. |
| Contact file lacks `## Interaction log` section | Schema violation (manual edit broke convention, or pre-schema legacy file) | Abort with schema-violation error. Do NOT auto-create. Suggest fixing the file or running `/contact-update` (planned). |
| User declines topic / cancels mid-flow | Changed mind, distraction | Abort cleanly: *"Nothing logged. Run /contact-log again when ready."* No mutation. |
| User gives sparse input ("nothing happened") | Genuinely uneventful interaction | Accept. Write minimal entry with topic + `- (no specific decisions or commitments)`. **Never fabricate specifics.** |
| Edit #1 (frontmatter) fails | `last_interaction:` line format unexpected (e.g., trailing inline comment, weird whitespace) | Abort, report error. Do NOT fall back to `Write`. Surface the literal `old_string` mismatch so user can fix the file. |
| Edit #2 (body insertion) fails | `## Interaction log` heading text doesn't match expected, or the line after it is non-deterministic | Abort, report error. Do NOT fall back to `Write`. Re-Read and try a tighter anchor (e.g., heading + 2 lines), or surface the issue. |
| File modified between Read and Edit | Concurrent edit, git pull, etc. | Edit's built-in safety catches this — surface the error and re-prompt the user to re-run. |
| `AskUserQuestion` not available (subagent context) | Worker subagent runs lack the tool | Pre-extract topic + body from the invocation prompt if possible (e.g., `log my 1:1 with omar — discussed MCP, agreed on auth pattern`). If extraction fails, abort cleanly — do not invent. |
| User invokes on a `status: personal` or `status: family` contact | Logging interaction with a friend | Works normally. No special handling. The status field doesn't gate `/contact-log`. |
| Configuration values missing | Fresh fork without `/bootstrap` run | Error: *"Configuration section in root CLAUDE.md not populated. Run `/bootstrap` (TBD) or fill it in manually first."* |

## Boundary

This skill is **write-only and narrowly scoped**. It MUST NOT:

- Modify any file other than the matched contact file.
- Modify any frontmatter field other than `last_interaction`. (Use `/contact-update` for those — planned.)
- Modify the body sections About / Recurring topics / Open commitments. (Those are not in this skill's mutation surface.)
- Rewrite, merge, summarize, or reformat prior `## Interaction log` entries.
- Auto-create a missing `## Interaction log` section. (Schema violation → abort.)
- Write to `memory/YYYY-MM-DD.md` (the daily log). (Per single-source rule.)
- Scaffold a brand-new contact file. (Use `/contact-add` — planned.)
- Use the `Write` tool to mutate the contact file. (Use `Edit` only.)

If <user.name> asks for any of the above during the same turn, complete the log-append action first, then suggest the appropriate skill — do not silently invoke it.

## Output format

**Successful append:**
```
Logged interaction with <name> at <workspace.root>/<workspace.resources>/contacts/<slug>.md.
  Entry:           ### <YYYY-MM-DD> — <topic>
  last_interaction: bumped to <YYYY-MM-DD>
```

**No match:**
```
No contact named "<query>" in <workspace.root>/<workspace.resources>/contacts/.

Options:
- Add them: /contact-add <query>   (coming soon — Pass 4 #35)
- Check spelling: ls <workspace.root>/<workspace.resources>/contacts/
```

**Schema violation (no `## Interaction log` section):**
```
Schema violation: <slug>.md has no `## Interaction log` section.
Per <workspace.root>/<workspace.resources>/contacts/README.md, this is a required body section.
Fix the file's schema first (add `## Interaction log` heading), then re-run /contact-log.
```

**Cancellation:**
```
Nothing logged. Run /contact-log again when you're ready.
```

These four formats are stable — Layer 3 skills (`/briefing`, `/meeting-prep`) and audit tooling will look for "Logged interaction with" lines in transcripts.
