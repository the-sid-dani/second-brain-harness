# shellcheck shell=bash
# lib/ui.sh — colored output, step framing, log file management.

LOG_FILE="${HOME}/second-brain-os-install.log"

# Truncate the log file. Called explicitly from install.sh on each run start so
# that re-sourcing this file (e.g., from a sub-shell) doesn't wipe an in-flight log.
init_log() {
  : > "$LOG_FILE"
}

if [ -t 1 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; DIM=''; RESET=''
fi

header() {
  printf '\n%sSecond-Brain OS Installer%s\n' "$BOLD" "$RESET"
  printf '%sInstalls Claude Code + CCv4 toolchain (bloks, tldr, optional FastEdit MCP) and pre-configures workspaces.%s\n' "$DIM" "$RESET"
  printf '%sLog: %s%s\n\n' "$DIM" "$LOG_FILE" "$RESET"
}

step() {
  local num="$1"; shift
  local label="$1"; shift
  printf '\n%s[%d/%d] %s%s\n' "$BLUE$BOLD" "$num" "$TOTAL_STEPS" "$label" "$RESET"
  if "$@"; then
    return 0
  else
    printf '%s✗ Step %d failed. See %s%s\n' "$RED" "$num" "$LOG_FILE" "$RESET" >&2
    exit 1
  fi
}

ok()    { printf '       %s✓%s %s\n' "$GREEN"  "$RESET" "$1"; }
skip()  { printf '       %s•%s %s\n' "$DIM"    "$RESET" "$1"; }
info()  { printf '       %s→%s %s\n' "$BLUE"   "$RESET" "$1"; }
warn()  { printf '       %s!%s %s\n' "$YELLOW" "$RESET" "$1"; }

# Run a command quietly; output is appended to log file.
# VERBOSE=1 streams output to terminal as well.
run() {
  if [ "${VERBOSE:-0}" = "1" ]; then
    "$@" 2>&1 | tee -a "$LOG_FILE"
    return "${PIPESTATUS[0]}"
  else
    "$@" >>"$LOG_FILE" 2>&1
  fi
}

# ---- Interactive prompts (added 2026-05-06 for client_secret onboarding) -----

# prompt_choice <prompt-text> <choice1> <choice2> [<choice3> ...]
#
# Prints the prompt-text and numbered list of choices to stderr (so callers
# using $(prompt_choice ...) capture only the chosen number on stdout). Reads
# a single line from stdin, and on a valid 1-indexed numeric reply echoes the
# chosen number to stdout (so callers can capture via $(prompt_choice ...))
# and returns 0. On invalid input, prints an error to stderr and returns 1 —
# the caller is responsible for re-prompting.
#
# Bash 3.2 compatible: no ${var,,}, no mapfile, no associative arrays.
prompt_choice() {
  local prompt_text="$1"; shift
  local total=$#
  if [ "$total" -lt 1 ]; then
    printf '%sprompt_choice: at least one choice required%s\n' "$RED" "$RESET" >&2
    return 1
  fi

  printf '%s\n' "$prompt_text" >&2
  local i=1
  local choice
  for choice in "$@"; do
    printf '  [%d] %s\n' "$i" "$choice" >&2
    i=$((i + 1))
  done

  local reply=""
  read -r reply

  case "$reply" in
    ''|*[!0-9]*)
      printf '%sInvalid choice — please enter a number from 1 to %d%s\n' "$RED" "$total" "$RESET" >&2
      return 1
      ;;
  esac

  if [ "$reply" -lt 1 ] || [ "$reply" -gt "$total" ]; then
    printf '%sInvalid choice — please enter a number from 1 to %d%s\n' "$RED" "$total" "$RESET" >&2
    return 1
  fi

  printf '%s\n' "$reply"
  return 0
}

# validate_oauth_json <path-to-json-file>
#
# Returns 0 if the file parses as JSON via jq AND contains both
# .installed.client_id and .installed.client_secret as non-empty strings.
# Returns 1 with a single-line error to stderr on any failure.
validate_oauth_json() {
  local path="${1:-}"

  if ! command -v jq >/dev/null 2>&1; then
    printf '%sjq not installed — cannot validate JSON. Run: brew install jq%s\n' "$RED" "$RESET" >&2
    return 1
  fi

  if [ -z "$path" ]; then
    printf '%svalidate_oauth_json: no path provided%s\n' "$RED" "$RESET" >&2
    return 1
  fi

  if [ ! -f "$path" ]; then
    printf '%sOAuth client file not found: %s%s\n' "$RED" "$path" "$RESET" >&2
    return 1
  fi

  if ! jq empty "$path" >/dev/null 2>&1; then
    printf '%sOAuth client file is not valid JSON: %s%s\n' "$RED" "$path" "$RESET" >&2
    return 1
  fi

  if ! jq -e '.installed.client_id and .installed.client_secret and (.installed.client_id != "") and (.installed.client_secret != "")' "$path" >/dev/null 2>&1; then
    printf '%sOAuth client file missing or empty .installed.client_id / .installed.client_secret: %s%s\n' "$RED" "$path" "$RESET" >&2
    return 1
  fi

  return 0
}
