#!/usr/bin/env bash
# scripts/lib/ccv4-python.sh — install CCv4 Python dependencies (requirements.txt + FastEdit)

install_ccv4_python() {
    step "Installing CCv4 Python dependencies"

    if ! command -v uv >/dev/null 2>&1; then
        die "uv not found on PATH — install_uv must run first"
    fi

    local req=".claude/tools/requirements.txt"
    if [ -f "$req" ]; then
        # uv pip install handles PEP 668 (externally-managed Python) cleanly.
        # --system installs into the active Python; for macOS brew Python this
        # is the right scope. Fork users with their own venv can `source` it
        # before running install.sh and uv will pick that up instead.
        uv pip install --system -r "$req" 2>/dev/null \
            || uv pip install --system --break-system-packages -r "$req" \
            || die "uv pip install -r $req failed"
        info "Python deps installed from $req"
    else
        warn "$req not found — skipping Python deps"
    fi

    if [ "${NO_FASTEDIT_MODEL:-0}" = "1" ]; then
        info "--no-fastedit-model set; skipping FastEdit install"
        return 0
    fi

    if command -v fastedit >/dev/null 2>&1; then
        info "fastedit already installed (skipping uv tool install)"
        return 0
    fi

    if ! command -v uv >/dev/null 2>&1; then
        die "uv not found on PATH — install_uv must run first"
    fi
    # Platform-branch fastedits extras. MLX is Apple-Silicon-only; Linux/WSL2
    # uses CPU fallback.
    local fastedits_extras
    if [[ "$(uname -s)" == "Darwin" ]]; then
        fastedits_extras='fastedits[mlx,mcp]'
    else
        fastedits_extras='fastedits[mcp]'
    fi
    uv tool install "$fastedits_extras" || die "uv tool install $fastedits_extras failed"
    info "FastEdit installed"
}
