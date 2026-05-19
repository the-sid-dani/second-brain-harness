---
name: end-of-day
description: End-of-day task reconciliation routine. Cross-references today's calendar events, meeting transcripts, sent emails, and (if Slack token live) Slack outbound messages against open Notion Action Items to PROPOSE done-candidates and surface new commitments not yet tracked. Never auto-marks done — always returns a proposed batch for <user.name> to confirm. Runs nightly via cron OR on demand via `/end-of-day`. Use when <user.name> says "end of day", "wrap up", "what did I get done today", or when the cron fires. Closes the gap where due-today-only filters miss done work on overdue items and untracked tasks.
allowed-tools: Read Write Bash Skill
---

# end-of-day

Nightly reconciliation between **what happened** (calendar/transcripts/email/slack) and **what Notion thinks is still open**. Closes the loop where:
- Overdue items get done same-day but stay flagged "overdue"
- Tasks with no due date never surface in `today` views
- Commitments from meeting transcripts never make it into Notion at all

This is read-mostly. The only mutation is appending to `memory/YYYY-MM-DD.md`. Marking tasks done is **never automatic** — the routine always returns a proposed batch for <user.name> to confirm via `/todo done`.

## Why this exists

A 2026-05-18 session surfaced the problem: morning report said 4 tasks done when 8 had been done. The 4 missed had patterns the today-filter couldn't see:
- A task with no due date set
- A task done in person at a calendared meeting, no outbound message to detect
- An overdue task from yesterday, completed today
- An administrative cleanup task

The signal for "done" isn't just outbound messages — it's **engagement with the right person on the right surface during the right window**. This routine triangulates all of those.

## When to use

Trigger phrases:
- `/end-of-day` / `/eod`
- "wrap up the day" / "end of day reconciliation"
- "what did I get done today?"
- Cron-driven invocation (8:43pm weekdays — see Setup section)

Do NOT trigger for:
- A specific task mark-done — that's `/todo done "..."`
- Morning orientation — that's `/briefing`
- Mid-day check — the session-start hook already loads task state

## Source of truth

- **Open tasks** — `$NOTION_ACTION_ITEMS_DS` queried for status NOT IN (Done, Archived)
- **Today's calendar** — `gws calendar +agenda --today --format json`
- **Today's transcripts** — Tactiq folder + Gemini folder (IDs in root CLAUDE.md / USER.md) filtered to today's modifiedTime
- **Sent emails** — `gws gmail messages list q="from:me newer_than:1d"`
- **Slack outbound** — `from:<@your_user_id> after:<today>` via Slack MCP (if token live; degrade gracefully if not)
- **Journal sink** — `memory/YYYY-MM-DD.md` (append-only per root CLAUDE.md)

## Tiger invariants

### T1 — Never auto-mark Notion tasks done
This routine ONLY proposes. Always returns a batch like "Candidates to mark done: [list]" and asks <user.name> to confirm. Same protection as `/todo done` (one task, fuzzy match, disambiguation gate) — but at routine scale, the risk of mass-incorrect marking is higher, so the gate is explicit confirmation, not a confidence threshold.

### T2 — Never fabricate engagement
If a transcript doesn't mention person X, don't claim "engaged with X today". If Slack token expired, say "Slack signal unavailable — re-auth needed" rather than guessing. Same as `/briefing` T3.

### T3 — Append-only to memory
`memory/YYYY-MM-DD.md` is append-only per CLAUDE.md "Memory writes are append-only" boundary. Add an end-of-day entry below any existing entries for the date — never rewrite, never delete.

### T4 — Degrade gracefully on missing signals
If Slack token expired → skip Slack section, note in output. If `gws` auth dead → skip Gmail/Calendar/Drive, note. The routine has a mandatory floor: read Notion + write to memory, with whatever signals are available.

## Process

### Step 0: Environment + tool probe

```bash
source ~/.second-brain-os.env
source "$CLAUDE_PROJECT_DIR/.claude/skills/todo/lib/ntn.sh"
todo_check_env || { echo "Notion env missing"; exit 1; }

has_gws=$(command -v gws >/dev/null && echo true || echo false)
today=$(date +%Y-%m-%d)
```

### Step 1: Pull open Notion tasks

Query for: status NOT IN (Done, Archived). Get title, due date, priority, LNO, and engagement hints (who's named in the title).

```bash
filter='{"and":[
  {"property":"Kanban Status","status":{"does_not_equal":"Done"}},
  {"property":"Kanban Status","status":{"does_not_equal":"Archived"}}
]}'
ntn api /v1/data_sources/$NOTION_ACTION_ITEMS_DS/query \
  -d "{\"page_size\":100,\"filter\":$filter}" > /tmp/eod_open_tasks.json
```

Parse out: id, title, due_date, priority, lno_category. Extract person names from titles (capitalized first names).

### Step 2: Pull today's engagement signals

#### 2a. Calendar (with participants)

```bash
gws calendar +agenda --today --format json 2>/dev/null | grep -v keyring | \
  jq -r '.[] | "\(.start) | \(.summary) | \(.attendees // [] | map(.email) | join(","))"'
```

Extract: meeting summaries (for project/topic match) + attendee email local-parts → first names.

#### 2b. Today's transcripts

```bash
gws drive files list --params '{"q":"('"'"'<TACTIQ_FOLDER_ID>'"'"' in parents or '"'"'<GEMINI_FOLDER_ID>'"'"' in parents) and trashed=false and modifiedTime > '"'"'TODAY_ISO'"'"'","orderBy":"modifiedTime desc","pageSize":30,"fields":"files(id,name,modifiedTime)"}' --format json
```

Replace folder IDs from root CLAUDE.md / USER.md. Replace `TODAY_ISO` with `${today}T00:00:00Z`. Filenames often match meeting titles. Generic "Meeting Transcription" names need to be cross-referenced by modifiedTime against calendar slots.

#### 2c. Sent emails

```bash
gws gmail messages list --params '{"q":"from:me newer_than:1d","maxResults":30}' --format json 2>/dev/null | \
  grep -v keyring | jq -r '.messages[]?.id' | while read id; do
    gws gmail messages get --params "{\"id\":\"$id\",\"format\":\"metadata\",\"metadataHeaders\":[\"To\",\"Subject\",\"Date\"]}" \
      --format json 2>/dev/null | grep -v keyring | jq -r '.payload.headers | map({(.name):.value})|add'
  done
```

#### 2d. Slack outbound (best-effort)

Call `mcp__slack__slack_search_public_and_private` with query `from:<@your_user_id> after:<today>`. If token expired error → note the gap in output and continue.

### Step 3: Cross-reference — propose done-candidates

For each open task, score engagement:

| Signal | Score | Notes |
|---|---|---|
| Person named in task title appeared as calendar attendee today | +3 | Strong: in-person/video interaction |
| Person named appeared in transcript participants today | +3 | Strong: confirmed meeting happened |
| Email sent today TO person named in task | +4 | Very strong: outbound action |
| Slack DM to person named today (if signal available) | +4 | Very strong |
| Task title keyword matches today's calendar event title | +2 | Medium: e.g., "Sacramento" task + "Exec Offsite" meeting |
| Task is administrative cleanup (no person, no surface) | +0 | Excluded — needs different verification |
| Slack token expired AND task is "Reply to X via Slack" | UNKNOWN | Flag as unverifiable |

**Threshold for proposing done**: score ≥ 3. Tasks scoring 1-2 surface as "possibly done — please confirm". Tasks scoring 0 stay open without comment.

### Step 4: Surface new commitments from transcripts

Read today's named transcripts (skip generic "Meeting Transcription" files unless they map to a calendar slot). Look for:
- "I'll..." / "let me ping..." / "I'll get back to you..."
- Names + dates ("by Friday", "next week", "before the offsite")
- Action items called out by Gemini summaries (in `Notes by Gemini` files)

For each, propose a NEW `/todo add` invocation — never auto-create.

### Step 5: Write the day's journal

Append to `memory/YYYY-MM-DD.md` (per root CLAUDE.md append-only rule):

```markdown
## End-of-day reconciliation — <time>

**Done today** (per cross-reference):
- [task title] — evidence: <calendar event / transcript / email>

**Proposed done — awaiting confirmation:**
- [task title] — score 3, signal: <what>

**New commitments surfaced from transcripts:**
- [proposed task] — source: <transcript filename>, exact quote: "<...>"

**Still genuinely open:**
- <count> 1st Priority Leverage tasks
- <count> Slack reply cluster (verifiability gap if token expired)

**Signal availability:**
- Calendar / Transcripts / Gmail Sent / Slack — present or absent
```

### Step 6: Return the proposal to user

Print a concise summary to the conversation (not just the journal file):

```
End-of-day reconciliation — <today>

Confirmed done (N): [list]
Proposed done — confirm? (M): [list]
New commitments to track (K): [list]
Still open (J): [count by priority]
Signal gaps: [Slack expired / etc.]

Say "yes mark done" + numbers to close. Say "yes add" + numbers to create new tasks.
```

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Reports wrong count of done tasks | Today-only filter missed overdue completions or no-due-date tasks | Step 1 pulls ALL open (no date filter); engagement signals catch overdue done |
| Misses Slack replies | Slack token expired | Step 2d gracefully degrades; output flags the gap |
| Hallucinates engagement | Generic "Meeting Transcription" filenames matched by accident | Step 2b cross-references modifiedTime against calendar, only trust named transcripts |
| Writes to wrong date file | Time zone confusion (UTC vs local) | Use `date +%Y-%m-%d` (local) consistently |
| Duplicate journal entries | Cron fires twice or manual + cron same day | Step 5 appends with timestamp header — multiple entries OK |
| Auto-marks tasks done | T1 violation | Always end with explicit `Confirm with "yes mark done"` — never call `ntn api PATCH` from this skill directly |

## Setup — cron registration

The routine fires nightly via CronCreate. Per session limits, CronCreate is session-only and auto-expires after 7 days. For permanent scheduling, use macOS launchd (TBD launchd plist template).

In-session cron invocation:
```
CronCreate(cron="43 20 * * 1-5", durable=true, recurring=true, prompt="/end-of-day")
```

(8:43pm local, weekdays — picks an off-minute to avoid fleet alignment per CronCreate guidance.)

## Boundaries

- Never auto-mark tasks done (T1)
- Never fabricate engagement signals (T2)
- Never overwrite memory entries (T3)
- Never send anything outbound — read-only reconciliation
- Slack expired token is a graceful-degrade, not an error to escalate
- If user approves a batch of dones, execute via the existing `/todo done` per-task loop (one fuzzy match + disambiguation per task) — never bulk-PATCH

## Integration map

- `/briefing` (morning) reads memory's end-of-day entry from previous day to give "Yesterday you closed N tasks" context
- Session-start hook (`session-start-tasks.mjs`) does NOT call this — too heavy. Hook is just a Notion task dump; this is the full cross-reference.
- `/todo done` is called by user after this skill proposes — closed loop.
