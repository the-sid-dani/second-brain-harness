#!/usr/bin/env bash
# scripts/lib/ccv4-bins.sh — install CCv4 binaries (bloks, tldr-cli) via cargo

install_ccv4_bins() {
    step "Installing CCv4 binaries (bloks, tldr-cli)"

    if command -v bloks >/dev/null 2>&1 && command -v tldr >/dev/null 2>&1; then
        info "bloks + tldr already installed (skipping cargo install)"
        return 0
    fi
    if ! command -v cargo >/dev/null 2>&1; then
        die "cargo not found on PATH — install_rust must run first"
    fi
    cargo install bloks || warn "cargo install bloks reported a problem (may already be installed)"
    cargo install tldr-cli || warn "cargo install tldr-cli reported a problem (may already be installed)"
    info "CCv4 binaries installed"
}
