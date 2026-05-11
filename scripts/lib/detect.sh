# shellcheck shell=bash
# lib/detect.sh — OS / arch detection. Sets PLATFORM and ARCH globals.

detect_platform() {
  ARCH="$(uname -m)"
  local os
  os="$(uname -s)"

  case "$os" in
    Darwin)
      PLATFORM="macos"
      ok "macOS $(sw_vers -productVersion 2>/dev/null || echo '') ($ARCH)"
      ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        PLATFORM="wsl"
        ok "Windows Subsystem for Linux ($ARCH)"
      else
        PLATFORM="linux"
        ok "Linux ($ARCH)"
      fi
      ;;
    *)
      warn "Unsupported platform: $os"
      return 1
      ;;
  esac

  export PLATFORM ARCH
}
