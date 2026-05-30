#!/usr/bin/env bash
#
# samba-publish — Deploy static HTML to Cloudflare Pages with @samba.com / @samba.tv SSO gating
#
# Usage:
#   publish.sh <path> [--slug <slug>] [--public | --to <emails>]
#
# Modes:
#   Personal mode (default): uses wrangler OAuth, deploys to user's CF account
#   Org mode:                set SAMBA_PUBLISH_TOKEN to use Samba's service token

set -euo pipefail

# ── Color output ──────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_RESET="\033[0m"; C_BOLD="\033[1m"; C_DIM="\033[2m"
  C_GREEN="\033[32m"; C_YELLOW="\033[33m"; C_RED="\033[31m"; C_CYAN="\033[36m"
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_CYAN=""
fi

log()  { printf "%b%s%b\n" "$C_DIM" "$1" "$C_RESET" >&2; }
info() { printf "%b▸%b %s\n" "$C_CYAN" "$C_RESET" "$1" >&2; }
ok()   { printf "%b✓%b %s\n" "$C_GREEN" "$C_RESET" "$1" >&2; }
warn() { printf "%b⚠%b %s\n" "$C_YELLOW" "$C_RESET" "$1" >&2; }
err()  { printf "%b✘%b %s\n" "$C_RED" "$C_RESET" "$1" >&2; }
die()  { err "$1"; exit 1; }

# ── Parse arguments ───────────────────────────────────────────────────────
INPUT=""
SLUG=""
POLICY="default"   # default | public | allowlist
ALLOWLIST=""
DRY_RUN="false"
ASSUME_YES="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug)        SLUG="$2"; shift 2 ;;
    --public)      POLICY="public"; shift ;;
    --to)          POLICY="allowlist"; ALLOWLIST="$2"; shift 2 ;;
    --dry-run)     DRY_RUN="true"; shift ;;
    --assume-yes)  ASSUME_YES="true"; shift ;;
    --help|-h)     sed -n '3,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)            die "Unknown flag: $1" ;;
    *)             [ -z "$INPUT" ] && INPUT="$1" || die "Unexpected argument: $1"; shift ;;
  esac
done

[ -z "$INPUT" ] && die "Usage: publish.sh <path> [--slug <slug>] [--public | --to <emails>] [--dry-run]"
[ ! -e "$INPUT" ] && die "Path does not exist: $INPUT"

# ── Environment checks ────────────────────────────────────────────────────
if [ "$DRY_RUN" = "false" ]; then
  command -v wrangler >/dev/null 2>&1 || die "wrangler not found. Install: npm install -g wrangler"
  # Note: we no longer pre-check auth — wrangler itself will error clearly if not authenticated.
  # Pre-checks via `wrangler whoami` are unreliable in non-TTY contexts.
fi

# Detect mode
if [ -n "${SAMBA_PUBLISH_TOKEN:-}" ]; then
  MODE="org"
  ACCOUNT_ID="${SAMBA_CF_ACCOUNT_ID:-}"
  [ -z "$ACCOUNT_ID" ] && die "Org mode requires SAMBA_CF_ACCOUNT_ID env var"
else
  MODE="personal"
fi

info "Mode: $MODE"

# ── Compute slug ──────────────────────────────────────────────────────────
if [ -z "$SLUG" ]; then
  if [ -d "$INPUT" ]; then
    SLUG=$(basename "$INPUT")
  else
    SLUG=$(basename "$INPUT" | sed 's/\.[^.]*$//')
  fi
  # Sanitize: lowercase, only a-z 0-9 -, no leading/trailing hyphens, max 58 chars (CF limit)
  SLUG=$(echo "$SLUG" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/--*/-/g; s/^-//; s/-$//' | cut -c1-58)
fi

[ -z "$SLUG" ] && die "Could not derive slug from input. Use --slug to specify."

# Project name (slug for personal mode, fixed for org mode)
if [ "$MODE" = "org" ]; then
  PROJECT_NAME="samba-publish"
else
  PROJECT_NAME="$SLUG"
fi

info "Slug: $SLUG"
info "Project: $PROJECT_NAME"

# ── Stage deploy directory ────────────────────────────────────────────────
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

if [ -d "$INPUT" ]; then
  if [ ! -f "$INPUT/index.html" ]; then
    die "Folder must contain index.html: $INPUT"
  fi
  cp -R "$INPUT"/* "$STAGE/"
else
  # Single file → stage as index.html
  cp "$INPUT" "$STAGE/index.html"
fi

ok "Staged $(find "$STAGE" -type f | wc -l | tr -d ' ') file(s) for deploy"

# ── Sensitive content scan ────────────────────────────────────────────────
SCAN_HITS=$(grep -irlE "ssn|social.?security|credit.?card|api.?key|secret.?key|password|bearer.?token" "$STAGE" 2>/dev/null || true)
if [ -n "$SCAN_HITS" ]; then
  warn "Sensitive keywords detected in:"
  echo "$SCAN_HITS" | sed 's/^/    /' >&2
  warn "Continuing — but verify the content does not actually contain secrets before sharing."
fi

# ── Public confirmation gate ──────────────────────────────────────────────
if [ "$POLICY" = "public" ]; then
  warn "PUBLIC DEPLOY: This URL will be openly accessible and indexable by search engines."
  if [ "$ASSUME_YES" = "true" ]; then
    info "Public deploy auto-confirmed (--assume-yes)"
  else
    printf "Proceed with public deploy? Type 'yes' to confirm: " >&2
    CONFIRM=""
    read -r CONFIRM || true
    [ "$CONFIRM" = "yes" ] || die "Aborted."
  fi
fi

# ── Deploy to Cloudflare Pages ────────────────────────────────────────────
if [ "$DRY_RUN" = "true" ]; then
  info "DRY RUN — skipping wrangler calls"
  PROD_URL="https://${PROJECT_NAME}.pages.dev"
  DEPLOY_URL="https://abc12345.${PROJECT_NAME}.pages.dev"
else
  info "Creating/verifying Pages project: $PROJECT_NAME"
  wrangler pages project create "$PROJECT_NAME" --production-branch main 2>/dev/null || true

  info "Deploying to Cloudflare Pages..."
  DEPLOY_OUTPUT=$(wrangler pages deploy "$STAGE" --project-name "$PROJECT_NAME" --commit-dirty=true 2>&1)

  if ! echo "$DEPLOY_OUTPUT" | grep -q "Deployment complete"; then
    err "Deploy failed:"
    echo "$DEPLOY_OUTPUT" >&2
    exit 1
  fi

  # Extract production URL (the canonical *.pages.dev alias, not the per-deploy hash)
  PROD_URL="https://${PROJECT_NAME}.pages.dev"
  DEPLOY_URL=$(echo "$DEPLOY_OUTPUT" | grep -oE "https://[a-f0-9]+\.${PROJECT_NAME}\.pages\.dev" | head -1)
fi

# ── Apply Access policy ───────────────────────────────────────────────────
AUTH_POSTURE=""
ACCESS_NEXT=""

case "$POLICY" in
  default)
    if [ "$MODE" = "org" ]; then
      info "Applying Access policy: @samba.com / @samba.tv only"
      if [ "$DRY_RUN" = "false" ]; then
        bash "$(dirname "$0")/apply-access-policy.sh" \
          --domain "${PROJECT_NAME}.pages.dev" \
          --policy default \
          || warn "Access policy automation failed — apply manually in dashboard"
      fi
      AUTH_POSTURE="🔒 Gated to @samba.com / @samba.tv (Google SSO required)"
    else
      AUTH_POSTURE="⚠ NOT YET GATED — currently public"
      ACCESS_NEXT="Apply @samba.com / @samba.tv gate manually:
    1. Open https://one.dash.cloudflare.com → Access → Applications → Add
    2. Type: Self-hosted | Domain: ${PROJECT_NAME}.pages.dev
    3. IDP: Google (one-time OAuth setup)
    4. Policy: Allow → Emails ending in @samba.com / @samba.tv
    Takes ~3 minutes."
    fi
    ;;
  allowlist)
    if [ "$MODE" = "org" ]; then
      info "Applying Access policy: allowlist ($ALLOWLIST)"
      if [ "$DRY_RUN" = "false" ]; then
        bash "$(dirname "$0")/apply-access-policy.sh" \
          --domain "${PROJECT_NAME}.pages.dev" \
          --policy allowlist \
          --emails "$ALLOWLIST" \
          || warn "Access policy automation failed — apply manually"
      fi
      AUTH_POSTURE="🔒 Gated to: $ALLOWLIST"
    else
      AUTH_POSTURE="⚠ NOT YET GATED — apply allowlist in dashboard"
      ACCESS_NEXT="Apply allowlist for [$ALLOWLIST] manually in CF dashboard."
    fi
    ;;
  public)
    AUTH_POSTURE="🌐 PUBLIC — anyone with the link can view"
    ;;
esac

# ── Output ────────────────────────────────────────────────────────────────
echo
ok "Deploy complete"
echo
printf "%b%s%b\n" "$C_BOLD" "URL:        $PROD_URL" "$C_RESET"
printf "%bAuth:       %s%b\n" "$C_BOLD" "$AUTH_POSTURE" "$C_RESET"
printf "%bDeploy ID:  %s%b\n" "$C_DIM" "$DEPLOY_URL" "$C_RESET"
echo

if [ -n "$ACCESS_NEXT" ]; then
  printf "%bNext step:%b\n%s\n\n" "$C_YELLOW" "$C_RESET" "$ACCESS_NEXT"
fi

# Sharing snippet
echo "─── Sharing snippet (paste into Slack/email) ───"
case "$POLICY" in
  default)
    cat <<EOF
Sharing this internally — gated to @samba.com / @samba.tv SSO:
$PROD_URL

(You'll get a Google login challenge first; use your @samba.com / @samba.tv account.)
EOF
    ;;
  allowlist)
    cat <<EOF
Sharing this with you specifically — link gated to your email:
$PROD_URL

(Sign in with the email I added to the allowlist when prompted.)
EOF
    ;;
  public)
    cat <<EOF
Public link:
$PROD_URL
EOF
    ;;
esac
echo "──────────────────────────────────────────────"
echo

# To update content later: rerun the same command, URL stays stable
log "Update later: rerun the same command — same URL, fresh content."

# ---------------- record to shipped manifest ----------------
# Append/update entry in beru-workspace/3-Resources/shipped/manifest.json.
# Failure is non-fatal — deploy already succeeded.
RECORDER="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../../../.." && pwd)}/beru-workspace/3-Resources/shipped/record-deploy.mjs"
if [[ -f "$RECORDER" ]]; then
  case "$POLICY" in
    default)   GATING="@samba.com / @samba.tv SSO" ;;
    allowlist) GATING="Cloudflare Access allowlist" ;;
    public)    GATING="public" ;;
    *)         GATING="unknown" ;;
  esac
  SRC="${1:-}"
  if [[ "$SRC" = /* ]]; then
    REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
    SRC="${SRC#$REPO_ROOT/}"
  fi
  node "$RECORDER" \
    --id "$PROJECT_NAME" \
    --title "$PROJECT_NAME" \
    --url "$PROD_URL" \
    --platform "cloudflare-pages" \
    --source-path "$SRC" \
    --gating "$GATING" \
    || echo "⚠ failed to update shipped manifest (deploy still succeeded)"
fi
