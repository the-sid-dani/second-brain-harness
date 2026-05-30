#!/usr/bin/env python3
"""attach.py — upload files as attachments to a Jira issue or a Confluence page.

Usage:
  attach.py jira <ISSUE-KEY> <file> [<file>...] [--instance <subdomain>]
  attach.py confluence <PAGE-ID> <file> [<file>...] [--instance <subdomain>]
                                                    [--comment TEXT] [--minor-edit]

Auth: ATLASSIAN_BASIC_AUTH env var (auto-loaded via ~/.zshrc → ~/.second-brain-os.env).
      Must be a CLASSIC API token — scoped/granular tokens cannot upload attachments.
      Generate a classic token at https://id.atlassian.com/manage-profile/security/api-tokens

Why this exists: the official Atlassian remote MCP exposes no attachment-upload
tools (verified by tools list inspection). REST direct is the only path.

Pure stdlib — no `pip install`. Matches the design of
.claude/skills/confluence-publish-markdown/scripts/publish_markdown.py and
.claude/skills/jira-decompose-epic/scripts/create_slices.py.
"""
from __future__ import annotations

import argparse
import json
import mimetypes
import os
import sys
import uuid
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError


DEFAULT_INSTANCE = os.environ.get("ATLASSIAN_INSTANCE", "")  # *.atlassian.net subdomain — set via env var or --instance flag


def _resolve_auth() -> str:
    auth = os.environ.get("ATLASSIAN_BASIC_AUTH")
    if not auth:
        sys.exit(
            "ATLASSIAN_BASIC_AUTH env var not set.\n"
            "Source ~/.second-brain-os.env or run from a fresh shell.\n"
            "Setup: generate a classic API token at https://id.atlassian.com/manage-profile/security/api-tokens"
        )
    return auth


def _base_url(instance: str) -> str:
    if not instance:
        sys.exit(
            "ERROR: Atlassian instance not set.\n"
            "  Set the ATLASSIAN_INSTANCE env var to your *.atlassian.net subdomain\n"
            "  (e.g. ATLASSIAN_INSTANCE=acme for acme.atlassian.net),\n"
            "  or pass --instance <name> on the command line."
        )
    return f"https://{instance}.atlassian.net"


def _build_multipart(files: list[Path], extra_fields: dict[str, str] | None = None) -> tuple[bytes, str]:
    """Build a multipart/form-data body from a list of files and optional fields.

    Returns (body_bytes, content_type_header).
    """
    boundary = f"----samba-{uuid.uuid4().hex}"
    chunks: list[bytes] = []
    for f in files:
        mime, _ = mimetypes.guess_type(f.name)
        mime = mime or "application/octet-stream"
        chunks.append(f"--{boundary}\r\n".encode())
        chunks.append(
            f'Content-Disposition: form-data; name="file"; filename="{f.name}"\r\n'.encode()
        )
        chunks.append(f"Content-Type: {mime}\r\n\r\n".encode())
        chunks.append(f.read_bytes())
        chunks.append(b"\r\n")
    for name, value in (extra_fields or {}).items():
        chunks.append(f"--{boundary}\r\n".encode())
        chunks.append(
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode()
        )
        chunks.append(str(value).encode())
        chunks.append(b"\r\n")
    chunks.append(f"--{boundary}--\r\n".encode())
    return b"".join(chunks), f"multipart/form-data; boundary={boundary}"


def _post_multipart(url: str, body: bytes, content_type: str, auth: str) -> tuple[int, bytes]:
    req = Request(url, data=body, method="POST")
    req.add_header("Authorization", f"Basic {auth}")
    # X-Atlassian-Token: no-check is required by Atlassian to bypass XSRF on
    # the attachment endpoints. Without it, the POST returns HTTP 403 with a
    # confusing "XSRF check failed" body that doesn't surface in most clients.
    req.add_header("X-Atlassian-Token", "no-check")
    req.add_header("Content-Type", content_type)
    try:
        with urlopen(req) as r:
            return r.status, r.read()
    except HTTPError as e:
        return e.code, e.read()
    except URLError as e:
        sys.exit(f"Network error: {e}")


def _handle_error(status: int, response: bytes, kind: str, target: str, files: list[Path]) -> None:
    body_preview = response.decode(errors="replace")[:500]
    hint = ""
    if status == 401:
        hint = (
            "\nAuth failed (HTTP 401). Is ATLASSIAN_BASIC_AUTH a CLASSIC API token?\n"
            "Scoped/granular tokens cannot upload attachments — regenerate at\n"
            "id.atlassian.com/manage-profile/security/api-tokens (Create classic API token)."
        )
    elif status == 403:
        hint = (
            "\nPermission denied (HTTP 403). Either:\n"
            "  - your token is scoped (classic API token needed), OR\n"
            "  - your account lacks edit permission on this resource, OR\n"
            "  - the X-Atlassian-Token header was missing (script sets it; only an issue if you modified the source)."
        )
    elif status == 404:
        kind_label = "issue key" if kind == "Jira" else "page ID"
        hint = (
            f"\n{kind} resource not found. Verify the {kind_label}: {target}\n"
            f"NOTE: Atlassian returns 404 for both 'doesn't exist' AND 'auth-fail' on Jira\n"
            f"issue endpoints (security through obscurity). If you're sure the {kind_label} is\n"
            f"correct, re-check ATLASSIAN_BASIC_AUTH (must be CLASSIC API token, not scoped)."
        )
    elif status == 413:
        sizes = ", ".join(f"{f.name}={f.stat().st_size // 1024}KB" for f in files)
        hint = f"\nFile too large (Atlassian Cloud limit is ~100MB per upload). Sizes: {sizes}"
    sys.exit(f"Upload failed (HTTP {status}):{hint}\n{body_preview}")


def attach_jira(issue_key: str, files: list[Path], instance: str) -> None:
    url = f"{_base_url(instance)}/rest/api/2/issue/{issue_key}/attachments"
    body, ct = _build_multipart(files)
    auth = _resolve_auth()
    status, response = _post_multipart(url, body, ct, auth)
    if status == 200:
        data = json.loads(response)
        for att in data:
            print(f"✓ {att['filename']} → {att['content']}")
        return
    _handle_error(status, response, "Jira", issue_key, files)


def attach_confluence(
    page_id: str,
    files: list[Path],
    instance: str,
    comment: str | None = None,
    minor_edit: bool = False,
) -> None:
    url = f"{_base_url(instance)}/wiki/rest/api/content/{page_id}/child/attachment"
    extra: dict[str, str] = {}
    if comment:
        extra["comment"] = comment
    if minor_edit:
        extra["minorEdit"] = "true"
    body, ct = _build_multipart(files, extra)
    auth = _resolve_auth()
    status, response = _post_multipart(url, body, ct, auth)
    if status in (200, 201):
        data = json.loads(response)
        for att in data.get("results", []):
            link = att.get("_links", {}).get("download", "")
            base = _base_url(instance)
            print(f"✓ {att['title']} → {base}/wiki{link}")
        return
    _handle_error(status, response, "Confluence", page_id, files)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Upload file(s) to a Jira issue or Confluence page.",
        epilog=(
            "Examples:\n"
            "  attach.py jira PROJ-450 ~/Downloads/screenshot.png\n"
            "  attach.py confluence 12345678 ~/Desktop/diagram.svg --comment 'v2'\n"
            "  attach.py jira PROJ-450 *.png  (shell-expanded multi-file)\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="target", required=True)

    jira_p = sub.add_parser("jira", help="Attach file(s) to a Jira issue")
    jira_p.add_argument("issue_key", help="e.g. PROJ-450")
    jira_p.add_argument("files", nargs="+", type=Path)
    jira_p.add_argument(
        "--instance",
        default=DEFAULT_INSTANCE,
        help="Atlassian subdomain (default: %(default)s; override via $ATLASSIAN_INSTANCE)",
    )

    conf_p = sub.add_parser("confluence", help="Attach file(s) to a Confluence page")
    conf_p.add_argument("page_id", help="Numeric page ID (visible in the page URL)")
    conf_p.add_argument("files", nargs="+", type=Path)
    conf_p.add_argument(
        "--instance",
        default=DEFAULT_INSTANCE,
        help="Atlassian subdomain (default: %(default)s; override via $ATLASSIAN_INSTANCE)",
    )
    conf_p.add_argument("--comment", help="Optional version-comment attached to the upload")
    conf_p.add_argument(
        "--minor-edit",
        action="store_true",
        help="Mark upload as a minor edit (suppresses watcher notifications)",
    )

    args = parser.parse_args()

    # Pre-flight: every file must exist + be readable.
    missing = [str(f) for f in args.files if not (f.exists() and f.is_file())]
    if missing:
        sys.exit(f"Files not found: {', '.join(missing)}")
    unreadable = [str(f) for f in args.files if not os.access(f, os.R_OK)]
    if unreadable:
        sys.exit(f"Files not readable: {', '.join(unreadable)}")

    if args.target == "jira":
        attach_jira(args.issue_key, args.files, args.instance)
    else:
        attach_confluence(
            args.page_id,
            args.files,
            args.instance,
            args.comment,
            args.minor_edit,
        )


if __name__ == "__main__":
    main()
