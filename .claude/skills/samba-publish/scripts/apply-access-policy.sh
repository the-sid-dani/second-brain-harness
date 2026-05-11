#!/usr/bin/env bash
#
# apply-access-policy.sh — Apply Cloudflare Access policy to a Pages deployment
#
# Org-mode helper. Requires SAMBA_PUBLISH_TOKEN (CF API token with Access:Edit scope)
# and SAMBA_CF_ACCOUNT_ID env vars.
#
# Usage:
#   apply-access-policy.sh --domain <domain> --policy default
#   apply-access-policy.sh --domain <domain> --policy allowlist --emails a@x.com,b@x.com

set -euo pipefail

DOMAIN=""
POLICY="default"
EMAILS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)  DOMAIN="$2"; shift 2 ;;
    --policy)  POLICY="$2"; shift 2 ;;
    --emails)  EMAILS="$2"; shift 2 ;;
    *)         echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

[ -z "$DOMAIN" ] && { echo "--domain required" >&2; exit 1; }
[ -z "${SAMBA_PUBLISH_TOKEN:-}" ] && { echo "SAMBA_PUBLISH_TOKEN env var required" >&2; exit 1; }
[ -z "${SAMBA_CF_ACCOUNT_ID:-}" ] && { echo "SAMBA_CF_ACCOUNT_ID env var required" >&2; exit 1; }

API="https://api.cloudflare.com/client/v4"
AUTH_HEADER="Authorization: Bearer $SAMBA_PUBLISH_TOKEN"

# Build policy payload
case "$POLICY" in
  default)
    INCLUDE='[{"email_domain":{"domain":"samba.com"}},{"email_domain":{"domain":"samba.tv"}}]'
    POLICY_NAME="Samba employees only"
    ;;
  allowlist)
    [ -z "$EMAILS" ] && { echo "--emails required for allowlist policy" >&2; exit 1; }
    INCLUDE=$(echo "$EMAILS" | tr ',' '\n' | sed 's/^/{"email":{"email":"/; s/$/"}}/' | paste -sd ',' -)
    INCLUDE="[$INCLUDE]"
    POLICY_NAME="Specific allowlist"
    ;;
  *)
    echo "Unknown policy: $POLICY" >&2; exit 1 ;;
esac

# 1. Create or update Access application
APP_PAYLOAD=$(cat <<EOF
{
  "name": "samba-publish: $DOMAIN",
  "domain": "$DOMAIN",
  "type": "self_hosted",
  "session_duration": "24h",
  "allowed_idps": []
}
EOF
)

echo "▸ Creating/updating Access application for $DOMAIN" >&2
APP_RESPONSE=$(curl -sS -X POST \
  "$API/accounts/$SAMBA_CF_ACCOUNT_ID/access/apps" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  --data "$APP_PAYLOAD")

APP_ID=$(echo "$APP_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$APP_ID" ]; then
  echo "Failed to create Access app:" >&2
  echo "$APP_RESPONSE" >&2
  exit 1
fi

# 2. Create the policy
POLICY_PAYLOAD=$(cat <<EOF
{
  "name": "$POLICY_NAME",
  "decision": "allow",
  "include": $INCLUDE
}
EOF
)

echo "▸ Applying policy: $POLICY_NAME" >&2
POLICY_RESPONSE=$(curl -sS -X POST \
  "$API/accounts/$SAMBA_CF_ACCOUNT_ID/access/apps/$APP_ID/policies" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  --data "$POLICY_PAYLOAD")

if echo "$POLICY_RESPONSE" | grep -q '"success":true'; then
  echo "✓ Access policy applied" >&2
else
  echo "Failed to apply policy:" >&2
  echo "$POLICY_RESPONSE" >&2
  exit 1
fi
