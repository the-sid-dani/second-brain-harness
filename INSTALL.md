# INSTALL.md — Manual Install Guide

A step-by-step fallback to `./scripts/install.sh`. Use this if you want fine-grained control, you're debugging a failed install, or the installer's idempotency check missed something on your machine.

---

## Overview

`scripts/install.sh` runs the same 11 steps documented below, sourcing `scripts/lib/*.sh` for each one. It is **idempotent** — safe to re-run after a partial failure. Every step probes for existing tooling and skips when already present.

**Use the installer if:** you want the fastest path, you're on a fresh Mac, or you're happy with the defaults (Homebrew install, brew-managed Rust, brew-managed `uv`).

**Use this manual guide if:** the installer failed mid-way, you maintain a non-standard toolchain (rustup-managed Rust, pipx-managed Python, etc.), or you want to understand exactly what lands on your machine before running anything.

---

## Prerequisites

- **macOS** (11 Big Sur or later). WSL2 / Linux compatibility is deferred — most steps work, but `brew` and `mlx` paths assume Darwin.
- **bash 3.2+** (default on macOS).
- **Internet access** — Homebrew, npm, cargo, pip, and `uv tool install` all fetch from the network.
- **Disk space** — roughly **5 GB** with FastEdit's optional 1.7B merge model (skip with `--no-fastedit-model` to save ~3 GB).
- **Admin password** — `xcode-select --install` and the Homebrew bootstrap will prompt at least once.

---

## Step-by-step manual install

Each section maps 1:1 to a step in `scripts/install.sh`. Run them in order. After each, verify with the probe at the end of the section.

### 1. Homebrew

```bash
# Skip if `brew --version` already returns a version.
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Apple Silicon — add brew to PATH for this shell:
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Probe: `brew --version`

### 2. Node 20 + git + jq

```bash
brew install node@20 git jq
brew link --overwrite node@20  # if a different Node major was previously linked
```

Probe: `node --version` (expect `v20.x.x`), `git --version`, `jq --version`.

### 3. Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

Probe: `claude --version`

### 4. System extras

```bash
brew install ripgrep ffmpeg yt-dlp
```

These back several skills: `rg` for fast grep, `ffmpeg` for video encoding (used by hyperframes / design skills), `yt-dlp` for transcript extraction.

Probe: `rg --version`, `ffmpeg -version`, `yt-dlp --version`.

### 5. Rust toolchain

```bash
# Preferred — brew-managed
brew install rust

# Fallback if brew install fails or you want rustup's nightly support
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
```

Probe: `cargo --version`, `rustc --version`.

### 6. uv (Python package manager)

```bash
brew install uv
```

Probe: `uv --version`

### 7. ContinuousClaude V4.7 binaries

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

### 8. ContinuousClaude V4.7 Python deps

```bash
# From the repo root:
pip install -r .claude/tools/requirements.txt

# FastEdit (with mlx + mcp extras — pulls the local 1.7B merge model on first run)
uv tool install 'fastedits[mlx,mcp]'
```

To skip the FastEdit model download (~3 GB), omit the `uv tool install` line. The `fastedit` MCP registration in step 9 will be skipped automatically by the installer; for manual install, just skip step 9 too.

Probe: `fastedit --version`

### 9. FastEdit MCP registration

Edit `.mcp.json` at the repo root and add a `fastedit` entry under `mcpServers`. The exact snippet:

```json
{
  "mcpServers": {
    "fastedit": {
      "command": "/path/to/fastedit",
      "args": ["mcp"],
      "type": "stdio"
    }
  }
}
```

Replace `/path/to/fastedit` with the output of `command -v fastedit` (typically `~/.local/bin/fastedit` if installed via `uv tool install`).

If `.mcp.json` already has other entries, merge — don't overwrite. Use `jq` to add idempotently:

```bash
jq --arg cmd "$(command -v fastedit)" \
   '.mcpServers.fastedit = {"command": $cmd, "args": ["mcp"], "type": "stdio"}' \
   .mcp.json > .mcp.json.tmp && mv .mcp.json.tmp .mcp.json
```

Probe: `jq '.mcpServers.fastedit' .mcp.json` should print the entry.

### 10. API keys

Create or edit `.env` at the repo root with the keys below. Get each from the linked provider:

```ini
# Anthropic API (Claude API access) — https://console.anthropic.com
ANTHROPIC_API_KEY=

# Exa (web search MCP)            — https://exa.ai
EXA_API_KEY=

# Nia (indexed-repo/research MCP) — https://trynia.ai
NIA_API_KEY=

# Hugging Face (FastEdit model downloads, optional) — https://huggingface.co/settings/tokens
HF_TOKEN=

# Atlassian (Jira + Confluence MCP) — https://id.atlassian.com/manage-profile/security/api-tokens
ATLASSIAN_BASIC_AUTH=
```

**Gemini** uses a shell-exported variable rather than `.env`. Add to `~/.zshrc`:

```bash
export GEMINI_API_KEY=<your-key>  # https://aistudio.google.com/apikey (free tier)
```

### 11. Verification

Run each probe — every command should return a version string with exit 0:

```bash
node --version
claude --version
gh --version
jq --version
cargo --version
bloks --version
tldr --version
uv --version
fastedit --version
ffmpeg -version
yt-dlp --version
rg --version
```

If any are missing, return to that step. If all pass, you're done.

---

## Post-install OAuth (browser flows)

Several MCPs use browser-based OAuth and cannot be scripted. After install, open Claude Code in the repo root and run:

```
/mcp
```

Then select each MCP one at a time and follow the browser prompt:

- **slack** — opens Slack's OAuth page; authorize the workspace, return to Claude Code.
- **figma** — opens Figma's OAuth page; authorize, return.
- **atlassian** — opens Atlassian's OAuth page; authorize, return.

**Google Workspace** (`gws` CLI, separate from MCPs) — if you skipped corporate onboarding:

```bash
gws auth login
```

Follow the browser prompt to grant the required scopes (calendar, drive, gmail.modify, documents, spreadsheets, presentations, tasks).

---

## Troubleshooting

**`cargo install` reports success but `bloks` / `tldr` not on PATH.**
Add `~/.cargo/bin` to your shell:
```bash
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.zshrc && exec zsh
```

**`uv tool install 'fastedits[mlx,mcp]'` fails with "no Python found."**
`uv` needs a Python toolchain. Install one:
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
Then re-apply the `jq` snippet from step 9.

**`ANTHROPIC_API_KEY` not picked up by Claude Code.**
Claude Code reads it from the shell env, not `.env`. Source the project `.env` in your shell startup:
```bash
echo 'set -a && [ -f .env ] && . .env; set +a' >> ~/.zshrc
```
Or export the key directly in `~/.zshrc`.

**Installer reports "foundation toolchain detected, skipping steps 1-3."**
This is correct behavior when `gh` and `claude` are already on PATH — the foundation steps are already covered. Re-run with `--reconfigure` if you need to re-prompt for API keys only.

---

## Re-running the installer

The installer is idempotent. To re-run after fixing an issue:

```bash
./scripts/install.sh
```

To rotate API keys without re-installing tooling:

```bash
./scripts/install.sh --reconfigure
```

To skip the heavy FastEdit model on a disk-constrained machine:

```bash
./scripts/install.sh --no-fastedit-model
```

See `./scripts/install.sh --help` for the full flag list.
