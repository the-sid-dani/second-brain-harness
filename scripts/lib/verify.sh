#!/usr/bin/env bash
# scripts/lib/verify.sh — post-install verification (probe each binary, print manual checklist)

verify_all() {
    step "Verifying installation"

    local probes=(
        "node --version"
        "claude --version"
        "gh --version"
        "jq --version"
    )
    # ripgrep is opt-in (W1). Probe only if rg is on PATH or installer flagged it.
    if command -v rg >/dev/null 2>&1 || [ "${INSTALL_RIPGREP:-0}" = "1" ]; then
        probes+=("rg --version")
    fi
    # CCv4 toolchain probes only fire on coding tier (W2).
    if [ "${INSTALL_CODING:-0}" = "1" ]; then
        probes+=("cargo --version" "bloks --version" "tldr --version" "uv --version")
        if [ "${NO_FASTEDIT_MODEL:-0}" != "1" ]; then
            probes+=("fastedit --version")
        fi
    fi

    local ok=0 fail=0
    for cmd in "${probes[@]}"; do
        # shellcheck disable=SC2086
        if $cmd >/dev/null 2>&1; then
            info "OK: $cmd"
            ok=$((ok+1))
        else
            warn "MISSING: $cmd"
            fail=$((fail+1))
        fi
    done

    if [ "${INSTALL_CODING:-0}" = "1" ] && [ "${NO_FASTEDIT_MODEL:-0}" = "1" ]; then
        info "fastedit probe skipped (--no-fastedit-model)"
    fi
    if [ "${INSTALL_CODING:-0}" != "1" ]; then
        info "CCv4 toolchain probes skipped (minimal tier — run with --with-coding to add)"
    fi

    printf '\n%s installed: %d, missing: %d%s\n\n' "${GREEN:-}" "$ok" "$fail" "${RESET:-}"

    info "Post-install manual steps (NOT scripted, in order):"
    info "  1. Open Claude Code in this folder → run /bootstrap"
    info "       (configures persona, regenerates TOOLS.md from live probes, ~15 min)"
    info "  2. After /bootstrap → run /mcp to authorize HTTP MCPs (slack, atlassian, figma, exa)"
    info "       (MCP OAuth is per-project — each workspace needs its own grants)"
    info "  3. GWS auth (optional) — run 'gws auth login' if you installed Google Workspace CLI separately"

    if [ "$fail" -gt 0 ]; then
        warn "Some binaries missing — re-run ./scripts/install.sh to retry, or install manually."
        return 1
    fi
    return 0
}
