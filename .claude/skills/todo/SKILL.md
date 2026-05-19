---
name: todo
description: Task tracking in <user.name>'s personal Notion Action Items [DB]. Read-mostly skill that surfaces today's/tomorrow's tasks, supports quick capture (add) and completion (done), and respects <user.name>'s PARA-aligned schema (1st-5th Priority, LNO Category, Kanban Status, Projects [DB] relation). Wraps the official `ntn` CLI + Notion HTTP API. Token + DS IDs auto-load from `~/.second-brain-os.env`. Use when <user.name> says "/todo", "what's on my list", "add a task", "mark done", "tasks today", "tasks tomorrow", "what should I ship", or any task-tracking intent. NEVER creates new databases, NEVER renames properties, NEVER deletes tasks (only marks Done/Archived). Reads from `<workspace.root>/Configuration` for assistant/user tokens; reads contacts directory for `status: personal` filtering when relevant.
allowed-tools: Read Write Glob Bash Skill AskUserQuestion
---

# todo

Quick-capture + scan layer over <user.name>'s existing **Action Items [DB]** in personal Notion. Built on the `ntn` CLI (v0.14.0+) and the Notion HTTP API. All ops respect <user.name>'s 51-property schema — no schema changes, no new databases.

**Before invoking anything:** confirm `~/.second-brain-os.env` is loaded (auto-loaded by `~/.zshrc`). If running from a fresh shell, `source ~/.second-brain-os.env` first.

## When to use

Trigger phrases (broad — task-tracking intent is the pattern):

- `/todo`, `/todo today`, `/todo tomorrow`, `/todo this-week`
- `/todo blast` — the "what should I ship right now" view
- `/todo add "..."` — quick capture
- `/todo done "..."` — mark Kanban Status = Done
- `/todo by-project <name>` — filter
- "what's on my list?" / "what do I need to do today?" / "show me my tasks"
- "add a task to ..." / "remind me to ..." (capture intent)
- "mark X as done" / "X is complete" (completion intent)

Do NOT trigger for:
- Schema changes to Action Items [DB] — always do that in Notion UI.
- Creating new databases — out of scope by design (decision: skill is read+light-write only).
- Deleting tasks — closest is mark Done or Archived.
- Bulk import — for migrations, use a one-off script, not this skill.

## Source of truth

- **Action Items [DB] data_source_id**: `$NOTION_ACTION_ITEMS_DS` (loaded from env)
- **Projects [DB] data_source_id**: `$NOTION_PROJECTS_DS`
- **Schema reference**: 51 properties. The ones this skill touches: `Action Items` (title), `Priority` (select), `Kanban Status` (status), `LNO Category` (select), `Due Date` (date), `Projects [DB]      ` (relation — note trailing spaces, preserve exactly).
- **Priority canonical values** (ascending): `1st Priority` → `2nd Priority` → `3rd Priority` → `4th Priority` → `5th Priority`. The skill maps `P0/P1/P2/P3` shortcuts to these.
- **LNO canonical values**: `Leverage` (high-value), `Neutral` (middle), `Overhead` (grunt). Per <user.name>'s memory — LNO is load-bearing for him.
- **Kanban Status**: `To-Do` (default for new tasks), `Next-Up`, `Future` (To-do group); `Active`, `Paused` (In progress); `Done`, `Archived` (Complete group).
- **Default new-task values**: status=`To-Do`, priority=`2nd Priority`, LNO=`Neutral`.

## Tiger invariants (load-bearing)

### T1 — Never create new databases or rename properties
This skill writes ONLY to existing Action Items [DB] rows. Never `POST /v1/databases`, never `PATCH /v1/data_sources/.../*` to alter schema. If a workflow seems to need new properties, surface to <user.name> and let him change in Notion UI.

### T2 — Property name exactness
`Projects [DB]      ` (with **6 trailing spaces**) is the canonical relation property name. Preserve byte-for-byte. Any other property name with weird whitespace from <user.name>'s Notion (e.g., ` Notes` with leading space, `Weekdays ` with trailing space, `Timeline ` with trailing space) must be quoted exactly. Don't "normalize" them.

### T3 — Never delete
Closest operation is `done` (status → `Done`) or `archive` (status → `Archived`). Trashing pages via `ntn pages trash` is reserved for explicit duplicate cleanup, never bulk and never auto-triggered.

### T4 — Never bulk-modify status
A `/todo done` call must target ONE specific task (fuzzy-matched, with disambiguation if multiple). Never "mark all P3 done" or similar — too easy to wipe out the wrong batch.

### T5 — Token discipline
The Notion API token is a secret. Source it from `~/.second-brain-os.env` only. Never echo it back to the user, never log it, never write it into any file the skill itself manages, never paste it into a public surface.

## Process

### Step 0: Environment check (every invocation)

```bash
source ~/.second-brain-os.env 2>/dev/null
source "$CLAUDE_PROJECT_DIR/.claude/skills/todo/lib/ntn.sh"
todo_check_env || exit 1
```

If `todo_check_env` fails, abort with a clear message — don't try to recover by prompting for tokens inline.

### Step 1: Parse the subcommand

The invocation looks like: `/todo <subcommand> [args]`. Subcommands:

| Subcommand | Args | Behavior |
|---|---|---|
| (none) or `today` | — | List tasks due today (status != Done/Archived), grouped by priority |
| `tomorrow` | — | List tasks due tomorrow |
| `this-week` | — | List tasks due in the next 7 days (today through today+7) |
| `blast` | — | The "ship right now" view: priority=1st, LNO=Leverage, due ≤ tomorrow |
| `overdue` | — | Tasks with Due Date < today AND status != Done |
| `add` | `"title"` + optional flags | Create a new task |
| `done` | `"<fuzzy title>"` | Mark Kanban Status = Done |
| `by-project` | `<project name fuzzy>` | List tasks linked to that project |
| `help` | — | Print usage |

### Step 2: Execute the subcommand

#### `today` / `tomorrow` / `this-week` / `overdue`

```bash
today=$(date +%Y-%m-%d)
case "$subcommand" in
  today)     todo_query_by_date equals "$today" ;;
  tomorrow)  todo_query_by_date equals "$(date -v+1d +%Y-%m-%d)" ;;
  this-week) todo_query_by_date between "$today" "$(date -v+7d +%Y-%m-%d)" ;;
  overdue)   todo_query_by_date on_or_before "$(date -v-1d +%Y-%m-%d)" ;;
esac | todo_format_list
```

Output is a piped table:
```
1st Priority   | Leverage  | 2026-05-18 | To-Do    | Deploy Gong connector fix (Dominik's merged PR)
1st Priority   | Leverage  | 2026-05-18 | To-Do    | Reply to Bob/Jay Fowdar/Walter/Phillip group DM
...
```

#### `blast`

The "Monday-morning blast" filter. Returns: status=To-Do/Active, priority=1st Priority, LNO=Leverage, due ≤ tomorrow.

```bash
filter='{"and":[
  {"property":"Kanban Status","status":{"does_not_equal":"Done"}},
  {"property":"Kanban Status","status":{"does_not_equal":"Archived"}},
  {"property":"Priority","select":{"equals":"1st Priority"}},
  {"property":"LNO Category","select":{"equals":"Leverage"}},
  {"property":"Due Date","date":{"on_or_before":"'"$(date -v+1d +%Y-%m-%d)"'"}}
]}'
ntn api /v1/data_sources/$NOTION_ACTION_ITEMS_DS/query \
  -d "{\"page_size\":50,\"filter\":$filter,\"sorts\":[{\"property\":\"Due Date\",\"direction\":\"ascending\"}]}" 2>/dev/null | todo_format_list
```

#### `add "title" [--priority P1] [--due tomorrow] [--project "name"] [--lno L] [--note "body"]`

```bash
# Parse flags from "$@", build the request, POST to /v1/pages.
title="$1"
priority=$(todo_resolve_priority "$priority_flag")     # P0/P1/P2/P3 → 1st/2nd/3rd/4th Priority
due=$(todo_resolve_date "$due_flag")                   # "tomorrow" → YYYY-MM-DD
lno=$(todo_resolve_lno "$lno_flag")                    # L/N/O → Leverage/Neutral/Overhead
project_id=$(todo_resolve_project "$project_flag")     # fuzzy name → UUID (empty if no match or no flag)

if [ -n "$project_flag" ] && [ -z "$project_id" ]; then
  echo "⚠️  No Projects [DB] match for '$project_flag'. Creating task without project relation."
  echo "    Use /todo by-project <name> to see existing projects." >&2
  # Don't block — create the task anyway, just unlinked.
fi

payload=$(todo_build_payload "$title" "$priority" "To-Do" "$lno" "$due" "$project_id" "$note_flag")
resp=$(ntn api /v1/pages -d "$payload" 2>&1)
id=$(echo "$resp" | jq -r '.id // empty')
if [ -n "$id" ]; then
  echo "✔ Created: $title"
  echo "  Priority=$priority | LNO=$lno | Due=$due | Project=${project_flag:-none}"
  echo "  URL: $(echo "$resp" | jq -r '.url')"
else
  echo "✗ Failed: $resp" >&2
fi
```

**Defaults if flags omitted**: priority=`2nd Priority`, lno=`Neutral`, due=`null` (no due date), project=`null`, note=`null`.

#### `done "<fuzzy title>"`

```bash
match=$(todo_find_task_id "$query")
case "$match" in
  NO_MATCH)
    echo "✗ No open task matches '$query'."
    return 1 ;;
  AMBIGUOUS)
    echo "Multiple matches — please be more specific. See list above." >&2
    return 1 ;;
  *)
    id=$(echo "$match" | cut -f1)
    title=$(echo "$match" | cut -f2)
    ntn api /v1/pages/$id -X PATCH -d '{"properties":{"Kanban Status":{"status":{"name":"Done"}}}}' >/dev/null 2>&1
    echo "✔ Done: $title"
    ;;
esac
```

#### `by-project <name>`

```bash
project_id=$(todo_resolve_project "$1")
if [ -z "$project_id" ]; then
  echo "✗ No Projects [DB] match for '$1'."
  return 1
fi
filter='{"and":[
  {"property":"Projects [DB]      ","relation":{"contains":"'"$project_id"'"}},
  {"property":"Kanban Status","status":{"does_not_equal":"Done"}},
  {"property":"Kanban Status","status":{"does_not_equal":"Archived"}}
]}'
ntn api /v1/data_sources/$NOTION_ACTION_ITEMS_DS/query \
  -d "{\"page_size\":50,\"filter\":$filter,\"sorts\":[{\"property\":\"Priority\",\"direction\":\"ascending\"}]}" 2>/dev/null | todo_format_list
```

### Step 3: Surface results to user

Don't dump 50 rows when 5 are relevant. If the list is long (>15), summarize the rest:

```
... showing top 15 of 32 open tasks. Use `/todo by-project <name>` or add a flag to narrow.
```

Always include the count at the bottom: `N tasks open for this view`.

## Examples

```bash
# Tomorrow's plan
/todo tomorrow

# Quick capture mid-conversation
/todo add "Reply to Bob re: Databricks cost governance" --priority P0 --due tomorrow --project "Central Tools Architecture" --lno L

# Monday-morning go-to view
/todo blast

# Mark something done after you do it
/todo done "Gong connector fix"

# Project-scoped view
/todo by-project "AI Engineer Hiring"
```

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| "NOTION_API_TOKEN not set" | Shell didn't source `.second-brain-os.env` | Run `source ~/.second-brain-os.env` then retry |
| "Could not parse date 'X'" | Date format not recognized by `todo_resolve_date` | Use ISO YYYY-MM-DD or the named tokens (today/tomorrow/mon/etc.) |
| "No Projects [DB] match for X" | Fuzzy match found nothing | Run `/todo by-project` (no arg) or check Notion for the exact name |
| Task created but Project relation empty | Project name didn't match | Re-run with exact substring of the project title |
| `done` says AMBIGUOUS | Fuzzy title matched 2+ open tasks | Add more words from the title until unique |
| Property name error from API | Trailing/leading whitespace got normalized | Check `lib/ntn.sh` for the exact `Projects [DB]      ` literal (6 trailing spaces) |
| Wrong workspace | Token authorized against a work / shared Notion workspace, not <user.name>'s personal one | The skill targets <user.name>'s personal Notion (PARA-aligned). If the token is wrong, generate a new internal integration token from the correct account at https://www.notion.so/profile/integrations and share the Action Items database with it. |
| Skill silently no-ops | `ntn` CLI not on PATH | `command -v ntn` — install via `curl -fsSL https://ntn.dev \| NTN_INSTALL_DIR=$HOME/.local/bin bash` |
| Slow first call (~2s) | First Notion API call per session has TLS handshake overhead | Acceptable; subsequent calls are sub-second |
| Created duplicate task on 504 retry | Notion sometimes returns 504 after a successful write | If `add` errors, check Notion before retrying. Per the 2026-05-17 incident where this happened once. |

## Boundaries

- **Never auto-send** anything — this skill is local to <user.name>'s Notion workspace, not external messaging.
- **Never modify schema** of Action Items [DB] or Projects [DB] — that's done in Notion UI.
- **Never delete** — only Done or Archived status changes.
- **Never bulk-modify** — every `done` targets one fuzzy-matched task with disambiguation gate.
- **Never write the API token** anywhere — env vars only, source from `~/.second-brain-os.env`.
- **Never assume the personal workspace** if `NOTION_API_TOKEN` is missing — fail loudly per Step 0.

## Integration map (future v2)

- `/briefing` Step 7 (Project synthesis) will optionally pull `priority IN (1st, 2nd) AND due ≤ today+1` from Action Items [DB] per project, replacing the manual mental sync between brief HTML and Notion. Wired via `todo_query_by_date between today tomorrow` cross-referenced with each project row.
- `/contact-log` can call `/todo add` when an interaction has the form "<user.name> promised X to Y by Z" — auto-create a follow-up task linked to that person's contact slug in the body block.
- `/inbox-process` can surface 0-Inbox files as tasks if <user.name> says "track this" during triage.

## Why this exists

<user.name>'s existing PARA-aligned Notion is the source of truth for what he's working on across work + personal life. Before this skill, every task surfaced in `/briefing` or chat lived only in transient conversation context — it was on him to manually copy them into Notion (which he wasn't doing, because that's friction). The brief became a "lay of the land" snapshot, but the lifecycle ended at the conversation.

This skill closes the loop. Capture from chat → land in Notion → surface in tomorrow's `/briefing` → mark done as you go. The PARA discipline (Priorities, LNO, Projects relation) is preserved because the skill respects <user.name>'s existing schema rather than imposing a new one.
