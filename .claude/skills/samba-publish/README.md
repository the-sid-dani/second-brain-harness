# samba-publish

Deploy static HTML to a Samba-internal URL with `@samba.com` / `@samba.tv` SSO gating, in one command.

## What it does

Turns any HTML file or static site folder into a Cloudflare Pages deployment, gated by default to `@samba.com` and `@samba.tv` Google Workspace accounts. Built for internal artifacts: briefings, prototypes, dashboards, exec snapshots, project pages.

## Quick start

### As a Claude Code skill

Just say what you want:
- "Publish this report to a Samba URL"
- "Deploy this HTML and gate it to Ashwin only"
- "Make this internal-only and shareable"

Claude routes to the `samba-publish` skill, asks for confirmation, runs the script.

### Direct CLI

```bash
# Default — gated to @samba.com / @samba.tv
.claude/skills/samba-publish/scripts/publish.sh ./report.html

# Specific allowlist
.claude/skills/samba-publish/scripts/publish.sh ./offer.html --to ashwin@samba.tv

# Public (rare, requires confirmation)
.claude/skills/samba-publish/scripts/publish.sh ./marketing.html --public

# Folder with custom slug
.claude/skills/samba-publish/scripts/publish.sh ./site/ --slug q2-board-deck
```

## Prerequisites

1. **wrangler installed** — `npm install -g wrangler`
2. **wrangler authenticated** — `wrangler login` (opens browser)
3. *(Org mode only)* `SAMBA_PUBLISH_TOKEN` and `SAMBA_CF_ACCOUNT_ID` env vars set

## Modes

### Personal mode (default)
- Uses your Cloudflare OAuth from `wrangler login`
- Deploys to your personal CF account
- URL: `https://<slug>.pages.dev`
- Access policy: must be applied manually in dashboard (script prints instructions)
- Use case: dogfooding before org infra exists

### Org mode (production)
- Uses Samba's service token via `SAMBA_PUBLISH_TOKEN` env var
- Deploys to org's `samba-publish` Pages project
- URL: `https://<slug>.publish.samba.com` (requires DNS setup)
- Access policy: applied automatically via API
- Use case: company-wide rollout

Mode is auto-detected: if `SAMBA_PUBLISH_TOKEN` is set → org mode, else → personal mode.

## Update flow

To update content on a published URL: run the same command again. Same project, same URL, fresh content. URL is stable.

```bash
# First publish
publish.sh ./report.html --slug q2-review
# → https://q2-review.pages.dev

# Edit ./report.html, then republish
publish.sh ./report.html --slug q2-review
# → https://q2-review.pages.dev (same URL, new content)
```

## Safety guardrails

- Sensitive keyword scan (`ssn`, `api_key`, `password`, etc.) before deploy — warns but doesn't block
- `--public` requires typed `yes` confirmation in same session
- Auth posture printed prominently in output
- All deploys logged in Cloudflare dashboard with timestamp + content hash

## Files

```
.claude/skills/samba-publish/
├── SKILL.md                       # Manifest read by Claude
├── README.md                      # This file
├── scripts/
│   ├── publish.sh                 # Main implementation
│   └── apply-access-policy.sh     # Org-mode Access policy automation
└── references/
    └── architecture.md            # Full architecture, IT setup, security model
```

## Architecture (production / org mode)

```
┌──────────────────────────────────────────────────────────┐
│  Cloudflare Org Account (Samba-owned)                    │
│  • Pages project: samba-publish                          │
│  • Domain: publish.samba.com                             │
│  • Default Access policy: @samba.com via Google SSO      │
│  • API service token in SAMBA_PUBLISH_TOKEN              │
└──────────────────────────────────────────────────────────┘
                        ↑ API calls
┌───────────────────────┴──────────────────────────────────┐
│  /samba:publish — this skill                             │
│  Distributed via claude-onboarding plugin                │
│  Employees install once, no per-user CF account needed   │
└──────────────────────────────────────────────────────────┘
```

See `references/architecture.md` for the full picture, IT setup steps, and governance model.

## Support

- Skill maintainer: <fork as needed>
- Pitch / strategic context: `beru-workspace/1-Projects/2026-05-publish-samba-platform/it-pitch-one-pager.md`
- Issues / questions: ping `#ai-enablement` Slack channel
