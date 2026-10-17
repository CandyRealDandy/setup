#!/usr/bin/env bash
# Sets up this machine from CandyRealDandy's dotfiles. The setup itself lives in
# a private repo, so this only gets GitHub's command line tool (gh), logs in to
# GitHub in the browser, then runs that setup. In a terminal:
#
#   curl -fsSL https://raw.githubusercontent.com/CandyRealDandy/setup/main/install.sh | bash
#
# Options go to the setup as they are, e.g. `... | bash -s -- --profile work --yes`.
# Settings (for testing): SETUP_GITHUB_USER, SETUP_PRIVATE, SETUP_TTY, SETUP_OS_RELEASE.

OWNER=${SETUP_GITHUB_USER:-CandyRealDandy}
PRIVATE=${SETUP_PRIVATE:-repos/CandyRealDandy/dotfiles/contents/setup/install.sh}
OS_RELEASE=${SETUP_OS_RELEASE:-/etc/os-release}
# Answers come from the terminal: with `curl … | bash`, stdin is this script.
if [[ -n ${SETUP_TTY:-} ]]; then TTY=$SETUP_TTY
elif [[ -t 0 ]]; then TTY=/dev/stdin
else TTY=/dev/tty
fi

say() { printf '%s\n' "$*" >&2; }
fail() { printf 'setup: %s\n' "$*" >&2; }

as_root() {
  if [[ $(id -u) == 0 ]]; then "$@"
  elif command -v sudo >/dev/null 2>&1; then sudo "$@"
  else fail "installing needs root, and sudo isn't installed"; return 1
  fi
}

brew_env() {
  local brew
  for brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x $brew ]]; then eval "$("$brew" shellenv)"; fi
  done
  command -v brew >/dev/null 2>&1
}

install_gh_linux() {
  local ids
  # shellcheck disable=SC1090  # os-release is shell assignments by design
  ids=$( . "$OS_RELEASE" 2>/dev/null && printf '%s %s' "${ID:-}" "${ID_LIKE:-}")
  case " $ids " in
    *" arch "*) as_root pacman -Syu --needed --noconfirm github-cli ;;
    *" debian "* | *" ubuntu "*) as_root apt-get update && as_root apt-get install -y gh ;;
    *) fail "this Linux (${ids%% *}) isn't supported: Ubuntu, Debian and Arch are"; return 2 ;;
  esac
}

install_gh() {
  local kernel script
  kernel=$(uname -s)
  case $kernel in
    Darwin)
      brew_env || {
        say "Installing Homebrew (it asks for your password)..."
        script=$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh) &&
          bash -c "$script" <&3 && brew_env
      } || return 1
      brew install gh ;;
    Linux) install_gh_linux ;;
    MINGW* | MSYS* | CYGWIN*) fail "on Windows, run install.ps1 in PowerShell"; return 2 ;;
    *) fail "$kernel isn't supported"; return 2 ;;
  esac
}

main() {
  local login previous script status
  { exec 3<"$TTY"; } 2>/dev/null || { exec 3</dev/null; NO_TERMINAL=1; }
  # macOS: with the full Xcode app, its license gates git, Homebrew and gh.
  if [[ $(uname -s) == Darwin && $(xcode-select -p 2>/dev/null) == *Xcode*.app* ]] &&
    ! xcodebuild -license check >/dev/null 2>&1; then
    fail "Xcode's license isn't accepted yet, and macOS blocks git until it is: run sudo xcodebuild -license (read it, type agree), then run this again"
    return 1
  fi
  if ! command -v gh >/dev/null 2>&1; then
    say "gh (GitHub's command line tool) is needed to get the private setup."
    printf 'Install it now? [Y/n] ' >&2
    if [[ " $* " == *" --yes "* ]]; then say "yes (--yes)"
    elif ! { read -r reply <&3 && [[ -z $reply || $reply == [yY]* ]]; }; then
      say; fail "gh is needed to get the private setup; nothing installed"; return 1
    fi
    install_gh
    status=$?
    ((status == 2)) && return 1
    ((status == 0)) || { fail "installing gh failed"; return 1; }
  fi
  login=$(gh api user --jq .login 2>/dev/null)
  previous=$login
  if [[ $login != "$OWNER" ]]; then
    if [[ -z $login ]] || ! gh auth switch --hostname github.com --user "$OWNER" >/dev/null 2>&1; then
      if [[ -n ${NO_TERMINAL:-} ]]; then
        fail "logging in to GitHub needs a terminal: run this in a terminal window"; return 1
      fi
      say "Log in to GitHub as $OWNER: gh opens the browser."
      local skip=""  # the setup uploads the SSH key itself
      gh auth login --help 2>/dev/null | grep -q -- --skip-ssh-key && skip=--skip-ssh-key
      # shellcheck disable=SC2086  # $skip is one flag or nothing
      gh auth login --hostname github.com --git-protocol ssh --web --scopes admin:public_key $skip <&3 ||
        { fail "GitHub login failed"; return 1; }
    fi
    login=$(gh api user --jq .login 2>/dev/null)
    if [[ $login != "$OWNER" ]]; then
      fail "gh is logged in to GitHub as ${login:-nobody}, not $OWNER: log in as $OWNER (gh auth login), then run this again"
      return 1
    fi
  fi
  script=$(gh api "$PRIVATE" -H 'Accept: application/vnd.github.raw' 2>/dev/null)
  status=$?
  # gh back to the account that was active (e.g. work, on a work machine).
  if [[ -n $previous && $previous != "$OWNER" ]]; then
    gh auth switch --hostname github.com --user "$previous" >/dev/null 2>&1
  fi
  if ((status)) || [[ -z $script ]]; then
    fail "couldn't download the setup from the private dotfiles repo as $OWNER"; return 1
  fi
  exec bash -c "$script" install.sh "$@"
}

main "$@"
