# ⚠️ Samba-specific skill — adapt before fork use

This skill deploys to **publish.samba.com** with **@samba.com / @samba.tv** Google SSO gating. Non-Samba forks must adapt:
  - Replace `samba.com` / `samba.tv` with your company's email domain(s)
  - Replace `SAMBA_PUBLISH_TOKEN` env var with `${YOUR_COMPANY}_PUBLISH_TOKEN`
  - Replace `publish.samba.com` with your Cloudflare Pages project domain

Kept in v0.1.0 as a reference for SSO-gated static-site publishing. Genericized fork in a future release.

---

---
name: samba-publish
description: Deploys an HTML file or static site folder to Cloudflare Pages with @samba.com / @samba.tv SSO gating by default. Use this skill when the user wants to share an HTML artifact (briefing, dashboard, prototype, deck, exec snapshot, project page) as an internal URL with Samba employees only. Triggers on phrases like "publish this", "deploy this page", "share this with the team", "put this on a URL", "make this internal-only", "samba publish", "/samba:publish", or any request to create a shareable internal-company URL from a static HTML/site asset.
allowed-tools: Bash AskUserQuestion
---

# Samba Publish

Deploy static HTML to a Samba-internal URL with `@samba.com` / `@samba.tv` SSO gating in one command.

## Overview

Turns any HTML file or static site folder into a Cloudflare Pages deployment, gated by default to `@samba.com` and `@samba.tv` Google Workspace accounts. Built for internal artifacts: briefings, prototypes, dashboards, exec snapshots, project pages — anything you'd otherwise paste into Slack as a file or share as a Google Doc.

**Default flow (90% of cases):**
- Input: a local `.html` file or a folder containing `index.html`
- Output: `https://<slug>.pages.dev` gated to `@samba.com` / `@samba.tv` SSO
- Time: ~30 seconds

**Three policy modes:**
- `default` — `@samba.com` / `@samba.tv` email gate (Google SSO)
- `--public` — publicly accessible (requires confirmation)
- `--to email1,email2` — explicit allowlist of specific emails

## When to Use This Skill

Trigger this skill when:
- The user has an HTML file or static folder they want to share
- The user says "publish", "deploy", "make a URL for", "put this online"
- The user wants to share an internal artifact with Samba employees
- The user needs a shareable link for an exec or stakeholder

Do NOT trigger this skill for:
- Dynamic apps (Next.js, Node servers) — this is static-only
- Public marketing pages (use Vercel)
- Code repos (use GitHub Pages)
- Customer-facing content (needs separate review)

## Prerequisites Check (Run First)

Before invoking the publish script, verify the user's environment:

1. Run: `which wrangler` — must return a path (Cloudflare CLI installed)
2. Run: `wrangler whoami` — must show authenticated account
3. If either fails, instruct the user:
   - Install: `npm install -g wrangler`
   - Login: `wrangler login`
4. Check for org token: `echo $SAMBA_PUBLISH_TOKEN` — if set, skill operates in **org mode** (uses Samba's service token + applies Access policies via API). If unset, skill operates in **personal mode** (uses user's wrangler OAuth, requires manual Access setup in dashboard).

## Workflow

### Step 1: Confirm Intent and Inputs

Ask the user (or confirm from context):
- **Path:** Which file or folder to deploy? (must exist locally)
- **Slug:** What should the URL be? (auto-generated from filename if not specified, sanitized to lowercase-hyphen)
- **Audience:** `@samba.com` employees (default), specific emails, or public?

If the path is a single `.html` file, the script will stage it as `index.html` in a temp directory. If it's a folder, the folder must contain `index.html`.

### Step 2: Run the Publish Script

Invoke the implementation:

```bash
bash ${SKILL_DIR}/scripts/publish.sh <path> [--slug <slug>] [--public | --to <emails>]
```

Where `${SKILL_DIR}` is the directory containing this SKILL.md (typically `.claude/skills/samba-publish`).

The script will:
1. Validate inputs and environment
2. Stage the deploy directory
3. Create the Cloudflare Pages project if it doesn't exist
4. Run `wrangler pages deploy`
5. In org mode: apply the Access policy via Cloudflare API
6. In personal mode: print dashboard instructions for the user
7. Output: production URL, auth posture, and a sharing-ready snippet

### Step 3: Confirm and Share

After the script finishes, present the user with:
- **URL** to share
- **Auth posture** (who can see this)
- **Sharing snippet** they can paste into Slack/email
- **Edit instructions** (rerun the same command to update content; URL stays stable)

If the user invoked `--public`, **explicitly confirm before running** that they understand the page will be publicly accessible and indexable.

## Safety Rules

- **Never publish files containing customer PII, signed contracts, source code, or credentials.** If the script detects keywords like "ssn", "credit card", "api_key", "secret", warn the user.
- **Never use `--public` without explicit user confirmation in the same turn.** Public is opt-in only.
- **Never deploy without showing the final URL and auth posture to the user.** They need visibility into what just shipped.
- If `wrangler` or `curl` fails, surface the actual error message to the user — do not silently retry.

## Mode Detection

| Condition | Mode | Behavior |
|---|---|---|
| `SAMBA_PUBLISH_TOKEN` env var set | **Org mode** | Uses service token, applies Access policy via API, deploys to org's `samba-publish` project at `publish.samba.com` |
| `SAMBA_PUBLISH_TOKEN` not set | **Personal mode** | Uses wrangler OAuth, deploys to user's CF account at `<slug>.pages.dev`, prints dashboard URL for manual Access setup |

Org mode is the production architecture. Personal mode is for dogfooding before IT provisions the org account.

## References

- `references/architecture.md` — full architecture, security model, IT setup
- `scripts/publish.sh` — implementation
- `scripts/apply-access-policy.sh` — Access policy automation (org mode only)
- `README.md` — human-readable docs

## Examples

```bash
# Default: gate to @samba.com
/samba:publish ./quarterly-review.html
→ https://quarterly-review.pages.dev (gated to @samba.com)

# Specific allowlist
/samba:publish ./offer-letter.html --to ashwin@samba.com,jaya@samba.com

# Public (rare, requires confirmation)
/samba:publish ./marketing-page.html --public

# Custom slug
/samba:publish ./folder/ --slug q2-board-deck
→ https://q2-board-deck.pages.dev
```
