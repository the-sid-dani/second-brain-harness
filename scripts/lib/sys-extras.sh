#!/usr/bin/env bash
# scripts/lib/sys-extras.sh — detect (and optionally install) ripgrep.
#
# v0.2.0 (W1):
#   - ffmpeg + yt-dlp removed (zero active skills consume them).
#   - ripgrep is now opt-in: detected always, installed only when
#     INSTALL_RIPGREP=1 (set by `./scripts/install.sh --with-ripgrep`).
#     /find skill has a `grep -r` fallback so this is purely a speed knob.

install_sys_extras() {
    step "Checking system extras (ripgrep)"

    if command -v rg >/dev/null 2>&1; then
        info "ripgrep already installed ($(rg --version | head -1))"
        return 0
    fi

    if [ "${INSTALL_RIPGREP:-0}" = "1" ]; then
        brew install ripgrep || die "brew install ripgrep failed"
        info "ripgrep installed"
    else
        info "ripgrep not installed — /find falls back to 'grep -r' (slower). To install: brew install ripgrep, or re-run with --with-ripgrep"
    fi
}
