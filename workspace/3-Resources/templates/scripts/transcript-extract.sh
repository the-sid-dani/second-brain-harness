#!/usr/bin/env bash
#
# transcript-extract.sh — YouTube video → cleaned markdown transcript
#
# Ported from heyitsnoah/claudesidian (.scripts/transcript-extract.sh).
# Adjusted to drop output into our 0-Inbox/ by default so /inbox-process can route it.
#
# USAGE:
#   ./transcript-extract.sh <youtube-url> [output-dir]
#
# DEFAULT OUTPUT:
#   workspace/0-Inbox/    (resolved relative to repo root, run from anywhere)
#
# DEPENDENCIES:
#   yt-dlp  — install via `brew install yt-dlp` (NOT installed by samba-onboarding;
#             handoff was incorrect about this)
#   jq      — already installed
#
# OUTPUT FORMAT:
#   YYYY-MM-DD - <safe-title> - Transcript.md  (truncated to 80 chars on title)
#
#   File header includes source URL, video ID, extraction date.
#   Body is cleaned text (no music symbols, no extra whitespace, no blank lines).
#
# FAILURE MODES:
#   - yt-dlp not installed → prints brew install command and exits 1
#   - URL has no captions → exits 1 with a hint to use Vision MCP analyze_video instead
#   - jq not installed → exits 1
#

set -euo pipefail

# Repo-root resolution: walk up from this script's location until we find the marker.
# Marker: presence of workspace/0-Inbox/ relative to a directory means it's the repo root.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/workspace/0-Inbox" ]; do
    REPO_ROOT="$(dirname "$REPO_ROOT")"
done

if [ "$REPO_ROOT" = "/" ]; then
    echo "❌ Could not locate repo root (looking for workspace/0-Inbox/ ancestor)" >&2
    echo "   Run this script from inside the second-brain-os tree, or pass output-dir explicitly." >&2
    exit 1
fi

URL="${1:-}"
OUTPUT_DIR="${2:-$REPO_ROOT/workspace/0-Inbox}"

if [ -z "$URL" ]; then
    echo "Usage: $0 <youtube-url> [output-dir]"
    echo "Default output dir: $REPO_ROOT/workspace/0-Inbox/"
    exit 1
fi

# Dependency check — yt-dlp and jq must be present
if ! command -v yt-dlp >/dev/null 2>&1; then
    echo "❌ yt-dlp not installed." >&2
    echo "   Install: brew install yt-dlp" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "❌ jq not installed." >&2
    echo "   Install: brew install jq" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "🔍 Extracting transcript from: $URL"
echo "📁 Output dir: $OUTPUT_DIR"

# Extract metadata
VIDEO_ID=$(yt-dlp --get-id "$URL")
TITLE=$(yt-dlp --get-title "$URL")
SAFE_TITLE=$(echo "$TITLE" | sed 's/[^a-zA-Z0-9 -]//g' | sed 's/  */ /g' | cut -c1-80)
DATE=$(date +%Y-%m-%d)

echo "📹 Video: $TITLE"
echo "🆔 Video ID: $VIDEO_ID"

# Use a temp dir for the captions JSON so we don't clutter the working directory
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Download captions only (no video). Try official then auto-generated, English variants.
echo "🎯 Attempting to extract captions..."
if yt-dlp --skip-download \
          --write-subs \
          --write-auto-subs \
          --sub-langs 'en.*' \
          --sub-format json3 \
          -o "$TMPDIR/%(id)s.%(ext)s" \
          "$URL"; then
    echo "✅ Captions extracted"

    FILENAME="$OUTPUT_DIR/$DATE - $SAFE_TITLE - Transcript.md"

    # Write header
    cat > "$FILENAME" <<EOF
---
type: transcript
source: $URL
video_id: $VIDEO_ID
extracted: $DATE
extraction_method: yt-dlp captions
---

# $TITLE — Transcript

**Source:** $URL
**Video ID:** $VIDEO_ID
**Extracted:** $DATE

---

EOF

    # Process JSON3 captions → clean markdown body
    # - extract text segments
    # - collapse whitespace
    # - remove music symbols
    # - drop blank lines
    jq -r '.events[]? | select(.segs) | .segs | map(.utf8) | join("")' "$TMPDIR"/*.json3 \
        | sed -E 's/[[:space:]]+/ /g; s/♪//g; s/^[[:space:]]*//; s/[[:space:]]*$//' \
        | grep -v '^$' >> "$FILENAME"

    LINE_COUNT=$(wc -l < "$FILENAME" | tr -d ' ')
    echo "✅ Transcript saved: $FILENAME"
    echo "📝 $LINE_COUNT lines"
    echo ""
    echo "Run /inbox-process to route this into Resources or a project."
else
    echo "❌ No captions available for this video." >&2
    echo "   Hint: try the Gemini Vision MCP — \`mcp__gemini-vision__analyze_video --youtube_url $URL\`" >&2
    echo "   That uses speech-to-text on the audio, slower but works on caption-less videos." >&2
    exit 1
fi
