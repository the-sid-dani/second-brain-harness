#!/usr/bin/env bash
# scripts/lib/rust.sh — install rust toolchain

install_rust() {
    step "Installing rust toolchain"

    if command -v cargo >/dev/null 2>&1; then
        info "rust already installed ($(cargo --version))"
        return 0
    fi

    if brew install rust; then
        info "rust installed via brew ($(cargo --version 2>/dev/null || echo 'cargo'))"
        return 0
    fi

    warn "brew install rust failed — falling back to rustup"
    if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable; then
        # shellcheck disable=SC1091
        source "$HOME/.cargo/env"
        info "rust installed via rustup ($(cargo --version 2>/dev/null || echo 'cargo'))"
    else
        die "rust install failed (both brew and rustup)"
    fi
}
