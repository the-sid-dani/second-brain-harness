#!/usr/bin/env python3
"""Port a local markdown file to a Confluence page (create or update).

Usage:
    # Create new child page under parent
    python publish_markdown.py --markdown <path> --parent-id <id> [--title <title>] \\
        [--header-config <yaml>] [--validate-only]

    # Update existing page (replace body)
    python publish_markdown.py --markdown <path> --page-id <id> [--title <title>] \\
        [--header-config <yaml>] [--validate-only]

Mermaid blocks (```mermaid ... ```) are rendered via mermaid.ink and embedded as
external mediaSingle nodes — no attachment upload required.

Auth: ATLASSIAN_BASIC_AUTH env var (auto-loaded via ~/.zshrc → ~/.second-brain-harness.env).
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import zlib
from pathlib import Path
from typing import Any
from urllib.parse import quote
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

CONF_BASE = "https://sambatv.atlassian.net/wiki"
TIMEOUT_SEC = 30


# ============================================================================
# Auth + HTTP
# ============================================================================

def get_basic_auth() -> str:
    auth = os.environ.get("ATLASSIAN_BASIC_AUTH")
    if not auth:
        sys.exit(
            "ATLASSIAN_BASIC_AUTH env var not set.\n"
            "Source ~/.second-brain-harness.env or run from a fresh shell."
        )
    return auth


def confluence_request(
    method: str, path: str, body: dict | None = None, *,
    expect: tuple[int, ...] = (200, 201, 204),
) -> tuple[int, dict | None]:
    """Single Confluence REST call. path is everything after CONF_BASE."""
    auth = get_basic_auth()
    url = f"{CONF_BASE}{path}"
    headers = {
        "Authorization": f"Basic {auth}",
        "Accept": "application/json",
    }
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = Request(url, method=method, headers=headers, data=data)
    try:
        with urlopen(req, timeout=TIMEOUT_SEC) as resp:
            status = resp.getcode()
            raw = resp.read()
            parsed = json.loads(raw) if raw else None
            if status not in expect:
                sys.exit(f"{method} {path} returned {status} (expected {expect}): {parsed}")
            return status, parsed
    except HTTPError as e:
        body_text = e.read().decode("utf-8", errors="replace")
        sys.exit(f"{method} {path} HTTPError {e.code}: {body_text}")
    except URLError as e:
        sys.exit(f"{method} {path} URLError: {e}")


# ============================================================================
# Mermaid rendering via mermaid.ink
# ============================================================================

def mermaid_url(src: str, theme: str = "default") -> str:
    state = {"code": src, "mermaid": {"theme": theme}}
    data = zlib.compress(json.dumps(state).encode("utf-8"), level=9)
    enc = base64.urlsafe_b64encode(data).decode().rstrip("=")
    return f"https://mermaid.ink/img/pako:{enc}?type=png&bgColor=white"


def validate_mermaid(src: str) -> tuple[bool, str]:
    """Render via mermaid.ink, return (ok, error_msg). Confirms syntax compiles."""
    url = mermaid_url(src)
    req = Request(url, headers={"User-Agent": "Mozilla/5.0 (compatible; confluence-publish-markdown/1.0)"})
    try:
        with urlopen(req, timeout=TIMEOUT_SEC) as resp:
            if resp.getcode() != 200:
                return False, f"mermaid.ink returned {resp.getcode()}"
            data = resp.read()
            if len(data) < 100:
                return False, "mermaid.ink returned empty response (syntax error?)"
            return True, ""
    except HTTPError as e:
        return False, f"mermaid.ink HTTPError {e.code}: syntax check failed"
    except URLError as e:
        return False, f"mermaid.ink URLError: {e}"


# ============================================================================
# ADF builders
# ============================================================================

def adf_text(t: str, marks: list | None = None) -> dict:
    n: dict = {"type": "text", "text": t}
    if marks:
        n["marks"] = marks
    return n


def adf_paragraph(content: list[dict]) -> dict:
    return {"type": "paragraph", "content": content}


def adf_heading(level: int, content: list[dict]) -> dict:
    return {"type": "heading", "attrs": {"level": level}, "content": content}


def adf_panel(panel_type: str, content: list[dict]) -> dict:
    return {"type": "panel", "attrs": {"panelType": panel_type}, "content": content}


def adf_codeblock(text: str, language: str = "text") -> dict:
    return {
        "type": "codeBlock",
        "attrs": {"language": language},
        "content": [adf_text(text)],
    }


def adf_bullet_list(items: list[list[dict]]) -> dict:
    return {
        "type": "bulletList",
        "content": [{"type": "listItem", "content": item} for item in items],
    }


def adf_ordered_list(items: list[list[dict]]) -> dict:
    return {
        "type": "orderedList",
        "attrs": {"order": 1},
        "content": [{"type": "listItem", "content": item} for item in items],
    }


def adf_blockquote(content: list[dict]) -> dict:
    return {"type": "blockquote", "content": content}


def adf_rule() -> dict:
    return {"type": "rule"}


def adf_media_external(url: str, layout: str = "wide", alt: str = "") -> dict:
    return {
        "type": "mediaSingle",
        "attrs": {"layout": layout},
        "content": [{
            "type": "media",
            "attrs": {"type": "external", "url": url, "alt": alt},
        }],
    }


def adf_table(header_row: list[dict], body_rows: list[list[dict]]) -> dict:
    """header_row + body_rows are lists of cells, where each cell is an ADF
    paragraph (or list of inline nodes wrapped into a paragraph)."""
    rows = [{
        "type": "tableRow",
        "content": [
            {"type": "tableHeader", "attrs": {}, "content": [cell]}
            for cell in header_row
        ],
    }]
    for body in body_rows:
        rows.append({
            "type": "tableRow",
            "content": [
                {"type": "tableCell", "attrs": {}, "content": [cell]}
                for cell in body
            ],
        })
    return {
        "type": "table",
        "attrs": {"layout": "default", "isNumberColumnEnabled": False},
        "content": rows,
    }


# ============================================================================
# Markdown → ADF via mistletoe
# ============================================================================

def _import_mistletoe():
    try:
        import mistletoe  # type: ignore
        from mistletoe import Document  # type: ignore
        from mistletoe import block_token, span_token  # type: ignore
        return mistletoe, Document, block_token, span_token
    except ImportError:
        sys.exit(
            "mistletoe not installed. Install with:\n"
            "  uv pip install mistletoe\n"
            "or:\n"
            "  pip install mistletoe"
        )


class MarkdownToADF:
    """Walk a mistletoe AST and emit ADF block nodes.

    Mermaid code blocks are intercepted and emitted as mediaSingle nodes with
    a mermaid.ink URL. Other code blocks become ADF codeBlock nodes.
    """

    def __init__(self):
        _, _, self.block_token, self.span_token = _import_mistletoe()[1:5] if False else _import_mistletoe()[1:4] + (None,)
        # Re-import directly for clarity
        import mistletoe
        from mistletoe import block_token, span_token
        self.block_token = block_token
        self.span_token = span_token

    # ---- inline (span) processing ------------------------------------------

    def render_inline(self, token, *, marks: list | None = None) -> list[dict]:
        """Render a single inline token (or its children) into a list of ADF text nodes."""
        marks = marks or []
        cls = type(token).__name__

        if cls == "RawText":
            return [adf_text(token.content, marks=list(marks) if marks else None)]
        if cls == "InlineCode":
            new_marks = list(marks) + [{"type": "code"}]
            return [adf_text(token.children[0].content, marks=new_marks)]
        if cls == "Strong":
            new_marks = list(marks) + [{"type": "strong"}]
            return self.render_inline_children(token, marks=new_marks)
        if cls == "Emphasis":
            new_marks = list(marks) + [{"type": "em"}]
            return self.render_inline_children(token, marks=new_marks)
        if cls == "Link":
            new_marks = list(marks) + [{"type": "link", "attrs": {"href": token.target}}]
            return self.render_inline_children(token, marks=new_marks)
        if cls == "Image":
            # Images aren't supported as block here — emit alt text in italics
            alt = "".join(c.content for c in token.children if hasattr(c, "content"))
            new_marks = list(marks) + [{"type": "em"}]
            return [adf_text(f"[image: {alt or token.src}]", marks=new_marks)]
        if cls == "LineBreak":
            return [{"type": "hardBreak"}]
        if cls == "EscapeSequence":
            return [adf_text(token.children[0].content, marks=list(marks) if marks else None)]
        if cls == "Strikethrough":
            new_marks = list(marks) + [{"type": "strike"}]
            return self.render_inline_children(token, marks=new_marks)
        # AutoLink — render as link
        if cls == "AutoLink":
            new_marks = list(marks) + [{"type": "link", "attrs": {"href": token.target}}]
            return [adf_text(token.target, marks=new_marks)]
        # Fallback: render children if it has any
        if hasattr(token, "children") and token.children:
            return self.render_inline_children(token, marks=marks)
        # Unknown — render as plain text if it has content
        if hasattr(token, "content"):
            return [adf_text(str(token.content), marks=list(marks) if marks else None)]
        return []

    def render_inline_children(self, token, *, marks: list | None = None) -> list[dict]:
        out: list[dict] = []
        for child in token.children:
            out.extend(self.render_inline(child, marks=marks))
        return out

    # ---- block processing --------------------------------------------------

    def render_block(self, token) -> list[dict]:
        """Render a single block token into a list of ADF block nodes
        (usually one node, but lists/tables/etc. can produce one)."""
        cls = type(token).__name__

        if cls == "Heading":
            return [adf_heading(token.level, self.render_inline_children(token))]

        if cls == "Paragraph":
            return [adf_paragraph(self.render_inline_children(token))]

        if cls == "BlockCode":
            # Indented code block (no language)
            return [adf_codeblock(token.children[0].content, language="text")]

        if cls == "CodeFence":
            lang = (token.language or "text").strip().lower() or "text"
            content = token.children[0].content
            if lang == "mermaid":
                # Render via mermaid.ink, embed as external media
                url = mermaid_url(content)
                return [adf_media_external(url, layout="wide", alt="diagram")]
            return [adf_codeblock(content, language=lang)]

        if cls == "List":
            items: list[list[dict]] = []
            for li in token.children:
                # li.children may include nested paragraphs, lists, etc.
                child_blocks: list[dict] = []
                for c in li.children:
                    child_blocks.extend(self.render_block(c))
                # If the list item has only inline content (rare in mistletoe — usually wrapped
                # in a Paragraph), wrap in paragraph
                if not child_blocks:
                    child_blocks = [adf_paragraph([])]
                items.append(child_blocks)
            if getattr(token, "start", None) is not None:
                return [adf_ordered_list(items)]
            return [adf_bullet_list(items)]

        if cls == "Quote":
            inner: list[dict] = []
            for c in token.children:
                inner.extend(self.render_block(c))
            # blockquote needs paragraph children only
            if not inner:
                inner = [adf_paragraph([])]
            return [adf_blockquote(inner)]

        if cls == "ThematicBreak":
            return [adf_rule()]

        if cls == "Table":
            return [self._render_table(token)]

        if cls == "HtmlBlock":
            # Pass through as a code block — discourages it, but doesn't lose content
            return [adf_codeblock(token.content, language="html")]

        # Unknown block — try children, else emit as paragraph with placeholder
        if hasattr(token, "children") and token.children:
            out: list[dict] = []
            for child in token.children:
                out.extend(self.render_block(child))
            return out

        return [adf_paragraph([adf_text(f"[unsupported block: {cls}]")])]

    def _render_table(self, token) -> dict:
        """Convert a mistletoe Table token to ADF table."""
        # Header row
        header_cells: list[dict] = []
        for cell in token.header.children:
            content = self.render_inline_children(cell)
            header_cells.append(adf_paragraph(content) if content else adf_paragraph([]))

        # Body rows
        body_rows: list[list[dict]] = []
        for row in token.children:
            row_cells: list[dict] = []
            for cell in row.children:
                content = self.render_inline_children(cell)
                row_cells.append(adf_paragraph(content) if content else adf_paragraph([]))
            body_rows.append(row_cells)

        return adf_table(header_cells, body_rows)

    # ---- entrypoint --------------------------------------------------------

    def render_document(self, md_text: str) -> list[dict]:
        from mistletoe import Document
        doc = Document(md_text)
        out: list[dict] = []
        for child in doc.children:
            out.extend(self.render_block(child))
        return out


# ============================================================================
# Title extraction
# ============================================================================

def extract_title_and_strip(md: str) -> tuple[str | None, str]:
    """If the markdown starts with `# Title\n`, extract it and return rest.
    Otherwise return (None, original)."""
    m = re.match(r"^#\s+(.+?)\s*\n", md)
    if m:
        title = m.group(1).strip()
        return title, md[m.end():]
    return None, md


# ============================================================================
# Header config
# ============================================================================

def load_header_config(path: Path) -> dict:
    suffix = path.suffix.lower()
    text = path.read_text()
    if suffix in (".yaml", ".yml"):
        try:
            import yaml  # type: ignore
        except ImportError:
            sys.exit("Header config is YAML but PyYAML not installed. uv pip install pyyaml")
        return yaml.safe_load(text)
    if suffix == ".json":
        return json.loads(text)
    sys.exit(f"Unsupported header config extension: {suffix}")


def build_header_panel(cfg: dict) -> dict:
    """Build a standard 'info' panel with cross-links from header config.

    Schema (all fields optional except at least one link):
      repo_url:     https://...
      live_url:     https://...   (deployed app, optional)
      jira_epic:    ATF-450       (resolved to full URL)
      confluence_hub: https://... (link to project hub)
      extra_links:                 (list of {label, url})
        - label: "..."
          url: "..."
      summary:      "Optional one-line summary at top of panel"
    """
    paragraphs: list[dict] = []

    if cfg.get("summary"):
        paragraphs.append(adf_paragraph([
            adf_text(cfg["summary"], marks=[{"type": "em"}])
        ]))

    # Build link line(s)
    pairs: list[tuple[str, str]] = []
    if cfg.get("repo_url"):
        url = cfg["repo_url"]
        label = url.replace("https://", "").replace("http://", "")
        pairs.append(("Repo", url))
    if cfg.get("live_url"):
        pairs.append(("Live", cfg["live_url"]))
    if cfg.get("confluence_hub"):
        pairs.append(("Confluence hub", cfg["confluence_hub"]))
    if cfg.get("jira_epic"):
        epic = cfg["jira_epic"]
        url = f"https://sambatv.atlassian.net/browse/{epic}"
        pairs.append((f"Jira Epic ({epic})", url))
    for extra in cfg.get("extra_links", []):
        pairs.append((extra["label"], extra["url"]))

    if not pairs and not cfg.get("summary"):
        sys.exit("Header config must include at least one link or summary")

    # Render link lines: one per pair, comma-separated within a single paragraph
    if pairs:
        nodes: list[dict] = []
        for i, (label, url) in enumerate(pairs):
            if i > 0:
                nodes.append(adf_text("  ·  "))
            nodes.append(adf_text(f"{label}: ", marks=[{"type": "strong"}]))
            display = url.replace("https://", "").replace("http://", "") if label.lower().startswith(("repo", "live")) else label
            nodes.append(adf_text(display, marks=[{"type": "link", "attrs": {"href": url}}]))
        paragraphs.append(adf_paragraph(nodes))

    return adf_panel("info", paragraphs)


# ============================================================================
# Main pipeline
# ============================================================================

def preflight(args, md_text: str, mermaid_blocks: list[str]) -> None:
    print("Pre-flight:")

    # Parent or page
    if args.parent_id:
        print(f"  GET parent page {args.parent_id} ...", end=" ", flush=True)
        status, body = confluence_request("GET", f"/api/v2/pages/{args.parent_id}")
        title = body.get("title", "?") if body else "?"
        print(f"OK — {title!r}")
    elif args.page_id:
        print(f"  GET target page {args.page_id} ...", end=" ", flush=True)
        status, body = confluence_request("GET", f"/api/v2/pages/{args.page_id}")
        title = body.get("title", "?") if body else "?"
        version = body.get("version", {}).get("number", "?") if body else "?"
        print(f"OK — {title!r} (v{version})")

    # Header config
    if args.header_config:
        print(f"  Header config: {args.header_config} ...", end=" ", flush=True)
        cfg = load_header_config(Path(args.header_config))
        build_header_panel(cfg)  # raises if invalid
        print("OK")

    # Mermaid blocks
    print(f"  Found {len(mermaid_blocks)} mermaid block(s).")
    for i, src in enumerate(mermaid_blocks, 1):
        ok, err = validate_mermaid(src)
        if not ok:
            print(f"    Block #{i}: FAIL — {err}", file=sys.stderr)
            sys.exit(1)
        print(f"    Block #{i}: OK ({len(src)} chars source)")

    print("Pre-flight OK.")


def extract_mermaid_blocks(md_text: str) -> list[str]:
    """Find all ```mermaid ... ``` blocks (returns sources)."""
    pattern = re.compile(r"```mermaid\s*\n(.+?)```", re.DOTALL)
    return [m.group(1).rstrip() for m in pattern.finditer(md_text)]


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument("--markdown", required=True, type=Path, help="Local markdown file")
    g = parser.add_mutually_exclusive_group(required=True)
    g.add_argument("--parent-id", help="Confluence parent page ID — creates a new child page")
    g.add_argument("--page-id", help="Confluence page ID — replaces body of existing page")
    parser.add_argument("--title", help="Page title (default: first H1 from markdown)")
    parser.add_argument("--space-id", default="14288191609",
                        help="Confluence space ID (default: ATF=14288191609)")
    parser.add_argument("--header-config", help="Path to header config YAML/JSON (optional)")
    parser.add_argument("--validate-only", action="store_true",
                        help="Run pre-flight only, don't create or update")
    args = parser.parse_args()

    if not args.markdown.is_file():
        sys.exit(f"Markdown file not found: {args.markdown}")

    md_text = args.markdown.read_text()

    # Extract title from first H1 if not provided
    h1_title, body_md = extract_title_and_strip(md_text)
    if args.title:
        title = args.title
        # If user gave a title AND markdown has H1, we still strip the H1 (avoid duplication)
        md_for_render = body_md if h1_title else md_text
    else:
        if not h1_title:
            sys.exit("--title not provided AND markdown has no H1 — pass --title <name> or add a # heading")
        title = h1_title
        md_for_render = body_md

    # Extract mermaid blocks for pre-flight syntax check
    mermaid_blocks = extract_mermaid_blocks(md_for_render)

    preflight(args, md_for_render, mermaid_blocks)
    if args.validate_only:
        print("\n--validate-only: stopping before publish.")
        return

    # Convert markdown to ADF
    print("\nConverting markdown to ADF ...")
    converter = MarkdownToADF()
    adf_blocks = converter.render_document(md_for_render)

    # Prepend header panel if configured
    if args.header_config:
        header_panel = build_header_panel(load_header_config(Path(args.header_config)))
        adf_blocks = [header_panel] + adf_blocks

    adf_doc = {"version": 1, "type": "doc", "content": adf_blocks}
    print(f"  → {len(adf_blocks)} top-level blocks")

    # Publish
    if args.parent_id:
        print(f"\nCreating new page under parent {args.parent_id} ...")
        page_id = create_page(args, adf_doc, title)
    else:
        print(f"\nUpdating existing page {args.page_id} ...")
        page_id = update_page(args.page_id, adf_doc, title)

    print(f"\n{'─'*60}")
    print(f"Published: https://sambatv.atlassian.net/wiki/spaces/ATF/pages/{page_id}")
    print(f"  Title:    {title}")
    print(f"  Page ID:  {page_id}")


def create_page(args, adf_doc: dict, title: str) -> str:
    """Create a new page. Tries v2 POST first; falls back to MCP if forbidden."""
    payload = {
        "spaceId": args.space_id,
        "status": "current",
        "title": title,
        "parentId": args.parent_id,
        "body": {
            "representation": "atlas_doc_format",
            "value": json.dumps(adf_doc),
        },
    }
    auth = get_basic_auth()
    url = f"{CONF_BASE}/api/v2/pages"
    headers = {
        "Authorization": f"Basic {auth}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }
    req = Request(url, method="POST", headers=headers,
                  data=json.dumps(payload).encode("utf-8"))
    try:
        with urlopen(req, timeout=TIMEOUT_SEC) as resp:
            status = resp.getcode()
            body = json.loads(resp.read())
            if status == 200 and body.get("id"):
                return body["id"]
            sys.exit(f"POST /api/v2/pages returned {status}: {body}")
    except HTTPError as e:
        body_text = e.read().decode("utf-8", errors="replace")
        if e.code == 404:
            sys.exit(
                f"POST /api/v2/pages returned 404 — token likely lacks page-create scope.\n"
                f"Workaround: use the Atlassian MCP createConfluencePage tool to create the\n"
                f"page first (any placeholder body), then re-run this script with --page-id.\n"
                f"Response: {body_text}"
            )
        sys.exit(f"POST /api/v2/pages HTTPError {e.code}: {body_text}")
    except URLError as e:
        sys.exit(f"POST /api/v2/pages URLError: {e}")


def update_page(page_id: str, adf_doc: dict, title: str) -> str:
    # Get current version
    _, body = confluence_request("GET", f"/api/v2/pages/{page_id}")
    if not body:
        sys.exit(f"GET page {page_id} returned no body")
    current_version = body.get("version", {}).get("number")
    if not current_version:
        sys.exit(f"GET page {page_id} returned no version: {body}")

    payload = {
        "id": page_id,
        "status": "current",
        "title": title,
        "body": {
            "representation": "atlas_doc_format",
            "value": json.dumps(adf_doc),
        },
        "version": {
            "number": current_version + 1,
            "message": "Updated by confluence-publish-markdown skill",
        },
    }
    confluence_request("PUT", f"/api/v2/pages/{page_id}", body=payload, expect=(200,))
    return page_id


if __name__ == "__main__":
    main()
