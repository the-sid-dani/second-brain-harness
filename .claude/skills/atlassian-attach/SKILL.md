---
name: atlassian-attach
description: Upload files (screenshots, diagrams, PDFs, exported designs) as attachments to a Jira issue or a Confluence page. Works for either target — pick the subcommand. Uses Atlassian REST API directly via Python urllib + multipart — the official Atlassian MCP has no attachment-upload tools, so this skill exists to fill that hole. Auth via ATLASSIAN_BASIC_AUTH env var (classic API token only — scoped tokens cannot upload). Use whenever the user wants to add an image, screenshot, design export, or any binary file to an existing Jira ticket or Confluence page — phrases like "attach this screenshot to PROJ-450", "upload my-diagram.png to the design page", "add this PDF to the ticket", "embed this image in Confluence". Pairs naturally with `/confluence-publish-markdown` (which embeds external URLs only — no native upload) and with `/scaffold-engineering-project` (when slice descriptions need supporting images).
---

# atlassian-attach

Fills the one gap the rest of the Atlassian skill suite leaves open. `/confluence-publish-markdown` deliberately uses external URLs (mermaid.ink) instead of uploads because scoped tokens can't push attachments. `/jira-decompose-epic` creates tickets with text-only bodies. The MCP surface (30+ tools) has zero attachment-upload tools. When the user actually has a binary file they want into Atlassian, **this skill is the path**.

The skill is a thin one-script wrapper over `POST /rest/api/2/issue/{key}/attachments` (Jira) and `POST /wiki/rest/api/content/{pageId}/child/attachment` (Confluence). Pure stdlib — no `pip install`. Multipart constructed by hand for full control.

## When this triggers

Use this skill when:
- The user has a local file (PNG, JPG, SVG, PDF, ZIP, anything) and wants it as an attachment on a Jira issue OR a Confluence page
- The file is small-to-medium — Atlassian Cloud's hard limit is ~100MB per upload
- The user has the issue key or page ID (Confluence page IDs are numeric, in the page URL)

Do NOT use this skill when:
- You want to embed a remote image via URL — use `/confluence-publish-markdown` with a mermaid block or external image URL instead
- The user wants to attach to a Jira COMMENT (different endpoint — `/rest/api/2/issue/{key}/comment/{id}/attachments` isn't an Atlassian API, comments don't have attachments separately from the parent issue)
- The user is uploading from an HTTPS URL not on disk — they should `curl` it down first, then attach

## Workflow

### Step 1 — Confirm target + files

The user says "attach `~/screenshot.png` to `PROJ-450`" or "upload this PDF to the design page (ID 12345678)". Two values needed:

- **Subcommand:** `jira` or `confluence`
- **Target:** issue key (`PROJ-450`) for Jira, numeric page ID (`12345678`) for Confluence
- **File(s):** one or more local paths

Multiple files in one invocation work — they upload to the same target in a single multipart POST.

If <assistant.name> doesn't know the Confluence page ID, ask the user to open the page in a browser — the ID is in the URL: `.../wiki/spaces/SPACE/pages/<PAGE_ID>/Title`.

### Step 2 — Run the script

```
python3 .claude/skills/atlassian-attach/scripts/attach.py jira <ISSUE-KEY> <file> [<file>...]
python3 .claude/skills/atlassian-attach/scripts/attach.py confluence <PAGE-ID> <file> [<file>...] [--comment "version note"] [--minor-edit]
```

The script:
1. Pre-flight: confirms every file exists and is readable
2. Resolves `ATLASSIAN_BASIC_AUTH` from env (sys.exit with a clear message if missing)
3. Builds multipart/form-data body in memory (uuid-based boundary, `Content-Disposition: form-data; name="file"; filename="..."`)
4. POSTs with `Authorization: Basic <token>` + `X-Atlassian-Token: no-check` (required by Atlassian to bypass XSRF)
5. On success, prints one line per attachment: filename → permalink URL
6. On failure, prints HTTP status + a hint specific to common errors (401 / 403 / 404 / 413)

### Step 3 — Verify

Open the target in a browser and confirm the attachment shows up. For Jira, attachments appear in the right-side panel under "Attachments". For Confluence, they appear at the bottom of the page under "Attachments" (you may need to click "Show all" if the page has many).

## Auth

`ATLASSIAN_BASIC_AUTH` env var, base64'd `email:api_token`, auto-loaded via `~/.zshrc` → `~/.second-brain-os.env`.

**Must be a CLASSIC API token, not a scoped/granular one.** Scoped tokens lack the `write:attachment` scope and return HTTP 403 on the upload endpoint with a confusingly generic error body. Classic tokens carry full user permissions including attachments.

Generate at: [id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens) → **Create classic API token**. There's no security downside vs scoped — both revoke from the same page.

Setup steps documented in `samba-onboarding/README.md` under "Power-user — Atlassian API token."

## Endpoints

| Target | Endpoint | Verb | Success |
|--------|----------|------|---------|
| Jira issue attachment | `/rest/api/2/issue/{KEY}/attachments` | POST (multipart) | 200 + array of attachment objects |
| Confluence page attachment | `/wiki/rest/api/content/{PAGE_ID}/child/attachment` | POST (multipart) | 200 or 201 + `{results: [attachment...]}` |

Both require:
- `Authorization: Basic <base64>` header
- `X-Atlassian-Token: no-check` header (otherwise Atlassian's XSRF check rejects)
- `Content-Type: multipart/form-data; boundary=<boundary>`
- One or more `Content-Disposition: form-data; name="file"; filename="..."` parts

Confluence additionally accepts optional `comment` and `minorEdit` form fields (handled by the `--comment` / `--minor-edit` flags).

## Why not the MCP

The official Atlassian remote MCP at `mcp.atlassian.com/v1/mcp` (branded "Atlassian Rovo MCP") exposes ~30 tools — `createJiraIssue`, `editJiraIssue`, `transitionJiraIssue`, `getJiraIssue`, `searchJiraIssuesUsingJql`, `addCommentToJiraIssue`, `createConfluencePage`, `updateConfluencePage`, `addCommentToConfluencePage`, `getConfluencePage`, `searchConfluenceUsingCql`, etc. — but **none for attachment upload**. The MCP surface is text/structured-data only; binary upload requires REST direct. Verified via the deferred-tools list at session start.

## File-size limits

Atlassian Cloud's default per-file attachment limit is **~100 MB**. Larger files return HTTP 413. The skill checks file sizes pre-flight only for the error message; it doesn't pre-reject — Atlassian could change the limit at any time and the response is the source of truth.

## Why not the MCP fallback that `/confluence-publish-markdown` uses

`/confluence-publish-markdown` has a `mcp__atlassian__createConfluencePage` fallback for the create-page case when scoped tokens reject `POST /wiki/api/v2/pages` with a 404. That fallback works because creating a page IS in the MCP surface. There's no equivalent MCP fallback for attachments because the MCP doesn't expose any attachment endpoint. Either the classic API token works (you're done) or there's no fallback path — flagging this explicitly so future-you doesn't waste time looking for one.

## Idempotency

**This skill is NOT idempotent.** Re-running it uploads a duplicate attachment with the same filename. Atlassian deduplicates by content for visual display in the UI but stores both physically. If you re-run by mistake:

- Jira: delete extras from the attachments panel (right-side of the issue)
- Confluence: delete from "Attachments" at page bottom

To safely re-upload (e.g., updated version of a diagram), Confluence supports **`--comment "v2"` + `--minor-edit`** to add a new version of the same-filename attachment without notification. Jira has no equivalent — re-upload to Jira creates a duplicate every time. Delete the old one first if you care.

## Files in this skill

- `scripts/attach.py` — the workhorse. Pure-stdlib multipart POST to Jira or Confluence.
- `references/usage.md` — worked examples (Jira screenshot, Confluence diagram with version comment, multi-file upload).

## When this skill is the wrong tool

- **Embedding an image inline in a Confluence body** — use `/confluence-publish-markdown` with an external image URL (mermaid.ink for diagrams; or upload via this skill first, then reference the attachment URL in your markdown). Attached files render under "Attachments" by default; inline embedding requires the page body to reference the attachment URL.
- **Attaching to a Jira comment** — Jira doesn't have per-comment attachments; comments reference the parent issue's attachment list. Upload to the issue, then reference in the comment text.
- **Bulk-uploading across many tickets/pages** — script around this skill in a shell loop. Don't extend the skill itself to take an attachment-spec YAML — the surface stays narrow.
- **Updating an attachment's content vs uploading a new version** — Confluence handles via `--minor-edit` + `--comment`. Jira doesn't support versioning; delete + re-upload.
