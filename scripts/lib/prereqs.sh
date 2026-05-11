# shellcheck shell=bash
# lib/prereqs.sh — Homebrew, Node.js, git.

install_brew() {
  if command -v brew >/dev/null 2>&1; then
    skip "Homebrew already installed ($(brew --version | head -1))"
    persist_brew_path
    return 0
  fi

  info "Installing Homebrew (you may be prompted for sudo) — this can take 1–3 minutes"
  # Stream to terminal so the user sees sudo prompts and progress; tee to log too.
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>&1 | tee -a "$LOG_FILE"

  # Make brew available in this session
  if [ "$PLATFORM" = "macos" ] && [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ "$PLATFORM" = "macos" ] && [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi

  ok "Installed $(brew --version | head -1)"
  persist_brew_path
}

# Append `eval "$(brew shellenv)"` to the user's shell profile so brew (and
# everything it installs) stays on PATH in future terminal sessions.
persist_brew_path() {
  local brew_bin profile
  brew_bin="$(command -v brew)"

  case "${SHELL:-}" in
    */zsh)  profile="$HOME/.zprofile" ;;
    */bash) profile="$HOME/.bash_profile" ;;
    */fish)
      info "fish detected — add 'eval ($brew_bin shellenv)' to ~/.config/fish/config.fish manually"
      return 0
      ;;
    *) profile="$HOME/.profile" ;;
  esac

  if [ -f "$profile" ] && grep -q 'brew shellenv' "$profile" 2>/dev/null; then
    skip "brew already on PATH in $(basename "$profile")"
    return 0
  fi

  {
    printf '\n# Added by samba-onboarding\n'
    # shellcheck disable=SC2016  # we intentionally write $(...) literally to the profile
    printf 'eval "$(%s shellenv)"\n' "$brew_bin"
  } >> "$profile"
  info "Added brew to $(basename "$profile") (takes effect in new terminals)"
}

install_node_and_git() {
  install_node
  install_git
  install_jq
}

install_node() {
  if command -v node >/dev/null 2>&1; then
    local current
    current=$(node --version | sed 's/v//' | cut -d. -f1)
    if [ "${current:-0}" -ge 20 ] 2>/dev/null; then
      skip "Node $(node --version) already installed"
      return 0
    fi
    warn "Node v${current:-unknown} found; installing Node 20"
  fi

  run brew install node@20
  run brew link --overwrite --force node@20
  ok "Installed $(node --version)"
}

install_git() {
  if command -v git >/dev/null 2>&1; then
    skip "git $(git --version | awk '{print $3}') already installed"
    return 0
  fi
  run brew install git
  ok "Installed $(git --version)"
}

# install_jq — `jq` is required by lib/ui.sh:validate_oauth_json to parse and
# validate the GWS OAuth client_secret.json before installing it. macOS
# Sonoma+ ships /usr/bin/jq, but older macOS and Linux/WSL distros do not —
# so we install it explicitly via Homebrew (already on PATH after install_brew).
# Must run BEFORE step 5 (Installing Samba CLIs) so validate_oauth_json works.
install_jq() {
  if command -v jq >/dev/null 2>&1; then
    skip "jq $(jq --version) already installed"
    return 0
  fi
  run brew install jq
  ok "Installed $(jq --version)"
}
