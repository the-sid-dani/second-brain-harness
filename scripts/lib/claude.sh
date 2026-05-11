# shellcheck shell=bash
# lib/claude.sh — Claude Code installation.
#
# Skills are intentionally NOT bundled. Teammates install whichever skills
# they actually need afterwards (via `/plugin` inside Claude or their own
# setup) — 100+ default skills was too much for most use cases.

install_claude() {
  if command -v claude >/dev/null 2>&1; then
    skip "Claude Code already installed ($(claude --version 2>/dev/null | head -1 || echo ''))"
    return 0
  fi

  info "Installing Claude Code (npm)"
  run npm install -g @anthropic-ai/claude-code
  ok "Installed Claude Code"
}
