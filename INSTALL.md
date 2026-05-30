# INSTALL.md — Manual Install Guide

A step-by-step fallback to `./scripts/install.sh`. Use this if you want fine-grained control, you're debugging a failed install, or the installer's idempotency check missed something on your machine.

For most fork users the one-shot installer is the right path:

```bash
./scripts/install.sh              # knowledge-worker default (minimal tier, ~3-5 min)
./scripts/install.sh --with-coding # adds Rust + uv + CCv4 + FastEdit (~15 min extra)
./scripts/install.sh --help        # full flag list
```

This file documents the same steps as a manual walkthrough.

---

## Overview — the two tiers

As of v0.2.0 the installer has two tiers:

- **Minimal (default).** Foundation toolchain (Homebrew, Node 20, git, jq, Claude Code) + `.env.example` + verify. ~3-5 min on a Mac with the foundation already present. Right choice for knowledge-worker forks (briefings, `/todo`, `/find`, design skills, briefing/meeting prep).
- **Coding (`--with-coding`).** Adds Rust, uv, the CCv4 binaries (`bloks`, `tldr-cli`), CCv4 Python deps, and the FastEdit MCP. ~15 min extra. Required for `/research`, `/autonomous`, `/premortem`, and FastEdit-MCP-backed surgical AST edits.

The installer writes `SBOS_TIER=minimal|coding` to `~/.second-brain-os.env` so `/bootstrap` knows which tier you're on and adjusts its tool-probe panel accordingly.

**Use the installer if:** you want the fastest path, you're on a fresh Mac, or you're happy with the defaults (Homebrew install, brew-managed Rust, brew-managed `uv`).

**Use this manual guide if:** the installer failed mid-way, you maintain a non-standard toolchain (rustup-managed Rust, pipx-managed Python, etc.), or you want to understand exactly what lands on your machine before running anything.

---

## Prerequisites

- **macOS** (11 Big Sur or later). WSL2 / Linux / Windows compatibility is deferred to v0.3.0 — most minimal-tier steps work on Linux, but `brew` and `mlx` paths assume Darwin.
- **bash 3.2+** (default on macOS).
- **Internet access** — Homebrew, npm, cargo, pip, and `uv tool install` all fetch from the network.
- **Disk space** — ~500 MB for minimal tier; roughly **5 GB** for coding tier (FastEdit's optional 1.7B merge model is most of that — skip it with `--no-fastedit-model` to save ~3 GB).
- **Admin password** — `xcode-select --install` and the Homebrew bootstrap will prompt at least once.

---

## Path A — Minimal tier (knowledge-worker default)

Run these steps in order. After each, verify with the probe at the end of the section.

### A1. Homebrew

```bash
# Skip if `brew --version` already returns a version.
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Apple Silicon — add brew to PATH for this shell:
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Probe: `brew --version`

### A2. Node 20 + git + jq

```bash
brew install node@20 git jq
brew link --overwrite node@20  # if a different Node major was previously linked
```

Probe: `node --version` (expect `v20.x.x`), `git --version`, `jq --version`.

### A3. Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

Probe: `claude --version`

### A4. Optional system extras

ripgrep is **opt-in** as of v0.2.0 — `/find` works fine via `grep -r` fallback (slower).

```bash
# Only if you want the faster /find path:
brew install ripgrep
```

Probe: `rg --version` (only if installed).

> **Note (v0.2.0 W1):** `ffmpeg` and `yt-dlp` are no longer auto-installed — no active skill consumes them. If a pre-v0.2.0 install already brewed them, they're left alone.

### A5. `.env.example` + tier marker

The installer writes both automatically. To do it manually:

```bash
# 1. Copy the annotated example (already in the repo):
cp .env.example .env  # then edit .env, fill in only the keys you need

# 2. Write the tier marker so /bootstrap knows you're on minimal:
echo 'SBOS_TIER=minimal' >> ~/.second-brain-os.env
```

Every key in `.env.example` is **optional** — the OS boots fine with all keys blank. Fill in only what your active skills need (see comments inside `.env.example`).

### A6. Verification

```bash
brew --version
node --version       # v20.x.x
git --version
jq --version
claude --version
# optional:
rg --version 2>/dev/null || echo "ripgrep not installed — /find falls back to grep -r"
grep SBOS_TIER ~/.second-brain-os.env   # SBOS_TIER=minimal
```

If all those return cleanly, minimal-tier install is complete. Open Claude Code and run `/bootstrap` next.

---

## Path B — Coding tier (`--with-coding`)

Do Path A first, then continue with these steps. Or invoke the installer with `./scripts/install.sh --with-coding` to do A + B in one shot.

### B1. Rust toolchain

```bash
# Preferred — brew-managed
brew install rust

# Fallback if brew install fails or you want rustup's nightly support
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
```

Probe: `cargo --version`, `rustc --version`.

### B2. uv (Python package manager)

```bash
brew install uv
```

Probe: `uv --version`

### B3. ContinuousClaude V4.7 binaries

```bash
cargo install bloks
cargo install tldr-cli
```

If `cargo install` succeeds but the binary isn't on PATH, add `~/.cargo/bin` to your shell init:

```bash
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.zshrc
exec zsh  # reload
```

Probe: `bloks --version`, `tldr --version`.

### B4. ContinuousClaude V4.7 Python deps

```bash
# From the repo root:
pip install -r .claude/tools/requirements.txt

# FastEdit (with mlx + mcp extras — pulls the local 1.7B merge model on first run)
uv tool install 'fastedits[mlx,mcp]'
```

To skip the FastEdit model download (~3 GB), omit the `uv tool install` line. The `fastedit` MCP registration in B5 will then be skipped automatically by the installer; for manual install, just skip B5 too.

Probe: `fastedit --version`

### B5. FastEdit MCP registration

Edit `.mcp.json` at the repo root and add a `fastedit` entry under `mcpServers`. Use `jq` for an idempotent add:

```bash
jq --arg cmd "$(command -v fastedit)" \
   '.mcpServers.fastedit = {"command": $cmd, "args": ["mcp"], "type": "stdio"}' \
   .mcp.json > .mcp.json.tmp && mv .mcp.json.tmp .mcp.json
```

If you prefer to hand-edit, the entry looks like:

```json
{
  "mcpServers": {
    "fastedit": {
      "command": "/Users/<you>/.local/bin/fastedit",
      "args": ["mcp"],
      "type": "stdio"
    }
  }
}
```

Replace the `command` path with the output of `command -v fastedit` (typically `~/.local/bin/fastedit` via `uv tool install`).

Probe: `jq '.mcpServers.fastedit' .mcp.json` should print the entry.

### B6. Update tier marker

```bash
# Overwrite the SBOS_TIER line so /bootstrap probes the CCv4 toolchain:
sed -i.bak -E 's|^SBOS_TIER=.*|SBOS_TIER=coding|' ~/.second-brain-os.env && rm -f ~/.second-brain-os.env.bak
grep SBOS_TIER ~/.second-brain-os.env   # SBOS_TIER=coding
```

### B7. Verification

```bash
cargo --version
rustc --version
uv --version
bloks --version
tldr --version
fastedit --version
jq '.mcpServers.fastedit' .mcp.json
grep SBOS_TIER ~/.second-brain-os.env   # SBOS_TIER=coding
```

If all return cleanly, coding-tier install is complete.

---

## API keys — `.env`

The installer no longer prompts for API keys. It writes an annotated `.env.example` and leaves the rest to you.

```bash
cp .env.example .env  # then edit .env
```

Every key is **optional**. Add only the ones you need:

| Key | Used by | Get one |
|---|---|---|
| `GEMINI_API_KEY` | gemini-vision MCP (image/PDF/video analysis) | https://aistudio.google.com/apikey (free 15 req/min) |
| `FIRECRAWL_API_KEY` | firecrawl MCP (web scrape/crawl) | https://firecrawl.dev |
| `ANTHROPIC_API_KEY` | Ouros sub-LLM calls (`/research`, `/autonomous`), FastEdit | https://console.anthropic.com |
| `EXA_API_KEY` | `company-research` + `people-research` skills (Python bridge) | https://exa.ai |
| `NIA_API_KEY` | NIA docs bridge (`/autonomous-research`) | https://trynia.ai |
| `HF_TOKEN` | FastEdit model pull if gated on Hugging Face | https://huggingface.co/settings/tokens |
| `ATLASSIAN_BASIC_AUTH` | `/atlassian-attach` skill (file uploads) | https://id.atlassian.com/manage-profile/security/api-tokens |

> **Important:** MCPs read keys from your **shell env**, not from `.env` — Claude Code launches its child processes without sourcing `.env`. For MCP keys (`GEMINI_API_KEY`, `FIRECRAWL_API_KEY`), also `export` them in `~/.zshrc`. For skill-only keys (Anthropic / Exa / NIA / Atlassian) `.env` works because the Python bridges read it directly.

The simplest pattern:

```bash
echo 'set -a && [ -f "$PWD/.env" ] && . "$PWD/.env"; set +a' >> ~/.zshrc
exec zsh
```

This auto-sources `.env` from the current directory at every shell start.

---

## Post-install OAuth (browser flows)

### Default MCPs

The default `.mcp.json` ships **3 universals** that need no OAuth:

- **gemini-vision** — local stdio, uses `GEMINI_API_KEY` shell env
- **exa** — HTTP transport, account-bound auth (no key)
- **firecrawl** — HTTP transport, `FIRECRAWL_API_KEY` shell env

If those keys are set, your first `claude` launch shows zero red MCP errors.

### Opt-in connectors (Slack / Atlassian / Figma)

These are **not in `.mcp.json` by default** as of v0.2.0. They're added during `/bootstrap` Step 2.5 — the bootstrap skill asks which ones you use via multi-select and appends them interactively. The canonical entries (including Slack's required `clientId` + `callbackPort`) live in `.mcp.json` `_notes.opt_in_*` as a single source of truth.

After bootstrap adds them, run `/mcp` inside Claude Code to authorize each via browser-OAuth:

- **slack** — opens Slack's OAuth page; a workspace admin needs to approve the app once
- **figma** — opens Figma's OAuth page
- **atlassian** — opens Atlassian's OAuth page

If you skipped `/bootstrap` and want a connector added manually, copy the canonical entry from `.mcp.json` `_notes.opt_in_<name>` into `mcpServers`, then run `/mcp`.

### Google Workspace CLI

Separate from MCPs — used by `/briefing` and `/end-of-day` for calendar/mail/drive:

```bash
gws auth login
```

Follow the browser prompt to grant: calendar, drive, gmail.modify, documents, spreadsheets, presentations, tasks.

---

## Troubleshooting

**`cargo install` reports success but `bloks` / `tldr` not on PATH.**
Add `~/.cargo/bin` to your shell:
```bash
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.zshrc && exec zsh
```

**`uv tool install 'fastedits[mlx,mcp]'` fails with "no Python found."**
`uv` needs a Python toolchain:
```bash
uv python install 3.12
```
Then retry the `uv tool install` line.

**`brew install rust` conflicts with an existing rustup install.**
Skip the brew step. Re-source rustup's env:
```bash
source "$HOME/.cargo/env"
```
`cargo --version` should now work.

**FastEdit MCP errors with "model not found" on first edit.**
The 1.7B merge model downloads lazily on first invocation. Trigger it once with any small edit, or pre-pull:
```bash
fastedit --warmup
```
If you ran `install.sh` with `--no-fastedit-model`, the MCP registration was skipped — re-run without the flag.

**`.mcp.json` becomes invalid JSON after manual edit.**
Restore from git:
```bash
git checkout .mcp.json
```
Then re-apply the `jq` snippet from B5.

**`ANTHROPIC_API_KEY` not picked up by Claude Code or skills.**
Claude Code reads from the shell env, not `.env`. Source `.env` from your shell init (see the API keys section above).

**Installer reports "foundation toolchain detected, skipping steps 1-3."**
Correct behavior when `gh`, `claude`, `jq`, and `node` are already on PATH — the foundation steps are already covered. The installer no longer prompts for API keys (those live in `.env`; see `.env.example`), so there's nothing to re-prompt for.

**`/bootstrap` Step 2 shows CCv4 tools as missing on a minimal install.**
Make sure the tier marker is set:
```bash
grep SBOS_TIER ~/.second-brain-os.env  # should print SBOS_TIER=minimal
```
If the marker is missing, write it (`echo 'SBOS_TIER=minimal' >> ~/.second-brain-os.env`). Bootstrap branches on the marker — without it, it falls back to probing all tools and reports CCv4 as missing.

**Want to upgrade minimal → coding later?**
Just run `./scripts/install.sh --with-coding`. The installer is additive — it skips foundation steps that are already done and adds the coding-tier steps on top. The `SBOS_TIER` marker gets updated to `coding` automatically.

---

## Re-running the installer

The installer is idempotent. To re-run after fixing an issue:

```bash
./scripts/install.sh                # re-run minimal
./scripts/install.sh --with-coding  # re-run coding (or upgrade minimal → coding)
```

To rotate API keys: edit `.env` directly. The installer no longer touches `.env` — it only writes `.env.example` once.

To skip the heavy FastEdit model on a disk-constrained machine:

```bash
./scripts/install.sh --with-coding --no-fastedit-model
```

See `./scripts/install.sh --help` for the full flag list.
