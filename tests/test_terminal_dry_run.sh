#!/usr/bin/env bash
# Simulate each supported platform for terminal-setup without touching the
# machine: a fake $HOME, a fake /etc/os-release, a PATH with only system
# binaries plus stubs, and --dry-run so package commands are only printed.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

SCRIPT="$REPO_DIR/skills/terminal-setup/scripts/verify-or-install.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# simulate <os-type> <os-release content|-> <apt packages available> <extra stubs> -- <args...>
simulate() {
  local os_type="$1" release="$2" apt_pkgs="$3" stubs="$4"
  shift 5
  local home="$WORK/home-$RANDOM" bin="$WORK/bin-$RANDOM" s
  mkdir -p "$home" "$bin"
  printf '%s\n' "$release" > "$WORK/os-release"
  cat > "$bin/apt-cache" <<EOF
#!/bin/sh
for p in $apt_pkgs; do [ "\$2" = "\$p" ] && exit 0; done
exit 100
EOF
  # shellcheck disable=SC2016 # $1 belongs to the generated stub
  for s in $stubs; do printf '#!/bin/sh\n[ "$1" = info ] && exit 1\nexit 0\n' > "$bin/$s"; done
  chmod +x "$bin"/*
  capture env -i HOME="$home" PATH="$bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    HOMEBREW_PREFIX=/nonexistent SHELL=/bin/bash TERM=dumb SETUP_AGENT_ARCH="${SIM_ARCH:-x86_64}" \
    SETUP_AGENT_OS_TYPE="$os_type" SETUP_AGENT_OS_RELEASE="$WORK/os-release" \
    /bin/bash "$SCRIPT" "$@" </dev/null
  SIM_HOME="$home"
  SIM_BIN="$bin"
}

home_is_empty() {
  [ -z "$(find "$SIM_HOME" -mindepth 1 -print -quit)" ]
}

echo "Fedora"
simulate Linux $'ID=fedora\nPRETTY_NAME="Fedora Linux 43"' "" "" -- --apply --dry-run
assert_eq "exit 0" "$RC" 0
assert_contains "detects dnf" "$OUT" "Package Mgr:  dnf"
assert_contains "ghostty COPR" "$OUT" "sudo dnf copr enable -y scottames/ghostty"
assert_contains "core packages + font" "$OUT" "sudo dnf install -y eza fastfetch zsh-autosuggestions zsh-syntax-highlighting jetbrains-mono-fonts-all"
assert_contains "starship COPR" "$OUT" "sudo dnf copr enable -y atim/starship"
assert_contains "deploys zshrc" "$OUT" "[dry-run] cp $REPO_DIR/skills/terminal-setup/assets/zshrc.template"
assert_true "dry run leaves HOME untouched" home_is_empty

echo "openSUSE Tumbleweed x86_64"
simulate Linux $'ID="opensuse-tumbleweed"\nID_LIKE="opensuse suse"' "" "" -- --apply --dry-run
assert_contains "detects zypper" "$OUT" "Package Mgr:  zypper"
assert_contains "tools + fonts from OSS" "$OUT" "sudo zypper --non-interactive install eza starship fastfetch jetbrains-mono-fonts nerdfonts-symbolsonly-fonts"
assert_contains "plugins from zsh-users OBS" "$OUT" "addrepo --refresh https://download.opensuse.org/repositories/shells:zsh-users:zsh-autosuggestions/openSUSE_Tumbleweed/ zsh-users-zsh-autosuggestions"
assert_contains "installs plugin after adding repo" "$OUT" "sudo zypper --non-interactive install zsh-syntax-highlighting"

echo "openSUSE Leap 16.0 x86_64"
simulate Linux $'ID="opensuse-leap"\nID_LIKE="suse opensuse"\nVERSION_ID="16.0"' "" "" -- --apply --dry-run
assert_contains "Leap OBS target" "$OUT" "/openSUSE_Leap_16.0/"

echo "openSUSE Tumbleweed aarch64"
SIM_ARCH=aarch64 simulate Linux $'ID="opensuse-tumbleweed"\nID_LIKE="opensuse suse"' "" "" -- --apply --dry-run
assert_contains "no OBS build: manual step" "$OUT" "Manual step: zsh-autosuggestions has no openSUSE package for aarch64"
assert_not_contains "no OBS repo added" "$OUT" "addrepo"

echo "Debian 12 (nothing packaged, no PPA tool, no flatpak)"
simulate Linux $'ID=debian\nVERSION_ID="12"' "" "" -- --apply --dry-run
assert_contains "detects apt" "$OUT" "Package Mgr:  apt"
assert_contains "eza vendor repo" "$OUT" "deb.gierens.de stable main"
assert_contains "ghostty manual step" "$OUT" "Manual step: Install Ghostty"
assert_contains "fastfetch manual step" "$OUT" "Manual step: Install fastfetch"
assert_contains "starship manual step, no curl" "$OUT" "Manual step: Starship has no apt package"
assert_not_contains "never pipes curl to sh" "$OUT" "curl"

echo "Ubuntu 25.04 (everything packaged)"
simulate Linux $'ID=ubuntu\nID_LIKE=debian' "ghostty eza fastfetch starship" "" -- --apply --dry-run
assert_contains "ghostty from apt" "$OUT" "sudo apt-get install -y ghostty"
assert_contains "eza from apt" "$OUT" "sudo apt-get install -y eza"
assert_contains "starship from apt" "$OUT" "sudo apt-get install -y starship"
assert_contains "plugins + font" "$OUT" "sudo apt-get install -y zsh-autosuggestions zsh-syntax-highlighting fonts-jetbrains-mono"
assert_not_contains "no vendor repo needed" "$OUT" "gierens"

echo "Debian 12 never uses Ubuntu PPAs"
simulate Linux $'ID=debian' "" "add-apt-repository" -- --apply --dry-run
assert_not_contains "no PPA on Debian" "$OUT" "ppa:"

echo "Ubuntu 24.04 without add-apt-repository"
simulate Linux $'ID=ubuntu\nID_LIKE=debian' "" "" -- --apply --dry-run
assert_contains "installs software-properties-common" "$OUT" "sudo apt-get install -y software-properties-common"
assert_contains "then adds the PPA" "$OUT" "ppa:zhangsongcui3371/fastfetch"
assert_contains "apt-get update comes first" "$(printf '%s\n' "$OUT" | grep -m1 'dry-run] sudo')" "apt-get update"

echo "Ubuntu 22.04 with PPA tool and flatpak"
simulate Linux $'ID=ubuntu\nID_LIKE=debian' "" "add-apt-repository flatpak" -- --apply --dry-run
assert_contains "fastfetch PPA" "$OUT" "sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch"
assert_contains "ghostty via flathub" "$OUT" "flatpak install -y flathub com.mitchellh.ghostty"

echo "Linux Mint (ID_LIKE ubuntu)"
simulate Linux $'ID=linuxmint\nID_LIKE="ubuntu debian"' "" "" -- --check
assert_contains "mint maps to apt" "$OUT" "Package Mgr:  apt"
assert_eq "check exits 1 when incomplete" "$RC" 1

echo "Arch"
simulate Linux $'ID=arch' "" "" -- --apply --dry-run
assert_contains "ghostty from extra" "$OUT" "sudo pacman -S --needed --noconfirm ghostty"
assert_contains "tools + nerd font" "$OUT" "sudo pacman -S --needed --noconfirm eza starship fastfetch zsh-autosuggestions zsh-syntax-highlighting ttf-jetbrains-mono-nerd"

echo "Manjaro (ID_LIKE arch)"
simulate Linux $'ID=manjaro\nID_LIKE=arch' "" "" -- --check
assert_contains "manjaro maps to pacman" "$OUT" "Package Mgr:  pacman"

echo "Rocky Linux (unsupported)"
simulate Linux $'ID=rocky\nID_LIKE="rhel centos fedora"' "" "" -- --apply --dry-run
assert_contains "classified as rhel" "$OUT" "family: rhel"
assert_contains "refuses politely" "$OUT" "Unsupported distribution"
assert_eq "exit 2" "$RC" 2

echo "macOS without Homebrew"
simulate Darwin - "" "" -- --apply -y
assert_contains "asks for Homebrew" "$OUT" "Homebrew is required"
assert_eq "exit 2" "$RC" 2

echo "macOS with Homebrew (dry run)"
simulate Darwin - "" "brew" -- --apply --dry-run
assert_contains "brew formulas in one call" "$OUT" "brew install eza starship fastfetch zsh-autosuggestions zsh-syntax-highlighting"
assert_contains "nerd font cask" "$OUT" "brew install --cask font-jetbrains-mono-nerd-font"

echo "No TTY and no -y"
simulate Linux $'ID=arch' "" "" -- --apply
assert_eq "refuses to prompt, exit 2" "$RC" 2
assert_contains "explains -y" "$OUT" "re-run with -y"

echo "Real apply on simulated macOS (stub brew): configs deployed, re-audit honest"
simulate Darwin - "" "" -- --check
mkdir -p "$SIM_BIN"
cat > "$SIM_BIN/brew" <<EOF
#!/bin/sh
echo "brew \$*" >> "$WORK/brew.log"
EOF
chmod +x "$SIM_BIN/brew"
HOME_KEEP="$SIM_HOME"
run_real() {
  capture env -i HOME="$HOME_KEEP" PATH="$SIM_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
    HOMEBREW_PREFIX=/nonexistent SHELL=/bin/bash TERM=dumb SETUP_AGENT_OS_TYPE=Darwin \
    /bin/bash "$SCRIPT" "$@" </dev/null
}
run_real --apply -y
ASSETS="$(dirname "$SCRIPT")/../assets"
assert_true ".zshrc deployed" cmp -s "$HOME_KEEP/.zshrc" "$ASSETS/zshrc.template"
assert_true "starship.toml deployed" cmp -s "$HOME_KEEP/.config/starship.toml" "$ASSETS/starship.toml.template"
assert_contains "brew was called" "$(cat "$WORK/brew.log")" "install eza starship"
assert_eq "exit 1 because stub brew installed nothing" "$RC" 1
assert_contains "re-audit reports what is still missing" "$OUT" "Still missing:"

if command -v fastfetch >/dev/null; then
  echo "Broken fastfetch config is reported (real fastfetch)"
  FF_HOME="$WORK/ff-home"
  mkdir -p "$FF_HOME/.config/fastfetch"
  printf '{ "modules": [ "title", }' > "$FF_HOME/.config/fastfetch/config.jsonc"
  capture env -i HOME="$FF_HOME" PATH="$(dirname "$(command -v fastfetch)"):/usr/bin:/bin" TERM=dumb \
    /bin/bash "$SCRIPT" --check </dev/null
  assert_contains "broken config detected" "$OUT" "[-] fastfetch config fails to load"
  assert_contains "counted as missing" "$OUT" "valid fastfetch config"
fi

echo "# my tweak" >> "$HOME_KEEP/.zshrc"
run_real --check
assert_contains "customised config reported" "$OUT" "[~] differs:  $HOME_KEEP/.zshrc"
run_real --apply -y
assert_true "customised config kept by default" grep -q "# my tweak" "$HOME_KEEP/.zshrc"
run_real --apply -y --update-configs
assert_true "--update-configs replaces it" cmp -s "$HOME_KEEP/.zshrc" "$ASSETS/zshrc.template"
assert_true "old config backed up" grep -q "# my tweak" "$HOME_KEEP"/.zshrc.bak-*

finish
