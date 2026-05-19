#!/usr/bin/env bash
# /todo skill helper — Notion API ops for Action Items [DB]
# Source this file, then call functions. All read-mostly, write-light.
# Token + DS IDs come from ~/.second-brain-os.env (auto-loaded by ~/.zshrc).

set -uo pipefail

# --- Env validation -----------------------------------------------------------

todo_check_env() {
  if [ -z "${NOTION_API_TOKEN:-}" ] || [ -z "${NOTION_ACTION_ITEMS_DS:-}" ]; then
    echo "ERROR: NOTION_API_TOKEN or NOTION_ACTION_ITEMS_DS not set." >&2
    echo "  Source: ~/.second-brain-os.env (loaded by ~/.zshrc)" >&2
    echo "  If running from a non-interactive shell, run: source ~/.second-brain-os.env" >&2
    return 1
  fi
  if ! command -v ntn >/dev/null 2>&1; then
    echo "ERROR: ntn CLI not on PATH. Install: curl -fsSL https://ntn.dev | NTN_INSTALL_DIR=\$HOME/.local/bin bash" >&2
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq not installed. Install: brew install jq" >&2
    return 1
  fi
}

# --- Date helpers -------------------------------------------------------------
# Resolve human dates → ISO YYYY-MM-DD (Mac BSD date syntax).

todo_resolve_date() {
  local input="${1:-}"
  case "$input" in
    "") echo "" ;;
    today)    date +%Y-%m-%d ;;
    tomorrow) date -v+1d +%Y-%m-%d ;;
    next-monday|monday|mon)   date -v+Mon +%Y-%m-%d ;;
    next-tuesday|tuesday|tue) date -v+Tue +%Y-%m-%d ;;
    next-wednesday|wed)       date -v+Wed +%Y-%m-%d ;;
    next-thursday|thu)        date -v+Thu +%Y-%m-%d ;;
    next-friday|fri)          date -v+Fri +%Y-%m-%d ;;
    eow|end-of-week)          date -v+Fri +%Y-%m-%d ;;
    next-week|nw)             date -v+7d +%Y-%m-%d ;;
    20[0-9][0-9]-[0-1][0-9]-[0-3][0-9]) echo "$input" ;;  # already ISO
    *)
      # Try BSD date parsing for things like "5/22" or "May 22"
      date -j -f "%Y-%m-%d" "$input" +%Y-%m-%d 2>/dev/null || \
      date -j -f "%m/%d/%Y" "$input" +%Y-%m-%d 2>/dev/null || \
      date -j -f "%m/%d" "$input" +%Y-%m-%d 2>/dev/null || \
      { echo "ERROR: could not parse date '$input'" >&2; return 1; }
      ;;
  esac
}

# --- Priority shortcuts -------------------------------------------------------
# P0/P1/P2/P3 → 1st/2nd/3rd/4th Priority (PARA-aligned convention).
# Pass-through if already in canonical form.

todo_resolve_priority() {
  case "${1:-}" in
    P0|p0|1st) echo "1st Priority" ;;
    P1|p1|2nd) echo "2nd Priority" ;;
    P2|p2|3rd) echo "3rd Priority" ;;
    P3|p3|4th) echo "4th Priority" ;;
    "")        echo "2nd Priority" ;;  # default
    *)         echo "$1" ;;            # passthrough (Urgent, Quick ⚡️, etc.)
  esac
}

# --- LNO shortcut -------------------------------------------------------------

todo_resolve_lno() {
  case "${1:-}" in
    L|l|leverage|Leverage) echo "Leverage" ;;
    N|n|neutral|Neutral)   echo "Neutral" ;;
    O|o|overhead|Overhead) echo "Overhead" ;;
    "")                    echo "Neutral" ;;  # default
    *)                     echo "$1" ;;
  esac
}

# --- Project name → ID resolution (fuzzy contains) ----------------------------

todo_resolve_project() {
  local name="${1:-}"
  [ -z "$name" ] && { echo ""; return 0; }

  local result
  result=$(ntn api /v1/data_sources/$NOTION_PROJECTS_DS/query \
    -d "{\"page_size\":5,\"filter\":{\"property\":\"Project Name\",\"title\":{\"contains\":\"$name\"}}}" 2>/dev/null) || true

  # Fallback if "Project Name" isn't the title field — try the generic title-field approach
  if [ -z "$result" ] || [ "$(echo "$result" | jq -r '.results | length')" = "0" ]; then
    # Build a query that filters via title using the data_source's auto-discovered title prop
    result=$(ntn api /v1/data_sources/$NOTION_PROJECTS_DS/query -d '{"page_size":100}' 2>/dev/null) || true
    # Client-side filter by title contains
    local match
    match=$(echo "$result" | jq -r --arg q "$name" '
      .results[] |
      select(
        ([.properties[]? | select(.type=="title") | .title[]? | .plain_text] | join("") | ascii_downcase) | contains(($q | ascii_downcase))
      ) | .id' | head -1)
    echo "$match"
    return 0
  fi
  echo "$result" | jq -r '.results[0].id // empty'
}

# --- Build a task-create JSON payload -----------------------------------------

todo_build_payload() {
  # Note: do NOT name local 'status' — zsh has it as read-only.
  local title="$1" priority="$2" kstatus="${3:-To-Do}" lno="$4" due="$5" project_id="$6" body="${7:-}"

  local props
  props=$(jq -n --arg t "$title" --arg p "$priority" --arg s "$kstatus" --arg l "$lno" '{
    "Action Items": {title: [{text: {content: $t}}]},
    "Priority": {select: {name: $p}},
    "Kanban Status": {status: {name: $s}},
    "LNO Category": {select: {name: $l}}
  }')
  [ -n "$due" ] && props=$(echo "$props" | jq --arg d "$due" '. + {"Due Date": {date: {start: $d}}}')
  [ -n "$project_id" ] && props=$(echo "$props" | jq --arg pid "$project_id" '. + {"Projects [DB]      ": {relation: [{id: $pid}]}}')

  if [ -n "$body" ]; then
    jq -n --argjson props "$props" --arg ds "$NOTION_ACTION_ITEMS_DS" --arg body "$body" '{
      parent: {type: "data_source_id", data_source_id: $ds},
      properties: $props,
      children: [{object: "block", type: "paragraph", paragraph: {rich_text: [{type: "text", text: {content: $body}}]}}]
    }'
  else
    jq -n --argjson props "$props" --arg ds "$NOTION_ACTION_ITEMS_DS" '{
      parent: {type: "data_source_id", data_source_id: $ds},
      properties: $props
    }'
  fi
}

# --- Query helpers (read) -----------------------------------------------------

# Query Action Items with a date filter + status To-Do (default).
# Args: $1 = date filter mode ('equals'|'on_or_before'|'on_or_after'|'between')
#       $2 = first date (YYYY-MM-DD)
#       $3 = optional second date (for 'between')
todo_query_by_date() {
  local mode="$1" d1="$2" d2="${3:-}"
  local filter
  case "$mode" in
    equals)        filter="{\"property\":\"Due Date\",\"date\":{\"equals\":\"$d1\"}}" ;;
    on_or_before)  filter="{\"property\":\"Due Date\",\"date\":{\"on_or_before\":\"$d1\"}}" ;;
    on_or_after)   filter="{\"property\":\"Due Date\",\"date\":{\"on_or_after\":\"$d1\"}}" ;;
    between)       filter="{\"and\":[{\"property\":\"Due Date\",\"date\":{\"on_or_after\":\"$d1\"}},{\"property\":\"Due Date\",\"date\":{\"on_or_before\":\"$d2\"}}]}" ;;
    *) echo "ERROR: unknown date mode '$mode'" >&2; return 1 ;;
  esac

  # Also require status != Done (open tasks only)
  local full_filter="{\"and\":[$filter,{\"property\":\"Kanban Status\",\"status\":{\"does_not_equal\":\"Done\"}},{\"property\":\"Kanban Status\",\"status\":{\"does_not_equal\":\"Archived\"}}]}"

  ntn api /v1/data_sources/$NOTION_ACTION_ITEMS_DS/query \
    -d "{\"page_size\":100,\"filter\":$full_filter,\"sorts\":[{\"property\":\"Priority\",\"direction\":\"ascending\"}]}" 2>/dev/null
}

# Pretty-print a task list (compact, terminal-friendly).
# Reads JSON results from stdin.
todo_format_list() {
  jq -r '.results[] | "\(.properties.Priority.select.name // "—" | (. + "                ")[0:14]) | \(.properties["LNO Category"].select.name // "—" | (. + "          ")[0:9]) | \(.properties["Due Date"].date.start // "no-date" | (. + "          ")[0:10]) | \(.properties["Kanban Status"].status.name // "—" | (. + "        ")[0:8]) | \(([.properties["Action Items"].title[]?.plain_text] | join("")))"' 2>/dev/null
}

# --- Find a task by fuzzy title match ----------------------------------------
# Returns: task ID + title on success, empty on no match, ambiguous warning on multiple.
# Uses CLIENT-SIDE filtering (not Notion's title-contains filter) to avoid the
# ~5-10s search-index lag on newly-created pages. Pulls open tasks (status != Done)
# and greps by case-insensitive substring.
todo_find_task_id() {
  local query="$1"
  local resp
  # Pull all open tasks (excluding Done/Archived). For workspaces with >100 open
  # tasks, paginate — but typically open backlog fits in one page.
  resp=$(ntn api /v1/data_sources/$NOTION_ACTION_ITEMS_DS/query \
    -d '{"page_size":100,"filter":{"and":[{"property":"Kanban Status","status":{"does_not_equal":"Done"}},{"property":"Kanban Status","status":{"does_not_equal":"Archived"}}]}}' 2>/dev/null)

  # Client-side filter: case-insensitive substring match on the title.
  local matches
  matches=$(echo "$resp" | jq -r --arg q "$query" '
    .results[] |
    select(([.properties["Action Items"].title[]?.plain_text] | join("") | ascii_downcase) | contains(($q | ascii_downcase))) |
    "\(.id)\t\([.properties["Action Items"].title[]?.plain_text] | join(""))"
  ')

  local count
  count=$(echo "$matches" | grep -c . || true)
  if [ "$count" = "0" ]; then
    echo "NO_MATCH"
  elif [ "$count" = "1" ]; then
    echo "$matches"
  else
    echo "AMBIGUOUS"
    echo "$matches" | sed 's/^/  /' >&2
  fi
}
