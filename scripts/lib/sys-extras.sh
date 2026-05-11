#!/usr/bin/env bash
# scripts/lib/sys-extras.sh — install ripgrep, ffmpeg, yt-dlp

install_sys_extras() {
    step "Installing system extras (ripgrep, ffmpeg, yt-dlp)"

    if command -v rg >/dev/null 2>&1; then
        info "ripgrep already installed ($(rg --version | head -1))"
    else
        brew install ripgrep || die "brew install ripgrep failed"
        info "ripgrep installed"
    fi

    if command -v ffmpeg >/dev/null 2>&1; then
        info "ffmpeg already installed ($(ffmpeg -version | head -1))"
    else
        brew install ffmpeg || die "brew install ffmpeg failed"
        info "ffmpeg installed"
    fi

    if command -v yt-dlp >/dev/null 2>&1; then
        info "yt-dlp already installed ($(yt-dlp --version 2>/dev/null | head -1))"
    else
        brew install yt-dlp || die "brew install yt-dlp failed"
        info "yt-dlp installed"
    fi
}
