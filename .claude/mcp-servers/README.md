# MCP Servers

Local Model Context Protocol servers for Beru. These extend Claude Code with capabilities that aren't available in the base toolset.

## gemini-vision

Lets Claude actually *see* images, PDFs, documents, and videos via Google's Gemini API. Without this, screenshots / PDFs dropped into `0-Inbox/` are opaque to Beru — the MCP turns them into structured analysis.

**Source:** ported from [heyitsnoah/claudesidian](https://github.com/heyitsnoah/claudesidian/blob/main/.claude/mcp-servers/gemini-vision.mjs).

### Tools exposed

- `analyze_image` — single-image analysis (description, transcription, Q&A)
- `analyze_multiple` — batch over a list of images
- `extract_text` — OCR (plain / markdown / structured output)
- `compare_images` — diff two images (differences / similarities / changes)
- `suggest_image_filename` — content-based filename suggestion
- `analyze_document` — PDF / DOC / DOCX / RTF / TXT
- `analyze_video` — local video file or YouTube URL

### One-time setup

1. **Get a free Gemini API key** from https://aistudio.google.com/apikey — starts with `AIzaSy...`. Free tier is 15 req/min, plenty for personal use.

2. **Export it in your shell** (so Claude Code inherits it; we deliberately do NOT bake it into `.mcp.json`):
   ```bash
   echo 'export GEMINI_API_KEY="AIzaSy...your-actual-key..."' >> ~/.zshrc
   source ~/.zshrc
   ```

3. **Verify the env var is set**:
   ```bash
   echo $GEMINI_API_KEY  # should print the key
   ```

4. **Restart Claude Code** (so it picks up the env var + reads `.mcp.json`).

5. **Verify the server is connected** — in Claude, run:
   ```
   /mcp
   ```
   You should see `gemini-vision ✔ connected`.

### Dependencies

`npm install` was already run in this folder. If `node_modules/` ever gets blown away:

```bash
cd .claude/mcp-servers
npm install
```

### Why the API key isn't in `.mcp.json`

`.mcp.json` is committed to git. Storing the key there would leak it. The MCP server reads `process.env.GEMINI_API_KEY`, which inherits from the shell that launched Claude Code → so as long as the env var is in your `~/.zshrc`, the server gets it.

### Costs

Free tier (15 req/min) is fine for the volume Beru will use this at — image triage on inbox items, occasional PDF extraction, the odd YouTube transcript. Paid tier exists if you need more throughput, but unlikely.
