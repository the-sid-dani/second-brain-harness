# samba-publish — Architecture Reference

## System overview

```
┌────────────────────────────────────────────────────────────────────┐
│                    EMPLOYEE WORKSPACE                              │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Claude Code session                                        │   │
│  │  User invokes: /samba:publish ./report.html                 │   │
│  │  Skill loads: SKILL.md → publish.sh                         │   │
│  └─────────────────────────────┬───────────────────────────────┘   │
└────────────────────────────────┼───────────────────────────────────┘
                                 │
                                 │  wrangler deploy
                                 │  + (org mode) CF API for Access
                                 ↓
┌────────────────────────────────────────────────────────────────────┐
│                  CLOUDFLARE ORG ACCOUNT (Samba TV)                 │
│  ┌──────────────────────────┐  ┌─────────────────────────────┐     │
│  │ Cloudflare Pages         │  │ Cloudflare Access (Zero     │     │
│  │ Project: samba-publish   │  │ Trust)                       │    │
│  │ Custom domain:           │  │ IDP: Google Workspace OIDC  │     │
│  │   publish.samba.com      │  │ Default policy:             │     │
│  │ Stores: HTML artifacts   │  │   email ends with @samba.com│     │
│  └──────────────────────────┘  └─────────────────────────────┘     │
└────────────────────────────────────────────────────────────────────┘
                                 ↑
                                 │  SSO challenge on view
                                 │
┌────────────────────────────────┼───────────────────────────────────┐
│                  VIEWER (any Samba employee)                       │
│  Opens https://q2-review.publish.samba.com                         │
│  → redirected to Google login                                      │
│  → @samba.com? allowed in. Else? denied.                           │
└────────────────────────────────────────────────────────────────────┘
```

## Component breakdown

### 1. The skill (this directory)
Lives in `.claude/skills/samba-publish/`. Distributed via the `claude-onboarding` plugin or a dedicated `samba-publish` plugin. SKILL.md is the entry point Claude reads.

### 2. The publish script (`scripts/publish.sh`)
Bash implementation. Wraps `wrangler pages deploy` with:
- Input validation
- Slug derivation
- Mode detection (personal vs org)
- Stage directory management
- Sensitive content scanning
- Public-deploy confirmation gate
- Output formatting (URL, auth posture, sharing snippet)

### 3. The Access policy helper (`scripts/apply-access-policy.sh`)
Org-mode only. Calls Cloudflare API to:
- Create or update an Access application for the deployed domain
- Apply an Allow policy (default `@samba.com` or specific allowlist)
- Returns success/failure to the caller

### 4. Cloudflare infra (Samba-owned, set up by IT)
- One **Pages project** (`samba-publish`) — destination for all deploys
- One **custom domain** (`publish.samba.com`) — branded URL
- One **Access application** per deploy slug (auto-created by skill)
- One **Identity Provider** (Google Workspace via OIDC)
- One **service token** (CF API token, stored in employee env or org-managed secret)

## Mode detection

```bash
if [ -n "$SAMBA_PUBLISH_TOKEN" ] && [ -n "$SAMBA_CF_ACCOUNT_ID" ]; then
  MODE="org"
else
  MODE="personal"
fi
```

| Mode | Auth | Project | URL | Access policy |
|---|---|---|---|---|
| Personal | wrangler OAuth | `<slug>` (per-deploy) | `<slug>.pages.dev` | Manual via dashboard |
| Org | service token | `samba-publish` (shared) | `<slug>.publish.samba.com` | Auto via CF API |

## IT setup checklist (one-time, ~45 min)

### Step 1: Cloudflare account
1. Create Cloudflare account for Samba TV (or use existing)
2. Note the Account ID — needed for `SAMBA_CF_ACCOUNT_ID`

### Step 2: DNS delegation
1. In Route 53 (samba.com hosted zone), add NS records for `publish.samba.com` pointing at Cloudflare's nameservers
2. Verify propagation: `dig publish.samba.com NS +short`

### Step 3: Create Pages project
```bash
wrangler pages project create samba-publish --production-branch main
```

### Step 4: Bind custom domain
1. Cloudflare dashboard → Pages → `samba-publish` → Custom domains → Add
2. Enter `publish.samba.com`
3. Cloudflare auto-issues SSL cert

### Step 5: Configure Cloudflare Access
1. Zero Trust dashboard → Settings → set team name (e.g., `samba`)
2. Identity → Add Identity Provider → Google Workspace
   - Use OAuth or SAML/OIDC depending on Samba's IT preference
   - Restrict to `samba.com` domain
3. Access → Applications → Add → Self-hosted
   - Domain: `*.publish.samba.com` (wildcard for all deploys)
   - Identity: Google Workspace
   - Policy: Allow if email ends with `@samba.com`

### Step 6: Generate API token
1. My Profile → API Tokens → Create Token → Custom token
2. Permissions:
   - Account → Cloudflare Pages → Edit
   - Account → Access: Apps and Policies → Edit
3. Account Resources: include the Samba TV account
4. TTL: 1 year, rotate annually
5. Distribute via secure secret manager (1Password, AWS Secrets Manager, or env var in plugin config)

### Step 7: Distribute skill
1. Bundle into the existing `claude-onboarding` plugin (or new `samba-publish` plugin)
2. Push to Samba's claude marketplace
3. Document install: `/plugin install samba-publish`

## Security model

### Defense layers
1. **Sensitive content scan** — script greps deploy directory for keywords (ssn, api_key, password, etc.) and warns before upload
2. **Default-secure auth** — `@samba.com` gate is the *default*, public requires `--public` flag + typed confirmation
3. **No customer data** — acceptable use policy explicitly excludes customer PII, contracts, source code
4. **Service token scope** — CF token only has Pages + Access edit; can't touch DNS, Workers, R2, etc.
5. **Audit trail** — every deploy logged in Cloudflare with username (from token metadata), timestamp, content hash
6. **Time-to-live** — deploys auto-archive after 90 days of no access (configurable via cron + CF API)
7. **Revocation** — IT or content owner can delete any deploy in <30 seconds via dashboard or `wrangler pages deployment delete`

### Threat model

| Threat | Mitigation |
|---|---|
| Employee accidentally publishes secrets | Sensitive content scan + visible auth posture in output |
| Employee publishes public when meant private | `--public` requires typed confirmation; default is gated |
| Service token leaks | Limited scope (Pages + Access only), TTL'd, rotatable |
| Unauthorized viewer | Cloudflare Access Google SSO; only `@samba.com` allowed by default |
| Stale URLs leaking after employee leaves | 90-day auto-archive; org admins can bulk-delete |
| Customer data exposure | AUP forbids; content scan; manual review for sensitive deploys |
| MITM on view | Cloudflare-issued SSL cert; HTTPS only |

### What this is NOT for
- Customer-facing pages (use Vercel or marketing site infra)
- Code repositories (use GitHub Pages internal repos)
- Long-lived dashboards needing real-time data (use Lakeview or Looker)
- Anything requiring server-side rendering (this is static-only)
- Files containing PII, credentials, contracts, source code

## Cost model

### Free tier limits (Cloudflare)
- Pages: unlimited bandwidth, unlimited requests
- Pages: 500 builds/month per project (re-deploys count, but a single project shared across all employees scales fine)
- Zero Trust Free: up to 50 users
- Custom domains: unlimited

### Paid tier triggers
- **>50 users:** Cloudflare Zero Trust Standard at ~$3/user/month
- **Custom build environments:** if we ever need more than the default Node/Python builders
- **Worker functions:** if we add server-side processing (currently not needed)

### Forecast at company scale

| Users | Monthly cost | Notes |
|---|---|---|
| 1–50 (early adopters) | $0 | Free tier covers everything |
| 50–250 (full company) | ~$150–750 | Zero Trust Standard kicks in |
| 250+ (growth) | $3/user/mo for ZT | Pages stays free |

## Future enhancements

- **Per-deploy TTL flag** (`--ttl 30d`) for ephemeral content
- **Slack integration** — auto-post to a thread when a deploy completes
- **Versioning UI** — rollback to a previous deploy from a CLI command
- **Templates** — `--template briefing` scaffolds a clean HTML shell
- **Analytics** — view counts, referrers via Cloudflare Analytics API
- **Wildcard subdomain per user** — `<user>.publish.samba.com` (more complex, optional)

## Related artifacts

- IT pitch one-pager: `beru-workspace/1-Projects/2026-05-publish-samba-platform/it-pitch-one-pager.md`
- Project status: `beru-workspace/1-Projects/2026-05-publish-samba-platform/README.md`
- Demo deployment: `https://sid-projects.pages.dev` (the projects-overview page that started this)
