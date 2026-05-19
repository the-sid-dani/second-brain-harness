#!/usr/bin/env bash
# scripts/lib/api-keys.sh — write annotated .env.example, do NOT prompt.
#
# Design: professional installers (Homebrew, oh-my-zsh, starship, chezmoi)
# never prompt for credentials inline. They install binaries; secrets are
# deferred to .env.example + post-install README OR first-use prompts.
#
# Claude Code itself uses OAuth (Pro/Max/Enterprise/Console login on first
# `claude` run) — no ANTHROPIC_API_KEY needed for the core LLM. The keys
# below are all OPTIONAL and only power specific niche features.
#
# Honors NONINTERACTIVE=1 (Homebrew convention) — but this step is
# non-interactive by default, so the flag is effectively a no-op here.

configure_api_keys() {
    step "Writing annotated .env.example (optional keys)"

    local example_file=".env.example"

    # Always (re)write .env.example — it's documentation, not state.
    cat > "$example_file" <<'EOF'
# second-brain-os API keys
#
# Copy this file to .env (gitignored) and fill in the keys you want to use.
# The installer no longer prompts — it just writes this annotated example.
# Edit .env directly to rotate; no installer re-run needed.
#
# Required ONLY if you use the listed skill or MCP — the OS boots fine with
# every key blank. Claude Code itself uses OAuth (Pro/Max/Console login on
# first `claude` run); /briefing, /todo, /find work with zero keys.

# ────────────────────────────────────────────────────────────────────────
# Default MCPs (.mcp.json) — keys auto-source from your shell env
# ────────────────────────────────────────────────────────────────────────

GEMINI_API_KEY=
# Used by: gemini-vision MCP (image/PDF/video analysis)
# Get one: https://aistudio.google.com/apikey  (free tier — 15 req/min)
# Note: must ALSO be exported in your shell (e.g. ~/.zshrc) for the MCP to
# read it at launch — .env-only export won't reach a child claude process.

FIRECRAWL_API_KEY=
# Used by: firecrawl MCP (web scrape / crawl / extract — v0.2.0 default MCP)
# Get one: https://firecrawl.dev
# Note: must ALSO be exported in your shell for the MCP to read it.
# Without it, the MCP loads but every tool call returns 401.

# (exa MCP needs no key — its HTTP transport handles auth account-side)

# ────────────────────────────────────────────────────────────────────────
# Skill-only keys (no MCP — used by .claude/tools/ Python bridges + skills)
# ────────────────────────────────────────────────────────────────────────

ANTHROPIC_API_KEY=
# Used by: Ouros harness sub-LLM calls (/research, /autonomous), FastEdit
# Get one: https://console.anthropic.com
# Note: Claude Code itself does NOT need this — it auths via OAuth on
# `claude` login. Only needed for the CCv4 Python tools that call the
# Anthropic SDK directly.

EXA_API_KEY=
# Used by: company-research and people-research skills (Python bridge)
# Get one: https://exa.ai
# Note: the exa MCP itself uses HTTP-transport auth — this key only powers
# the skill-side Python bridge.

NIA_API_KEY=
# Used by: NIA docs bridge (/autonomous-research)
# Get one: https://trynia.ai

# ────────────────────────────────────────────────────────────────────────
# Optional connector keys (used by opt-in MCPs you added via /bootstrap)
# ────────────────────────────────────────────────────────────────────────

HF_TOKEN=
# Used by: FastEdit model pull if the model is gated on Hugging Face
# Get one: https://huggingface.co/settings/tokens

ATLASSIAN_BASIC_AUTH=
# Used by: /atlassian-attach skill (file uploads — MCP doesn't cover them)
# Get one: https://id.atlassian.com/manage-profile/security/api-tokens
# Note: must be a CLASSIC token (scoped tokens cannot upload attachments).
# Format: base64(email:token) — generate with:
#   printf 'you@example.com:YOUR_API_TOKEN' | base64
EOF

    info "wrote $example_file (7 optional keys, all documented)"

    if [ ! -f .env ]; then
        info "no .env yet — copy .env.example to .env when you want to enable a feature"
    else
        info ".env already exists — left untouched"
    fi

    cat <<'NOTE'

  ℹ️  No API keys needed to start.  Claude Code OAuths on first `claude` run.
     Enable individual features later by editing .env  (see .env.example).
NOTE
}
