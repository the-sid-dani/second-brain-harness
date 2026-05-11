#!/usr/bin/env bash
# project-query.sh — scan all <workspace.root>/<workspace.projects>/*/CLAUDE.md
# (resolved from root CLAUDE.md's Configuration section — typically
# workspace/1-Projects/), extract YAML frontmatter, output a sortable
# table. Source of truth for project discovery (no INDEX file, per
# system-design.md §7 lock #15).
#
# Path resolution: this script lives at
# <workspace.root>/<workspace.resources>/templates/project-query.sh and uses
# its own location (../../<workspace.projects>) to find the projects folder,
# so it works for any user as long as the canonical path holds. If the
# Configuration section in root CLAUDE.md changes those folder names, the
# `cd` line below should match.
#
# Usage:
#   ./project-query.sh                  # all active projects, sorted by days_touched desc
#   ./project-query.sh --stale-days 90  # mark active projects untouched ≥N days as STALE
#   ./project-query.sh --tsv            # tab-separated, no header — for piping
#   ./project-query.sh --status all     # include paused/done (default: active only)
#
# last_touched = max(mtime of memory.md, mtime of CLAUDE.md). memory.md grows
# with the work, so it's the truer liveness signal.

set -euo pipefail

STALE_DAYS=90
TSV=0
STATUS_FILTER="active"

while [ $# -gt 0 ]; do
  case "$1" in
    --stale-days) STALE_DAYS="$2"; shift 2 ;;
    --tsv)        TSV=1; shift ;;
    --status)     STATUS_FILTER="$2"; shift 2 ;;
    -h|--help)    sed -n '2,15p' "$0"; exit 0 ;;
    *)            echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECTS_DIR="$SCRIPT_DIR/../../1-Projects"

[ -d "$PROJECTS_DIR" ] || { echo "1-Projects/ not found at $PROJECTS_DIR" >&2; exit 1; }

mtime_epoch() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"; }
fmt_date()    { date -r "$1" +%Y-%m-%d 2>/dev/null || date -d "@$1" +%Y-%m-%d; }

extract_field() {
  awk -v key="$1" '
    /^---$/ { n++; if (n == 2) exit; next }
    n == 1 && $1 == key":" {
      sub(/^[^:]*:[[:space:]]*/, "")
      sub(/[[:space:]]*#.*$/, "")
      print
      exit
    }
  ' "$2"
}

now=$(date +%s)
rows=""

for proj_dir in "$PROJECTS_DIR"/*/; do
  [ -d "$proj_dir" ] || continue
  slug=$(basename "$proj_dir")
  claude_md="$proj_dir/CLAUDE.md"
  memory_md="$proj_dir/memory.md"

  if [ ! -f "$claude_md" ]; then
    # Project predates Pass 2c scaffolding — surface only when --status all
    if [ "$STATUS_FILTER" = "all" ]; then
      m_epoch=$(mtime_epoch "$proj_dir")
      touched=$(fmt_date "$m_epoch")
      days=$(( (now - m_epoch) / 86400 ))
      rows+="$slug|unmigrated|?|?|$touched|$days|NEEDS_SCAFFOLD"$'\n'
    fi
    continue
  fi

  status=$(extract_field "status" "$claude_md")
  ptype=$(extract_field "project-type" "$claude_md")
  created=$(extract_field "created" "$claude_md")

  status=${status:-?}
  ptype=${ptype:-?}
  created=${created:-?}

  if [ "$STATUS_FILTER" != "all" ] && [ "$status" != "$STATUS_FILTER" ]; then
    continue
  fi

  if [ -f "$memory_md" ]; then
    m_epoch=$(mtime_epoch "$memory_md")
    c_epoch=$(mtime_epoch "$claude_md")
    [ "$c_epoch" -gt "$m_epoch" ] && m_epoch=$c_epoch
  else
    m_epoch=$(mtime_epoch "$claude_md")
  fi

  touched=$(fmt_date "$m_epoch")
  days=$(( (now - m_epoch) / 86400 ))

  flag=""
  if [ "$status" = "active" ] && [ "$ptype" != "ongoing" ] && [ "$days" -ge "$STALE_DAYS" ]; then
    flag="STALE"
  fi

  rows+="$slug|$status|$ptype|$created|$touched|$days|$flag"$'\n'
done

# Sort by days_touched (column 6) desc — staleest first
sorted=$(printf '%s' "$rows" | sort -t'|' -k6 -n -r)

if [ "$TSV" = "1" ]; then
  printf '%s' "$sorted" | tr '|' '\t'
  exit 0
fi

# Pretty table — compute column widths ourselves (macOS `column` has a low LINE_MAX)
{
  echo "slug|status|type|created|touched|days|flag"
  printf '%s' "$sorted"
} | awk -F'|' '
  { lines[NR] = $0; nf = NF
    for (i = 1; i <= NF; i++) if (length($i) > w[i]) w[i] = length($i)
  }
  END {
    for (r = 1; r <= NR; r++) {
      n = split(lines[r], f, "|")
      for (i = 1; i <= n; i++) printf "%-*s%s", w[i], f[i], (i < n ? "  " : "\n")
    }
  }
'
