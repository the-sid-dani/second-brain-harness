#!/usr/bin/env bash
# scripts/install.sh — second-brain-os installer for fork users.
# Idempotent. Safe to re-run. macOS-only (WSL2 deferred).
#
# Phases:
#   1-3 Foundation (Homebrew, Node/git, Claude Code) — skipped if foundation already installed
#   4-7 Toolchain (sys-extras, Rust, uv, CCv4 binaries)
#   8   CCv4 Python deps
#   9   FastEdit MCP registration
#   10  API keys (interactive)
#   11  Verify

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"  # so .env / .mcp.json edits land in repo root

# ---- flag parsing ----
NO_FASTEDIT_MODEL=0
SKIP_API_KEYS=0
VERBOSE=0
RECONFIGURE=0
print_help=0
help_exit_code=0

while [ $# -gt 0 ]; do
    case "$1" in
        --no-fastedit-model) NO_FASTEDIT_MODEL=1 ;;
        --skip-api-keys)     SKIP_API_KEYS=1 ;;
        --verbose)           VERBOSE=1 ;;
        --reconfigure)       RECONFIGURE=1 ;;
        --help|-h)           print_help=1 ;;
        *)
            echo "unknown flag: $1" >&2
            print_help=1
            help_exit_code=2
            break
            ;;
    esac
    shift
done
export NO_FASTEDIT_MODEL SKIP_API_KEYS VERBOSE RECONFIGURE

if [ "$print_help" = "1" ]; then
    cat <<'HELP'
second-brain-os installer

Usage: ./scripts/install.sh [flags]

Flags:
  --no-fastedit-model   Skip FastEdit model download (~3GB). For disk-constrained machines.
  --skip-api-keys       Skip interactive API-key prompts; write empty .env stubs instead.
  --verbose             Stream sub-command output.
  --reconfigure         Re-prompt for API keys even if .env is populated (key rotation).
  --help, -h            Print this message and exit.

This installer is idempotent — safe to re-run after partial completion or to apply updates.
HELP
    exit "$help_exit_code"
fi

[ "$VERBOSE" = "1" ] && set -x

# ---- source lib helpers ----
for lib in ui detect prereqs claude sys-extras rust uv ccv4-bins ccv4-python fastedit-mcp api-keys verify; do
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/${lib}.sh"
done

# init_log if ui.sh exposes it
type init_log >/dev/null 2>&1 && init_log

header "second-brain-os install" 2>/dev/null || true

# Override the 3-arg `step <num> <label> <cmd...>` form from ui.sh with a CCv4-port-style
# single-arg banner. Sibling libs (and the pipeline below) call `step "[N/11] label"`
# as a banner, then chain the install function via `&&` — keeping the runner
# logic on the caller side, not inside step.
step() {
    printf '\n\033[1;34m==> %s\033[0m\n' "$1"
}

# ---- foundation detection ----
FOUNDATION_INSTALLED=0
if command -v gh >/dev/null 2>&1 \
   && command -v claude >/dev/null 2>&1; then
    FOUNDATION_INSTALLED=1
    info "foundation toolchain detected (gh + claude on PATH) — skipping foundation steps 1-3"
fi

# ---- 11-step pipeline ----
if [ "$FOUNDATION_INSTALLED" -eq 0 ]; then
    step "[1/11] Homebrew"           && install_brew
    step "[2/11] Node 20, git, jq"   && install_node_and_git
    step "[3/11] Claude Code"        && install_claude
else
    info "[1-3/11] skipped (foundation already installed)"
fi

step "[4/11]  System extras"         && install_sys_extras
step "[5/11]  Rust toolchain"        && install_rust
step "[6/11]  uv (Python pkg mgr)"   && install_uv
step "[7/11]  CCv4 binaries"         && install_ccv4_bins
step "[8/11]  CCv4 Python deps"      && install_ccv4_python
step "[9/11]  FastEdit MCP register" && install_fastedit_mcp
step "[10/11] API keys"              && configure_api_keys
step "[11/11] Verify"                && verify_all

cat <<'NEXT'

────────────────────────────────────────────────────────────────────────
✅ Install complete. The OS-level toolchain is ready.

Next: configure your persona + workspace (in Claude Code, not the shell)

   1. Open Claude Code in this folder:   claude
   2. Run the bootstrap skill:           /bootstrap
   3. After /bootstrap finishes, run:    /mcp   (authorize HTTP MCPs for this workspace)

/bootstrap walks you through identity, persona, design system, and writes
TOOLS.md from live probes. ~15 minutes.

Re-run this installer with --reconfigure to rotate API keys, --help for flags.
────────────────────────────────────────────────────────────────────────
NEXT
