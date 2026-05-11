#!/usr/bin/env bash
# scripts/lib/uv.sh — install uv (Astral Python package manager)

install_uv() {
    step "Installing uv (Python package manager)"

    if command -v uv >/dev/null 2>&1; then
        info "uv already installed ($(uv --version))"
        return 0
    fi

    brew install uv || die "brew install uv failed"
    info "uv installed ($(uv --version 2>/dev/null || echo 'uv'))"
}
