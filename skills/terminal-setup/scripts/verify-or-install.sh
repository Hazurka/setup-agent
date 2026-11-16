#!/usr/bin/env bash
# ==============================================================================
# verify-or-install.sh (terminal-setup)
# Audit or apply the modern terminal environment on macOS and Linux:
#   Ghostty, Bash + Zsh (feature parity), Starship, eza, Fastfetch,
#   zsh-autosuggestions, zsh-syntax-highlighting, JetBrains Mono (Nerd) font.
# Rule: install only through native package managers using vendor-official
#       repositories. Anything else is reported as a manual step, never piped
#       from curl.
#
# Exit codes: 0 = environment complete (after apply: verified complete)
#             1 = components missing or a step failed
#             2 = usage / unsupported environment
# Compatible with macOS /bin/bash 3.2.
# ==============================================================================

# Helpers below are invoked indirectly through try().
# shellcheck disable=SC2329

set -euo pipefail

MODE="check"
AUTO_CONFIRM=false
DRY_RUN=false
SHOW_DIFF=false
UPDATE_CONFIGS=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [--check | --apply] [options]

Modes:
  --check            Audit only, change nothing (default)
  --apply            Install missing packages and deploy missing configs

Options:
  -y, --yes          Do not prompt (required when there is no TTY, e.g. agents)
  --dry-run          With --apply: print every command instead of running it
  --diff             Show a unified diff for configs that differ from templates
  --update-configs   With --apply: replace configs that differ from templates
                     (the old file is kept as <file>.bak-<timestamp>)
  -h, --help         Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --apply|--install) MODE="apply" ;;
    --check|--audit)   MODE="check" ;;
    -y|--yes)          AUTO_CONFIRM=true ;;
    --dry-run)         DRY_RUN=true ;;
    --diff)            SHOW_DIFF=true ;;
    --update-configs)  UPDATE_CONFIGS=true ;;
    -h|--help)         usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS_DIR="$SKILL_DIR/assets"

# Test hooks: the test-suite uses these to simulate other platforms.
OS_TYPE="${SETUP_AGENT_OS_TYPE:-$(uname -s)}"
OS_RELEASE_FILE="${SETUP_AGENT_OS_RELEASE:-/etc/os-release}"
ARCH="${SETUP_AGENT_ARCH:-$(uname -m)}"

FAILED_STEPS=()
MANUAL_STEPS=()

# ------------------------------------------------------------------------------
# Command helpers
# ------------------------------------------------------------------------------
run() {
  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] $*"
    return 0
  fi
  "$@"
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    run "$@"
  elif [ "$DRY_RUN" = true ] || command -v sudo &>/dev/null; then
    run sudo "$@"
  else
    echo "[-] Need root for '$*' but sudo is not available." >&2
    return 1
  fi
}

# try <label> <command...>: run a step, record (not abort on) failure.
try() {
  local label="$1"
  shift
  if ! "$@"; then
    echo "[!] Step failed: $label"
    FAILED_STEPS+=("$label")
  fi
}

manual() {
  echo "[*] Manual step: $1"
  MANUAL_STEPS+=("$1")
}

# ------------------------------------------------------------------------------
# 1. OS & distribution detection
# ------------------------------------------------------------------------------
DISTRO="unknown"
DISTRO_FAMILY="unknown"
IS_UBUNTU=false
OBS_TARGET=""
PKG_MGR="none"

if [ "$OS_TYPE" = "Darwin" ]; then
  DISTRO="macOS"
  DISTRO_FAMILY="darwin"
  command -v brew &>/dev/null && PKG_MGR="brew"
elif [ "$OS_TYPE" = "Linux" ] && [ -f "$OS_RELEASE_FILE" ]; then
  # Read in a subshell so os-release variables don't leak into this script.
  OS_INFO="$(
    # shellcheck disable=SC1090
    . "$OS_RELEASE_FILE"
    echo "${ID:-}|${ID_LIKE:-}|${VERSION_ID:-}|${PRETTY_NAME:-${NAME:-Linux}}"
  )"
  OS_ID="${OS_INFO%%|*}"
  OS_REST="${OS_INFO#*|}"
  OS_LIKE="${OS_REST%%|*}"
  OS_REST="${OS_REST#*|}"
  OS_VERSION="${OS_REST%%|*}"
  DISTRO="${OS_REST#*|}"
  IDS=" $OS_ID $OS_LIKE "

  if [ "$OS_ID" = "fedora" ]; then
    DISTRO_FAMILY="fedora"
  else
    case "$IDS" in
      *" rhel "*|*" centos "*) DISTRO_FAMILY="rhel" ;;  # COPRs used here are Fedora-only
      *suse*)                  DISTRO_FAMILY="suse" ;;
      *" arch "*)              DISTRO_FAMILY="arch" ;;
      *" debian "*|*" ubuntu "*) DISTRO_FAMILY="debian" ;;
      *" fedora "*)            DISTRO_FAMILY="fedora" ;;
    esac
  fi

  case "$IDS" in *" ubuntu "*) IS_UBUNTU=true ;; esac
  case "$OS_ID" in
    opensuse-tumbleweed|opensuse-slowroll) OBS_TARGET="openSUSE_Tumbleweed" ;;
    opensuse-leap) OBS_TARGET="openSUSE_Leap_$OS_VERSION" ;;
  esac

  case "$DISTRO_FAMILY" in
    fedora) PKG_MGR="dnf" ;;
    suse)   PKG_MGR="zypper" ;;
    arch)   PKG_MGR="pacman" ;;
    debian) PKG_MGR="apt" ;;
  esac
fi

echo "======================================================================"
echo " Terminal Environment Audit (vendor-official package managers)"
echo "======================================================================"
echo "[*] OS:           $OS_TYPE ($ARCH)"
echo "[*] Distribution: $DISTRO (family: $DISTRO_FAMILY)"
echo "[*] Package Mgr:  $PKG_MGR"
echo "[*] Login Shell:  ${SHELL:-unknown}"
[ "$DRY_RUN" = true ] && echo "[*] Dry run:      commands are printed, not executed"

# ------------------------------------------------------------------------------
# 2. Audit
# ------------------------------------------------------------------------------
CONFIG_PAIRS=(
  "$HOME/.bash_profile|bash_profile.template"
  "$HOME/.bashrc|bashrc.template"
  "$HOME/.zprofile|zprofile.template"
  "$HOME/.zshrc|zshrc.template"
  "$HOME/.config/ghostty/config|ghostty.config.template"
  "$HOME/.config/starship.toml|starship.toml.template"
  "$HOME/.config/fastfetch/config.jsonc|fastfetch.jsonc.template"
)

ghostty_bin() {
  local app
  if [ "$OS_TYPE" = "Darwin" ]; then
    for app in "/Applications/Ghostty.app" "$HOME/Applications/Ghostty.app"; do
      if [ -x "$app/Contents/MacOS/ghostty" ]; then
        echo "$app/Contents/MacOS/ghostty"
        return 0
      fi
    done
    return 1
  fi
  command -v ghostty
}

has_ghostty() {
  ghostty_bin &>/dev/null && return 0
  [ "$OS_TYPE" = "Linux" ] && command -v flatpak &>/dev/null &&
    flatpak info com.mitchellh.ghostty &>/dev/null
}

find_plugin() {
  local name="$1" p
  for p in \
    "${HOMEBREW_PREFIX:-/opt/homebrew}/share/$name/$name.zsh" \
    "/usr/local/share/$name/$name.zsh" \
    "/home/linuxbrew/.linuxbrew/share/$name/$name.zsh" \
    "/usr/share/$name/$name.zsh" \
    "/usr/share/zsh/plugins/$name/$name.zsh" \
    "$HOME/.zsh/$name/$name.zsh"; do
    if [ -f "$p" ]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

# Prints "nerd", "plain" or nothing. Output is captured before grepping:
# `fc-list | grep -q` fails under pipefail when grep exits early (SIGPIPE).
font_status() {
  local f fonts=""
  if [ "$OS_TYPE" = "Darwin" ]; then
    for f in "$HOME"/Library/Fonts/JetBrainsMono*Nerd* /Library/Fonts/JetBrainsMono*Nerd*; do
      if [ -e "$f" ]; then
        echo "nerd"
        return 0
      fi
    done
    return 0
  fi
  if command -v fc-list &>/dev/null; then
    fonts="$(fc-list 2>/dev/null || true)"
  fi
  # Without fontconfig (minimal installs), look at the font files themselves.
  if [ -z "$fonts" ]; then
    fonts="$(find /usr/share/fonts /usr/local/share/fonts "$HOME/.local/share/fonts" "$HOME/.fonts" \
      -iname '*JetBrains*Mono*' 2>/dev/null || true)"
  fi
  if grep -qiE "JetBrainsMono ?Nerd" <<< "$fonts"; then
    echo "nerd"
  elif grep -qiE "JetBrains ?Mono" <<< "$fonts"; then
    echo "plain"
  fi
}

# cmp/diff live in diffutils, which minimal openSUSE/Fedora installs lack.
same_file() {
  [ "$(cksum < "$1")" = "$(cksum < "$2")" ]
}

MISSING=()

audit() {
  MISSING=()
  local tool path pair target template font err

  echo ""
  echo "--> Terminal emulator"
  if has_ghostty; then
    echo "[+] ghostty: $(ghostty_bin 2>/dev/null || echo 'flatpak com.mitchellh.ghostty')"
  else
    echo "[-] ghostty: missing"
    MISSING+=(ghostty)
  fi

  echo ""
  echo "--> Shells & CLI tools"
  for tool in bash zsh eza starship fastfetch; do
    if path="$(command -v "$tool")"; then
      echo "[+] $tool: $path"
    else
      echo "[-] $tool: missing"
      MISSING+=("$tool")
    fi
  done

  echo ""
  echo "--> Zsh plugins"
  for tool in zsh-autosuggestions zsh-syntax-highlighting; do
    if path="$(find_plugin "$tool")"; then
      echo "[+] $tool: $path"
    else
      echo "[-] $tool: missing"
      MISSING+=("$tool")
    fi
  done

  echo ""
  echo "--> Font"
  font="$(font_status)"
  case "$font" in
    nerd)  echo "[+] JetBrainsMono Nerd Font: installed" ;;
    plain) echo "[+] JetBrains Mono: installed (no Nerd glyphs outside Ghostty; see SKILL.md)" ;;
    *)     echo "[-] JetBrains Mono font: missing"; MISSING+=(font) ;;
  esac

  echo ""
  echo "--> Config files"
  CONFIGS_DIFFER=()
  for pair in "${CONFIG_PAIRS[@]}"; do
    target="${pair%%|*}"
    template="$ASSETS_DIR/${pair#*|}"
    if [ ! -f "$target" ]; then
      echo "[-] missing:  $target"
      MISSING+=("$target")
    elif same_file "$target" "$template"; then
      echo "[+] current:  $target"
    else
      echo "[~] differs:  $target (kept; --diff to view, --update-configs to replace)"
      CONFIGS_DIFFER+=("$pair")
      if [ "$SHOW_DIFF" = true ] && command -v diff &>/dev/null; then
        diff -u "$target" "$template" || true
      fi
    fi
  done

  if path="$(ghostty_bin 2>/dev/null)" && [ -f "$HOME/.config/ghostty/config" ]; then
    if "$path" +validate-config --config-file="$HOME/.config/ghostty/config" &>/dev/null; then
      echo "[+] ghostty config validates"
    else
      echo "[-] ghostty config fails validation (run: ghostty +validate-config)"
      MISSING+=("valid ghostty config")
    fi
  fi

  # fastfetch exits 0 even for a broken config; errors only appear on stderr.
  if command -v fastfetch &>/dev/null && [ -f "$HOME/.config/fastfetch/config.jsonc" ]; then
    err="$(fastfetch --config "$HOME/.config/fastfetch/config.jsonc" --pipe 2>&1 >/dev/null || true)"
    if grep -q "Error" <<< "$err"; then
      echo "[-] fastfetch config fails to load: $(head -n 1 <<< "$err")"
      MISSING+=("valid fastfetch config")
    else
      echo "[+] fastfetch config loads"
    fi
  fi
}

CONFIGS_DIFFER=()
audit

echo ""
echo "======================================================================"
if [ ${#MISSING[@]} -eq 0 ] && { [ "$UPDATE_CONFIGS" = false ] || [ ${#CONFIGS_DIFFER[@]} -eq 0 ]; }; then
  echo "[OK] Terminal environment is complete."
  exit 0
fi
if [ ${#MISSING[@]} -gt 0 ]; then
  echo "[!] Missing: ${MISSING[*]}"
fi

if [ "$MODE" != "apply" ]; then
  echo "Audit only. To install/deploy the missing pieces run:"
  echo "  $0 --apply"
  exit 1
fi

# ------------------------------------------------------------------------------
# 3. Apply
# ------------------------------------------------------------------------------
if [ "$PKG_MGR" = "none" ]; then
  if [ "$OS_TYPE" = "Darwin" ]; then
    echo "[-] Homebrew is required on macOS. Install it from https://brew.sh, then re-run." >&2
  else
    echo "[-] Unsupported distribution '$DISTRO' (family: $DISTRO_FAMILY)." >&2
    echo "    Supported: macOS, Fedora, openSUSE, Debian/Ubuntu, Arch." >&2
  fi
  exit 2
fi

if [ "$AUTO_CONFIRM" = false ] && [ "$DRY_RUN" = false ]; then
  if [ ! -t 0 ]; then
    echo "[-] No TTY to confirm on. Get the user's approval, then re-run with -y." >&2
    exit 2
  fi
  read -r -p "Proceed with installation and configuration? [y/N] " resp
  case "$resp" in
    [yY][eE][sS]|[yY]) ;;
    *) echo "Aborted by user."; exit 1 ;;
  esac
fi

is_missing() {
  local item
  for item in ${MISSING[@]+"${MISSING[@]}"}; do
    [ "$item" = "$1" ] && return 0
  done
  return 1
}

pkg_available_apt() { apt-cache show "$1" &>/dev/null; }

deploy_config() {
  local target="$1" template="$2"
  if [ ! -f "$template" ]; then
    echo "[-] Template not found: $template"
    return 1
  fi
  if [ ! -f "$target" ]; then
    echo "[+] Deploying $target"
    run mkdir -p "$(dirname "$target")" && run cp "$template" "$target"
  elif [ "$UPDATE_CONFIGS" = true ] && ! same_file "$target" "$template"; then
    local backup
    backup="$target.bak-$(date +%Y%m%d%H%M%S)"
    echo "[+] Replacing $target (backup: $backup)"
    run cp -p "$target" "$backup" && run cp "$template" "$target"
  fi
}

add_zsh_users_obs_repo() {
  # Explicit alias: the project's .repo file would name it after the plugin only.
  local alias="zsh-users-$1"
  if zypper --non-interactive repos "$alias" &>/dev/null; then
    return 0
  fi
  as_root zypper --non-interactive addrepo --refresh \
    "https://download.opensuse.org/repositories/shells:zsh-users:$1/$OBS_TARGET/" "$alias" || return 1
  # download.opensuse.org redirects to mirrors that are occasionally stale: retry once.
  as_root zypper --non-interactive --gpg-auto-import-keys refresh "$alias" ||
    as_root zypper --non-interactive --gpg-auto-import-keys refresh --force "$alias"
}

add_eza_apt_repo() {
  # Per https://github.com/eza-community/eza/blob/main/INSTALL.md
  as_root apt-get install -y gpg wget || return 1
  as_root mkdir -p /etc/apt/keyrings || return 1
  as_root sh -c 'wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor --yes -o /etc/apt/keyrings/gierens.gpg' || return 1
  as_root sh -c 'echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" > /etc/apt/sources.list.d/gierens.list' || return 1
  as_root chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list || return 1
  as_root apt-get update
}

if [ "$PKG_MGR" = apt ]; then
  # Refresh package lists first: availability checks below use apt-cache.
  try "apt-get update" as_root apt-get update
fi

echo ""
echo "--> Step 1: Ghostty"
if is_missing ghostty; then
  case "$PKG_MGR" in
    brew)   try "install ghostty" run brew install --cask ghostty ;;
    pacman) try "install ghostty" as_root pacman -S --needed --noconfirm ghostty ;;
    dnf)
      try "enable ghostty COPR" as_root dnf copr enable -y scottames/ghostty
      try "install ghostty" as_root dnf install -y ghostty
      ;;
    zypper) try "install ghostty" as_root zypper --non-interactive install ghostty ;;
    apt)
      if pkg_available_apt ghostty; then
        try "install ghostty" as_root apt-get install -y ghostty
      elif command -v flatpak &>/dev/null; then
        try "install ghostty (flathub)" run flatpak install -y flathub com.mitchellh.ghostty
      else
        manual "Install Ghostty for Debian/Ubuntu following https://ghostty.org/docs/install/binary"
      fi
      ;;
  esac
fi
try "deploy ghostty config" deploy_config "$HOME/.config/ghostty/config" "$ASSETS_DIR/ghostty.config.template"

echo ""
echo "--> Step 2: Bash configuration"
try "deploy ~/.bash_profile" deploy_config "$HOME/.bash_profile" "$ASSETS_DIR/bash_profile.template"
try "deploy ~/.bashrc" deploy_config "$HOME/.bashrc" "$ASSETS_DIR/bashrc.template"

echo ""
echo "--> Step 3: Zsh"
if is_missing zsh; then
  case "$PKG_MGR" in
    brew)   try "install zsh" run brew install zsh ;;
    apt)    try "install zsh" as_root apt-get install -y zsh ;;
    dnf)    try "install zsh" as_root dnf install -y zsh ;;
    zypper) try "install zsh" as_root zypper --non-interactive install zsh ;;
    pacman) try "install zsh" as_root pacman -S --needed --noconfirm zsh ;;
  esac
fi
try "deploy ~/.zprofile" deploy_config "$HOME/.zprofile" "$ASSETS_DIR/zprofile.template"
try "deploy ~/.zshrc" deploy_config "$HOME/.zshrc" "$ASSETS_DIR/zshrc.template"

echo ""
echo "--> Step 4: CLI tools, plugins & font"
case "$PKG_MGR" in
  brew)
    FORMULAS=()
    for item in eza starship fastfetch zsh-autosuggestions zsh-syntax-highlighting; do
      if is_missing "$item"; then FORMULAS+=("$item"); fi
    done
    if [ ${#FORMULAS[@]} -gt 0 ]; then try "brew install ${FORMULAS[*]}" run brew install "${FORMULAS[@]}"; fi
    if is_missing font; then try "install font" run brew install --cask font-jetbrains-mono-nerd-font; fi
    ;;

  dnf)
    # eza, fastfetch, plugins, font: Fedora repos. starship: atim/starship COPR (starship.rs docs).
    PKGS=()
    for item in eza fastfetch zsh-autosuggestions zsh-syntax-highlighting; do
      if is_missing "$item"; then PKGS+=("$item"); fi
    done
    if is_missing font; then PKGS+=(jetbrains-mono-fonts-all); fi
    if [ ${#PKGS[@]} -gt 0 ]; then try "dnf install ${PKGS[*]}" as_root dnf install -y "${PKGS[@]}"; fi
    if is_missing starship; then
      try "enable starship COPR" as_root dnf copr enable -y atim/starship
      try "install starship" as_root dnf install -y starship
    fi
    ;;

  zypper)
    # Tools and fonts: openSUSE OSS. nerdfonts-symbolsonly-fonts adds the
    # Nerd glyphs the prompt uses to the plain JetBrains Mono.
    PKGS=()
    for item in eza starship fastfetch; do
      if is_missing "$item"; then PKGS+=("$item"); fi
    done
    if is_missing font; then PKGS+=(jetbrains-mono-fonts nerdfonts-symbolsonly-fonts); fi
    if [ ${#PKGS[@]} -gt 0 ]; then try "zypper install ${PKGS[*]}" as_root zypper --non-interactive install "${PKGS[@]}"; fi

    # The Zsh plugins are not in OSS; zsh-users publishes them on OBS
    # (shells:zsh-users:<plugin>), built for x86_64 only.
    for item in zsh-autosuggestions zsh-syntax-highlighting; do
      is_missing "$item" || continue
      if [ "$ARCH" = x86_64 ] && [ -n "$OBS_TARGET" ]; then
        try "add OBS repo shells:zsh-users:$item" add_zsh_users_obs_repo "$item"
        try "install $item" as_root zypper --non-interactive install "$item"
      else
        manual "$item has no openSUSE package for $ARCH; clone https://github.com/zsh-users/$item into ~/.zsh/$item"
      fi
    done
    ;;

  pacman)
    PKGS=()
    for item in eza starship fastfetch zsh-autosuggestions zsh-syntax-highlighting; do
      if is_missing "$item"; then PKGS+=("$item"); fi
    done
    if is_missing font; then PKGS+=(ttf-jetbrains-mono-nerd); fi
    if [ ${#PKGS[@]} -gt 0 ]; then try "pacman install ${PKGS[*]}" as_root pacman -S --needed --noconfirm "${PKGS[@]}"; fi
    ;;

  apt)
    PKGS=()
    for item in zsh-autosuggestions zsh-syntax-highlighting; do
      if is_missing "$item"; then PKGS+=("$item"); fi
    done
    if is_missing font; then PKGS+=(fonts-jetbrains-mono); fi
    if [ ${#PKGS[@]} -gt 0 ]; then try "apt install ${PKGS[*]}" as_root apt-get install -y "${PKGS[@]}"; fi

    if is_missing eza; then
      if pkg_available_apt eza; then
        try "install eza" as_root apt-get install -y eza
      else
        try "add eza vendor repo (deb.gierens.de)" add_eza_apt_repo
        try "install eza" as_root apt-get install -y eza
      fi
    fi

    if is_missing fastfetch; then
      if pkg_available_apt fastfetch; then
        try "install fastfetch" as_root apt-get install -y fastfetch
      elif [ "$IS_UBUNTU" = true ]; then
        # PPAs are Ubuntu-only; add-apt-repository ships in software-properties-common.
        if ! command -v add-apt-repository &>/dev/null; then
          try "install software-properties-common" as_root apt-get install -y software-properties-common
        fi
        try "add fastfetch PPA" as_root add-apt-repository -y ppa:zhangsongcui3371/fastfetch
        try "install fastfetch" as_root apt-get install -y fastfetch
      else
        manual "Install fastfetch from https://github.com/fastfetch-cli/fastfetch/releases (.deb)"
      fi
    fi

    if is_missing starship; then
      if pkg_available_apt starship; then
        try "install starship" as_root apt-get install -y starship
      else
        manual "Starship has no apt package before Debian 13 / Ubuntu 25.04; install per https://starship.rs/guide/"
      fi
    fi
    ;;
esac

echo ""
echo "--> Step 5: Shared configs"
try "deploy starship.toml" deploy_config "$HOME/.config/starship.toml" "$ASSETS_DIR/starship.toml.template"
try "deploy fastfetch config" deploy_config "$HOME/.config/fastfetch/config.jsonc" "$ASSETS_DIR/fastfetch.jsonc.template"

if command -v zsh &>/dev/null && [ "${SHELL:-}" != "$(command -v zsh)" ] && [ "${SHELL:-}" != "/bin/zsh" ]; then
  echo ""
  echo "[*] Login shell is '${SHELL:-unknown}'. To switch to Zsh (asks for your password):"
  echo "      chsh -s \"$(command -v zsh)\""
fi

# ------------------------------------------------------------------------------
# 4. Verify
# ------------------------------------------------------------------------------
echo ""
echo "======================================================================"
if [ "$DRY_RUN" = true ]; then
  echo "[*] Dry run complete; nothing was changed."
  exit 0
fi

hash -r
UPDATE_CONFIGS=false
SHOW_DIFF=false
echo " Verification"
audit
echo ""
echo "======================================================================"
for step in ${FAILED_STEPS[@]+"${FAILED_STEPS[@]}"}; do echo "[!] Failed step: $step"; done
for step in ${MANUAL_STEPS[@]+"${MANUAL_STEPS[@]}"}; do echo "[*] Manual step: $step"; done
if [ ${#MISSING[@]} -eq 0 ] && [ ${#FAILED_STEPS[@]} -eq 0 ]; then
  echo "[OK] Terminal environment applied and verified."
  exit 0
fi
[ ${#MISSING[@]} -gt 0 ] && echo "[!] Still missing: ${MISSING[*]}"
exit 1
