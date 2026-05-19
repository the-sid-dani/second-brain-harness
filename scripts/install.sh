#!/usr/bin/env bash
# scripts/install.sh — second-brain-os installer for fork users.
# Idempotent. Safe to re-run. macOS-only (WSL2/Windows deferred to v0.3.0).
#
# Tiers (v0.2.0):
#   Minimal (default)     Foundation + system extras + .env.example + verify + tier marker
#                         7 steps total; ~3-5 min with foundation present.
#   Coding (--with-coding) Adds Rust, uv, CCv4 binaries (bloks + tldr-cli),
#                          CCv4 Python deps, FastEdit MCP. 12 steps total.
#
# Knowledge-worker forks should run the default. Add --with-coding only if
# you need /research, /autonomous, /premortem, or FastEdit-MCP-backed edits.

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
INSTALL_RIPGREP=0
INSTALL_CODING=0
DOCTOR_MODE=0
print_help=0
help_exit_code=0

while [ $# -gt 0 ]; do
    case "$1" in
        --no-fastedit-model) NO_FASTEDIT_MODEL=1 ;;
        --skip-api-keys)     SKIP_API_KEYS=1 ;;
        --verbose)           VERBOSE=1 ;;
        --reconfigure)       RECONFIGURE=1 ;;
        --with-ripgrep)      INSTALL_RIPGREP=1 ;;
        --with-coding)       INSTALL_CODING=1 ;;
        --doctor)            DOCTOR_MODE=1 ;;
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
export NO_FASTEDIT_MODEL SKIP_API_KEYS VERBOSE RECONFIGURE INSTALL_RIPGREP INSTALL_CODING DOCTOR_MODE

if [ "$print_help" = "1" ]; then
    cat <<'HELP'
second-brain-os installer

Usage: ./scripts/install.sh [flags]

Flags:
  --no-fastedit-model   Skip FastEdit model download (~3GB). For disk-constrained machines.
  --skip-api-keys       Deprecated no-op. The installer no longer prompts for keys —
                        it writes an annotated .env.example you can fill in later.
  --verbose             Stream sub-command output.
  --reconfigure         Deprecated no-op (kept for backward compat). The installer
                        is fully idempotent; no re-prompting needed.
  --with-ripgrep        Install ripgrep via brew. Optional — `/find` skill works
                        without it via `grep -r` fallback (slower).
  --with-coding         Install the coding tier: Rust toolchain, uv, CCv4
                        binaries (bloks, tldr-cli), CCv4 Python deps, and
                        the FastEdit MCP. Skip for knowledge-worker default.
  --doctor              Read-only verification of an existing install (probes
                        tool versions + tier marker + .mcp.json + ~/.claude/
                        install.log; never mutates). v0.2.0 ships a stub —
                        full implementation in v0.3.0.
  --help, -h            Print this message and exit.

Tiers:
  Default (no flag)     Foundation + jq + .env.example + verify. ~3-5 min on
                        a machine with the foundation present. Right choice for
                        knowledge-worker forks.
  --with-coding         Adds Rust/uv/bloks/tldr/FastEdit. Required for /research,
                        /autonomous, and FastEdit-MCP-backed code edits.

This installer is idempotent — safe to re-run after partial completion or to apply updates.
HELP
    exit "$help_exit_code"
fi

[ "$VERBOSE" = "1" ] && set -x

# ---- --doctor stub (v0.2.0) ----
# Full implementation lands in v0.3.0 (W5). For now: print best-effort probe
# output and exit cleanly so the closing-banner hint isn't a broken promise.
if [ "$DOCTOR_MODE" = "1" ]; then
    printf '\n'
    printf '🩺 second-brain-os --doctor (v0.2.0 stub)\n'
    printf '────────────────────────────────────────────────────────────\n'
    printf 'Full --doctor lands in v0.3.0 (read-only health check with\n'
    printf 'tier-aware probes + remediation hints). For now, a minimal probe:\n\n'

    probe_one() {
        local name="$1" cmd="$2" arg="${3:---version}"
        if command -v "$cmd" >/dev/null 2>&1; then
            printf '  ✅ %-15s %s\n' "$name" "$("$cmd" "$arg" 2>/dev/null | head -1 | tr -d '\n')"
        else
            printf '  ❌ %-15s not on PATH\n' "$name"
        fi
    }

    printf 'Foundation:\n'
    probe_one claude   claude
    probe_one node     node
    probe_one git      git
    probe_one jq       jq
    probe_one gh       gh
    printf '\nTier marker:\n'
    if [ -f "$HOME/.second-brain-os.env" ] && grep -qE '^SBOS_TIER=' "$HOME/.second-brain-os.env" 2>/dev/null; then
        printf '  ✅ %s\n' "$(grep -E '^SBOS_TIER=' "$HOME/.second-brain-os.env")"
    else
        printf '  ⚠️  SBOS_TIER not set in ~/.second-brain-os.env — re-run installer to write it.\n'
    fi
    printf '\nCoding-tier tools (only relevant if SBOS_TIER=coding):\n'
    probe_one rustc    rustc
    probe_one uv       uv
    probe_one bloks    bloks
    probe_one tldr     tldr
    probe_one fastedit fastedit
    printf '\nMCP defaults (.mcp.json):\n'
    if [ -f "$REPO_ROOT/.mcp.json" ] && command -v jq >/dev/null 2>&1; then
        jq -r '.mcpServers | keys[] | "  ✅ " + .' "$REPO_ROOT/.mcp.json" 2>/dev/null || \
            printf '  ⚠️  .mcp.json present but jq failed to parse it.\n'
    else
        printf '  ❌ .mcp.json missing or jq unavailable.\n'
    fi
    printf '\nInstall log:\n'
    if [ -f "$HOME/.claude/install.log" ]; then
        printf '  ✅ ~/.claude/install.log (%s lines)\n' "$(wc -l < "$HOME/.claude/install.log" | tr -d ' ')"
    else
        printf '  ⚠️  No install log at ~/.claude/install.log — installer hasn'\''t run yet.\n'
    fi
    printf '\nDone. Full diagnostics + remediation hints in v0.3.0.\n\n'
    exit 0
fi

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
# Skip steps 1-3 (brew/node/git/jq/claude) if the foundation is already in place.
FOUNDATION_INSTALLED=0
if command -v gh >/dev/null 2>&1 \
   && command -v claude >/dev/null 2>&1 \
   && command -v jq >/dev/null 2>&1 \
   && command -v node >/dev/null 2>&1; then
    FOUNDATION_INSTALLED=1
    info "foundation toolchain detected (gh + claude + jq + node on PATH) — skipping foundation steps 1-3"
fi

# ---- ASCII logo + start time ----
INSTALL_START=$(date +%s)

cat <<'LOGO'

   ╔══════════════════════════════════════════════════════════════╗
   ║              second-brain-os installer                      ║
   ║              your fork's first 5 minutes                    ║
   ╚══════════════════════════════════════════════════════════════╝

LOGO

if [ "$INSTALL_CODING" = "1" ]; then
    info "tier: coding (foundation + ripgrep-opt-in + Rust + uv + CCv4 + FastEdit)"
else
    info "tier: minimal (foundation + jq + .env.example) — add --with-coding for the CCv4 toolchain"
fi

# ---- tee output to install log (best-effort; no-op if HOME unwritable) ----
LOG_DIR="$HOME/.claude"
mkdir -p "$LOG_DIR" 2>/dev/null || true
INSTALL_LOG="$LOG_DIR/install.log"
# Only redirect if not already redirected (avoid double-tee on re-source).
if [ -z "${SBOS_INSTALL_LOGGED:-}" ] && [ -w "$LOG_DIR" ]; then
    exec > >(tee -a "$INSTALL_LOG") 2>&1
    export SBOS_INSTALL_LOGGED=1
    info "log → $INSTALL_LOG"
fi

# ---- tier-aware pipeline ----
# Step count depends on tier:
#   minimal:  3 foundation + 1 sys-extras + 1 keys + 1 verify + 1 tier = 7
#   coding:   minimal + 5 (rust/uv/ccv4-bins/ccv4-python/fastedit-mcp) = 12
if [ "$INSTALL_CODING" = "1" ]; then
    TOTAL=12
else
    TOTAL=7
fi
N=0
nx() { N=$((N+1)); printf '[%d/%d]' "$N" "$TOTAL"; }

if [ "$FOUNDATION_INSTALLED" -eq 0 ]; then
    step "$(nx) Homebrew"           && install_brew
    step "$(nx) Node 20, git, jq"   && install_node_and_git
    step "$(nx) Claude Code"        && install_claude
else
    N=$((N+3))
    info "[1-3/$TOTAL] skipped (foundation already installed)"
fi

step "$(nx)  System extras"         && install_sys_extras

if [ "$INSTALL_CODING" = "1" ]; then
    step "$(nx)  Rust toolchain"        && install_rust
    step "$(nx)  uv (Python pkg mgr)"   && install_uv
    step "$(nx)  CCv4 binaries"         && install_ccv4_bins
    step "$(nx)  CCv4 Python deps"      && install_ccv4_python
    step "$(nx)  FastEdit MCP register" && install_fastedit_mcp
fi

step "$(nx)  API keys"              && configure_api_keys
step "$(nx)  Verify"                && verify_all

# ---- write SBOS_TIER marker (idempotent) ----
write_tier_marker() {
    local env_file="$HOME/.second-brain-os.env"
    local tier="$1"
    touch "$env_file" 2>/dev/null || { warn "could not write $env_file"; return 0; }
    if grep -qE '^SBOS_TIER=' "$env_file" 2>/dev/null; then
        # macOS-portable in-place edit via .bak then remove backup
        sed -i.bak -E "s|^SBOS_TIER=.*|SBOS_TIER=${tier}|" "$env_file"
        rm -f "${env_file}.bak"
    else
        printf '\nSBOS_TIER=%s\n' "$tier" >> "$env_file"
    fi
    info "wrote SBOS_TIER=${tier} → $env_file"
}
if [ "$INSTALL_CODING" = "1" ]; then
    step "$(nx)  Tier marker"          && write_tier_marker coding
else
    step "$(nx)  Tier marker"          && write_tier_marker minimal
fi

# ---- closing summary card + duration ----
INSTALL_END=$(date +%s)
INSTALL_DIFF=$((INSTALL_END - INSTALL_START))
INSTALL_MIN=$((INSTALL_DIFF / 60))
INSTALL_SEC=$((INSTALL_DIFF % 60))

probe_version() {
    # Print first-line --version output if installed, else "—".
    local cmd="$1" arg="${2:---version}"
    if command -v "$cmd" >/dev/null 2>&1; then
        "$cmd" "$arg" 2>/dev/null | head -1 | tr -d '\n' || true
    else
        printf '—'
    fi
}

printf '\n'
printf '┌─ installed tools ──────────────────────────────────────────┐\n'
printf '│ %-22s %-35s │\n' "tool" "version"
printf '│ %-22s %-35s │\n' "──────────────────────" "───────────────────────────────────"
printf '│ %-22s %-35s │\n' "claude"    "$(probe_version claude)"
printf '│ %-22s %-35s │\n' "node"      "$(probe_version node)"
printf '│ %-22s %-35s │\n' "jq"        "$(probe_version jq)"
printf '│ %-22s %-35s │\n' "gh"        "$(probe_version gh)"
if command -v rg >/dev/null 2>&1; then
    printf '│ %-22s %-35s │\n' "ripgrep"   "$(probe_version rg)"
fi
if [ "$INSTALL_CODING" = "1" ]; then
    printf '│ %-22s %-35s │\n' "rustc"     "$(probe_version rustc)"
    printf '│ %-22s %-35s │\n' "uv"        "$(probe_version uv)"
    printf '│ %-22s %-35s │\n' "bloks"     "$(probe_version bloks)"
    printf '│ %-22s %-35s │\n' "tldr"      "$(probe_version tldr)"
    printf '│ %-22s %-35s │\n' "fastedit"  "$(probe_version fastedit)"
fi
printf '└────────────────────────────────────────────────────────────┘\n'
printf '\nInstalled in %dm %ds. Log: %s\n' "$INSTALL_MIN" "$INSTALL_SEC" "$INSTALL_LOG"

cat <<'NEXT'

────────────────────────────────────────────────────────────────────────
✅ Install complete. The system toolchain is ready.

This installer follows a 3-layer model — you've just completed layer 1.

   Layer 1 — System tools          DONE  ←  ./scripts/install.sh (this script)
   Layer 2 — Workspace + persona   NEXT  ←  claude  →  /bootstrap
   Layer 3 — Optional API keys     LATER ←  edit .env  (see .env.example)

Next steps:

   1. Open Claude Code in this folder:   claude
   2. Run the bootstrap skill:           /bootstrap
        (~15 min — walks you through identity, persona, design system,
         writes TOOLS.md from live probes)
   3. After /bootstrap finishes, run:    /mcp   (authorize HTTP MCPs)
        (~1 min — browser-OAuth for the connectors you picked)
   4. Optional features: copy .env.example to .env and fill in any of
      the 5 optional keys you want to use. None are required.
NEXT

if [ "$INSTALL_CODING" != "1" ]; then
    cat <<'CODING_HINT'

   💡 Want /research, /autonomous, or surgical FastEdit AST code edits?
      Re-run with:   ./scripts/install.sh --with-coding
      Adds Rust + uv + bloks + tldr + FastEdit MCP (~15 min extra).
      Knowledge-worker flows (briefings, /todo, /find) don't need it.

CODING_HINT
fi

cat <<'DOCTOR_HINT'
   🩺 If something looks wrong later, probe the install with:
      ./scripts/install.sh --doctor   (read-only verification, no changes)

DOCTOR_HINT

cat <<'END'
────────────────────────────────────────────────────────────────────────
END
