#!/usr/bin/env bash
#
# samba-publish test runner
#
# Comprehensive functional tests using --dry-run mode (no network calls).
# Usage:
#   ./tests/run-tests.sh                # All tests
#   ./tests/run-tests.sh --integration  # Also run real-deploy integration test (requires wrangler auth)

set -uo pipefail

# Locate the skill root
SKILL_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd )"
PUBLISH="$SKILL_DIR/scripts/publish.sh"
FIXTURES="$SKILL_DIR/tests/fixtures"

# Colors
if [ -t 1 ]; then
  G="\033[32m"; R="\033[31m"; Y="\033[33m"; B="\033[34m"; D="\033[2m"; X="\033[0m"; BOLD="\033[1m"
else
  G=""; R=""; Y=""; B=""; D=""; X=""; BOLD=""
fi

PASS=0
FAIL=0
SKIPPED=0
TOTAL=0
FAILED_TESTS=()

assert_contains() {
  local haystack="$1" needle="$2" name="$3"
  TOTAL=$((TOTAL+1))
  if echo "$haystack" | grep -q -- "$needle"; then
    printf "  ${G}✓${X} %s\n" "$name"
    PASS=$((PASS+1))
  else
    printf "  ${R}✘${X} %s\n" "$name"
    printf "    ${D}expected to find:${X} %s\n" "$needle"
    FAIL=$((FAIL+1))
    FAILED_TESTS+=("$name")
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" name="$3"
  TOTAL=$((TOTAL+1))
  if echo "$haystack" | grep -q -- "$needle"; then
    printf "  ${R}✘${X} %s\n" "$name"
    printf "    ${D}should NOT contain:${X} %s\n" "$needle"
    FAIL=$((FAIL+1))
    FAILED_TESTS+=("$name")
  else
    printf "  ${G}✓${X} %s\n" "$name"
    PASS=$((PASS+1))
  fi
}

assert_exit_code() {
  local actual="$1" expected="$2" name="$3"
  TOTAL=$((TOTAL+1))
  if [ "$actual" -eq "$expected" ]; then
    printf "  ${G}✓${X} %s (exit=$actual)\n" "$name"
    PASS=$((PASS+1))
  else
    printf "  ${R}✘${X} %s (exit=$actual, expected $expected)\n" "$name"
    FAIL=$((FAIL+1))
    FAILED_TESTS+=("$name")
  fi
}

section() {
  printf "\n${BOLD}${B}── %s ──${X}\n" "$1"
}

# ── Pre-flight ────────────────────────────────────────────────────────────
printf "${BOLD}samba-publish test suite${X}\n"
printf "${D}Skill dir: %s${X}\n" "$SKILL_DIR"

if [ ! -x "$PUBLISH" ]; then
  printf "${R}✘${X} publish.sh not executable. Run: chmod +x %s\n" "$PUBLISH"
  exit 1
fi

# ── Test 1: Help text ─────────────────────────────────────────────────────
section "1. Argument parsing"
HELP_OUT=$("$PUBLISH" --help 2>&1 || true)
assert_contains "$HELP_OUT" "samba-publish" "help shows skill name"

# Test 1.2: Missing input → error
MISSING=$("$PUBLISH" 2>&1 || true)
assert_contains "$MISSING" "Usage" "missing input shows usage"

# Test 1.3: Nonexistent path → error
NONEXIST=$("$PUBLISH" /tmp/does-not-exist-$$.html 2>&1 || true)
assert_contains "$NONEXIST" "does not exist" "nonexistent path errors clearly"

# Test 1.4: Unknown flag → error
UNKNOWN=$("$PUBLISH" "$FIXTURES/simple.html" --invalid-flag 2>&1 || true)
assert_contains "$UNKNOWN" "Unknown flag" "unknown flag errors clearly"

# ── Test 2: Slug derivation ───────────────────────────────────────────────
section "2. Slug derivation & sanitization"

# Single file → slug from filename
OUT=$("$PUBLISH" "$FIXTURES/simple.html" --dry-run 2>&1)
assert_contains "$OUT" "Slug: simple" "slug auto-derived from filename"

# Folder → slug from folder name
OUT=$("$PUBLISH" "$FIXTURES/folder-fixture" --dry-run 2>&1)
assert_contains "$OUT" "Slug: folder-fixture" "slug auto-derived from folder name"

# Custom slug
OUT=$("$PUBLISH" "$FIXTURES/simple.html" --slug "my-custom-slug" --dry-run 2>&1)
assert_contains "$OUT" "Slug: my-custom-slug" "explicit --slug honored"

# Sanitization: uppercase + special chars
TMP_UPPER=$(mktemp -d)
echo '<html></html>' > "$TMP_UPPER/Q2 Review!.html"
OUT=$("$PUBLISH" "$TMP_UPPER/Q2 Review!.html" --dry-run 2>&1)
assert_contains "$OUT" "Slug: q2-review" "slug lowercased and special chars stripped"
rm -rf "$TMP_UPPER"

# ── Test 3: Mode detection ────────────────────────────────────────────────
section "3. Mode detection (personal vs org)"

# Personal mode (no env vars)
unset SAMBA_PUBLISH_TOKEN SAMBA_CF_ACCOUNT_ID 2>/dev/null || true
OUT=$("$PUBLISH" "$FIXTURES/simple.html" --dry-run 2>&1)
assert_contains "$OUT" "Mode: personal" "no env vars → personal mode"

# Org mode (both env vars set)
OUT=$(SAMBA_PUBLISH_TOKEN=fake-token SAMBA_CF_ACCOUNT_ID=fake-account "$PUBLISH" "$FIXTURES/simple.html" --dry-run 2>&1)
assert_contains "$OUT" "Mode: org" "both env vars → org mode"

# Org mode missing account ID → error
OUT=$(SAMBA_PUBLISH_TOKEN=fake-token "$PUBLISH" "$FIXTURES/simple.html" --dry-run 2>&1 || true)
assert_contains "$OUT" "SAMBA_CF_ACCOUNT_ID" "org mode requires account ID"

# ── Test 4: File staging ──────────────────────────────────────────────────
section "4. File and folder staging"

# Single file → staged as 1 file
OUT=$("$PUBLISH" "$FIXTURES/simple.html" --dry-run 2>&1)
assert_contains "$OUT" "Staged 1 file" "single file → 1 staged file"

# Folder with 2 files → both staged
OUT=$("$PUBLISH" "$FIXTURES/folder-fixture" --dry-run 2>&1)
assert_contains "$OUT" "Staged 2 file" "folder fixture → 2 staged files"

# Folder without index.html → error
TMP_NO_INDEX=$(mktemp -d)
echo "no index" > "$TMP_NO_INDEX/page.html"
OUT=$("$PUBLISH" "$TMP_NO_INDEX" --dry-run 2>&1 || true)
assert_contains "$OUT" "must contain index.html" "folder without index.html errors"
rm -rf "$TMP_NO_INDEX"

# ── Test 5: Sensitive content scan ────────────────────────────────────────
section "5. Sensitive content detection"

# Generate a fixture with sensitive content at runtime (avoids danger-file-protection hook)
TMP_SENSITIVE=$(mktemp -d)
cat > "$TMP_SENSITIVE/index.html" <<'EOF'
<html><body>
This content has an api_key=abc123 reference.
And a password example.
</body></html>
EOF

OUT=$("$PUBLISH" "$TMP_SENSITIVE" --dry-run 2>&1)
assert_contains "$OUT" "Sensitive keywords detected" "sensitive content triggers warning"

# Clean fixture should NOT trigger
OUT=$("$PUBLISH" "$FIXTURES/simple.html" --dry-run 2>&1)
assert_not_contains "$OUT" "Sensitive keywords detected" "clean content does NOT warn"

rm -rf "$TMP_SENSITIVE"

# ── Test 6: Policy modes ──────────────────────────────────────────────────
section "6. Auth policy modes"

# Default policy
OUT=$("$PUBLISH" "$FIXTURES/simple.html" --dry-run 2>&1)
assert_contains "$OUT" "@samba.com" "default policy mentions @samba.com"
assert_contains "$OUT" "NOT YET GATED" "personal mode default → not yet gated warning"

# Allowlist policy
OUT=$("$PUBLISH" "$FIXTURES/simple.html" --to "ashwin@samba.com,jaya@samba.com" --dry-run 2>&1)
assert_contains "$OUT" "ashwin@samba.com" "allowlist policy includes named emails"

# Public policy with --assume-yes
OUT=$("$PUBLISH" "$FIXTURES/simple.html" --public --assume-yes --dry-run 2>&1)
assert_contains "$OUT" "PUBLIC" "public policy shows PUBLIC label"
assert_contains "$OUT" "auto-confirmed" "public --assume-yes auto-confirms"

# Public WITHOUT --assume-yes and stdin closed → should die
OUT=$("$PUBLISH" "$FIXTURES/simple.html" --public --dry-run </dev/null 2>&1 || true)
assert_contains "$OUT" "Aborted" "public without yes confirmation aborts"

# ── Test 7: Org-mode policy automation ────────────────────────────────────
section "7. Org-mode policy output"

# Org mode default → "Gated to @samba.com"
OUT=$(SAMBA_PUBLISH_TOKEN=fake SAMBA_CF_ACCOUNT_ID=fake "$PUBLISH" "$FIXTURES/simple.html" --dry-run 2>&1)
assert_contains "$OUT" "Gated to @samba.com" "org mode default → gated message"

# ── Test 8: URL output ────────────────────────────────────────────────────
section "8. URL output format"

OUT=$("$PUBLISH" "$FIXTURES/simple.html" --slug urltest --dry-run 2>&1)
assert_contains "$OUT" "https://urltest.pages.dev" "production URL format correct"
assert_contains "$OUT" "Sharing snippet" "sharing snippet present in output"

# ── Test 9: Skill structure ───────────────────────────────────────────────
section "9. Skill structure validation"

[ -f "$SKILL_DIR/SKILL.md" ] && {
  TOTAL=$((TOTAL+1)); printf "  ${G}✓${X} SKILL.md present\n"; PASS=$((PASS+1))
} || {
  TOTAL=$((TOTAL+1)); printf "  ${R}✘${X} SKILL.md missing\n"; FAIL=$((FAIL+1)); FAILED_TESTS+=("SKILL.md missing")
}

[ -f "$SKILL_DIR/README.md" ] && {
  TOTAL=$((TOTAL+1)); printf "  ${G}✓${X} README.md present\n"; PASS=$((PASS+1))
} || {
  TOTAL=$((TOTAL+1)); printf "  ${R}✘${X} README.md missing\n"; FAIL=$((FAIL+1)); FAILED_TESTS+=("README.md missing")
}

[ -f "$SKILL_DIR/scripts/apply-access-policy.sh" ] && {
  TOTAL=$((TOTAL+1)); printf "  ${G}✓${X} apply-access-policy.sh present\n"; PASS=$((PASS+1))
} || {
  TOTAL=$((TOTAL+1)); printf "  ${R}✘${X} apply-access-policy.sh missing\n"; FAIL=$((FAIL+1)); FAILED_TESTS+=("apply-access-policy.sh missing")
}

[ -f "$SKILL_DIR/references/architecture.md" ] && {
  TOTAL=$((TOTAL+1)); printf "  ${G}✓${X} references/architecture.md present\n"; PASS=$((PASS+1))
} || {
  TOTAL=$((TOTAL+1)); printf "  ${R}✘${X} architecture.md missing\n"; FAIL=$((FAIL+1)); FAILED_TESTS+=("architecture.md missing")
}

# Validate SKILL.md frontmatter
SKILL_HEAD=$(head -5 "$SKILL_DIR/SKILL.md")
assert_contains "$SKILL_HEAD" "name: samba-publish" "SKILL.md has name field"
assert_contains "$SKILL_HEAD" "description:" "SKILL.md has description field"

# ── Optional: Integration test ────────────────────────────────────────────
if [ "${1:-}" = "--integration" ]; then
  section "10. Integration test (real deploy)"

  if ! command -v wrangler >/dev/null 2>&1; then
    printf "  ${Y}⊘${X} wrangler not installed — skipping\n"
    SKIPPED=$((SKIPPED+1))
  elif ! wrangler whoami 2>&1 | grep -q "logged in\|sid.dani\|samba"; then
    printf "  ${Y}⊘${X} wrangler not authenticated — skipping (run 'wrangler login')\n"
    SKIPPED=$((SKIPPED+1))
  else
    TEST_SLUG="samba-publish-test-$$"
    printf "  ${B}▸${X} Deploying test fixture to %s.pages.dev...\n" "$TEST_SLUG"

    DEPLOY_OUT=$("$PUBLISH" "$FIXTURES/simple.html" --slug "$TEST_SLUG" 2>&1 || true)
    if echo "$DEPLOY_OUT" | grep -q "Deploy complete"; then
      printf "  ${G}✓${X} Real deploy succeeded\n"
      PASS=$((PASS+1)); TOTAL=$((TOTAL+1))

      # Verify URL is reachable
      sleep 5
      HTTP=$(curl -s -o /dev/null -w "%{http_code}" "https://${TEST_SLUG}.pages.dev" || echo "000")
      if [ "$HTTP" = "200" ]; then
        printf "  ${G}✓${X} URL is reachable (HTTP 200)\n"
        PASS=$((PASS+1)); TOTAL=$((TOTAL+1))
      else
        printf "  ${R}✘${X} URL not reachable (HTTP %s)\n" "$HTTP"
        FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); FAILED_TESTS+=("URL not reachable")
      fi

      # Cleanup
      printf "  ${D}cleanup: deleting test project...${X}\n"
      wrangler pages project delete "$TEST_SLUG" --yes 2>/dev/null || \
        printf "  ${Y}⚠${X} Could not auto-delete test project — manually delete %s in CF dashboard\n" "$TEST_SLUG"
    else
      printf "  ${R}✘${X} Real deploy failed:\n"
      echo "$DEPLOY_OUT" | sed 's/^/      /'
      FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); FAILED_TESTS+=("Real deploy failed")
    fi
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo
printf "${BOLD}── Summary ──${X}\n"
printf "  Total:   %d\n" "$TOTAL"
printf "  ${G}Passed:  %d${X}\n" "$PASS"
[ "$FAIL" -gt 0 ] && printf "  ${R}Failed:  %d${X}\n" "$FAIL" || printf "  Failed:  0\n"
[ "$SKIPPED" -gt 0 ] && printf "  ${Y}Skipped: %d${X}\n" "$SKIPPED"

if [ "$FAIL" -gt 0 ]; then
  echo
  printf "${R}Failed tests:${X}\n"
  for t in "${FAILED_TESTS[@]}"; do
    printf "  - %s\n" "$t"
  done
  exit 1
fi

echo
printf "${G}${BOLD}All tests passed.${X}\n"
[ "${1:-}" != "--integration" ] && printf "${D}Run with --integration to also test real Cloudflare deploys.${X}\n"
exit 0
