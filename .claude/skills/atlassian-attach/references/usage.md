# atlassian-attach — usage examples

Concrete invocations for the four most common patterns. Run from any directory; the script lives at `.claude/skills/atlassian-attach/scripts/attach.py`.

## 1 — Attach a screenshot to a Jira issue

```bash
python3 .claude/skills/atlassian-attach/scripts/attach.py jira PROJ-450 ~/Downloads/screenshot.png
```

Output:
```
✓ screenshot.png → https://acme.atlassian.net/rest/api/2/attachment/content/{id}
```

The `content` URL is the permalink — it lives on the issue and is referenced by ID. Use it in subsequent code or comments by linking to that URL.

## 2 — Attach a diagram to a Confluence page with a version comment

```bash
python3 .claude/skills/atlassian-attach/scripts/attach.py confluence 12345678 ~/Desktop/architecture-v2.svg \
    --comment "Updated for the SF dual-region rollout" \
    --minor-edit
```

Output:
```
✓ architecture-v2.svg → https://acme.atlassian.net/wiki/download/attachments/12345678/architecture-v2.svg?...
```

`--minor-edit` suppresses email notifications to page watchers. Drop it if you want them to see the new version.

To find the page ID: open the page in a browser. The URL is `.../wiki/spaces/SPACE/pages/<PAGE_ID>/Title`. The numeric segment after `pages/` is what you pass to `--page-id`.

## 3 — Multi-file upload (shell glob)

```bash
python3 .claude/skills/atlassian-attach/scripts/attach.py jira PROJ-450 ~/Downloads/screenshots/*.png
```

All matching files are uploaded in a single multipart POST. Atlassian returns an array; the script prints one line per file. If even one file is missing or unreadable, the whole upload is aborted before sending (pre-flight check).

## 4 — Different Atlassian instance (override the default)

```bash
ATLASSIAN_INSTANCE=othercorp python3 .claude/skills/atlassian-attach/scripts/attach.py jira PROJ-100 ./file.pdf
```

Or pass `--instance othercorp`. Defaults to whatever `ATLASSIAN_INSTANCE` env var is set to (or pass `--instance <name>` on the CLI). Useful when running against multiple Atlassian Cloud tenants in the same session.

## When it fails

The script returns specific guidance for the four most common error codes:

| Status | Likely cause | What to do |
|--------|--------------|------------|
| 401 | Token is scoped/granular, not classic | Regenerate at id.atlassian.com → "Create classic API token" |
| 403 | Token lacks attachment-write permission OR scoped token | Same fix as 401, or check that your account has edit permission on the resource |
| 404 | Wrong issue key / page ID | Double-check the key (`PROJ-450` not `aitf-450`) or the page ID (numeric, from URL) |
| 413 | File > ~100MB | Atlassian Cloud's per-attachment limit — split the file or upload to a different service and link |

For anything else, the script prints the first 500 chars of Atlassian's response body — usually has a clear reason.

## Composition with other Atlassian skills

```
/jira-decompose-epic  →  creates PROJ-450 .. PROJ-456
                          ↓
/atlassian-attach jira PROJ-450 ~/screenshots/slice-a-mockup.png
                                                ↑
                                       fill in supporting media after creation

/confluence-publish-markdown  →  publishes design.md as page 12345678
                                  ↓
/atlassian-attach confluence 12345678 ~/diagrams/architecture-v2.svg
                                                    ↑
                                                supporting media for the page

/scaffold-engineering-project  →  full hub + design + slices
                                   ↓
                            (post-scaffold) attach screenshots / diagrams
                                            to specific slices or the design page
```

The skill doesn't compose into the scaffold orchestrator automatically — it's a manual follow-up step after the scaffold creates the text content.
