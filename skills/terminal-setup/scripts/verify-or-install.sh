#!/usr/bin/env bash
# ==============================================================================
# verify-or-install.sh
# Multi-platform audit & installation script for modern terminal environment.
# Supported OS: macOS (Darwin), openSUSE, Fedora, Debian, Ubuntu, Arch.
# Shells: Bash & Zsh (full feature parity).
# Rule: Always favour official vendor package manager repositories for robust,
#       updatable installations.
# ==============================================================================

set -euo pipefail

MODE="check"
AUTO_CONFIRM=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="$(cd "${SCRIPT_DIR}/../resources" && pwd)"

for arg in "$@"; do
  case "$arg" in
    --apply|--install)
      MODE="apply"
      ;;
    -y|--yes)
      AUTO_CONFIRM=true
      ;;
    --check|--audit)
      MODE="check"
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--check|--apply] [-y]"
      echo "  --check   Audit system environment and report status (default)"
      echo "  --apply   Execute vendor-recommended package manager installations & configs"
      echo "  -y        Non-interactive mode (automatically confirm prompts)"
      exit 0
      ;;
  esac
done

echo "======================================================================"
echo " Modern Terminal Environment Inspector & Installer"
echo " (Vendor-Official Package Manager Driven)"
echo "======================================================================"

# ------------------------------------------------------------------------------
# 1. OS & Distribution Detection
# ------------------------------------------------------------------------------
OS_TYPE="$(uname -s)"
DISTRO="unknown"
DISTRO_FAMILY="unknown"
DISTRO_VERSION_ID=""
PKG_MGR="unknown"
SUDO_CMD=""

if [ "$OS_TYPE" = "Darwin" ]; then
  DISTRO="macOS"
  DISTRO_FAMILY="darwin"
  if command -v brew &>/dev/null; then
    PKG_MGR="brew"
  fi
elif [ "$OS_TYPE" = "Linux" ]; then
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO="${NAME:-Linux}"
    DISTRO_ID="${ID:-}"
    DISTRO_LIKE="${ID_LIKE:-}"
    DISTRO_VERSION_ID="${VERSION_ID:-}"

    if [[ "$DISTRO_ID" =~ (opensuse|suse) ]] || [[ "$DISTRO_LIKE" =~ (suse) ]]; then
      DISTRO_FAMILY="suse"
      PKG_MGR="zypper"
    elif [[ "$DISTRO_ID" =~ (fedora|rhel|centos|rocky|alma) ]] || [[ "$DISTRO_LIKE" =~ (fedora|rhel) ]]; then
      DISTRO_FAMILY="fedora"
      PKG_MGR="dnf"
    elif [[ "$DISTRO_ID" =~ (debian|ubuntu|pop|mint) ]] || [[ "$DISTRO_LIKE" =~ (debian|ubuntu) ]]; then
      DISTRO_FAMILY="debian"
      PKG_MGR="apt"
    elif [[ "$DISTRO_ID" =~ (arch|manjaro) ]] || [[ "$DISTRO_LIKE" =~ (arch) ]]; then
      DISTRO_FAMILY="arch"
      PKG_MGR="pacman"
    fi
  fi

  if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo &>/dev/null; then
      SUDO_CMD="sudo"
    else
      echo "[!] Warning: Script is not running as root and 'sudo' was not found."
    fi
  fi
fi

echo "[*] OS:           $OS_TYPE"
echo "[*] Distribution: $DISTRO (Family: $DISTRO_FAMILY)"
echo "[*] Package Mgr:  $PKG_MGR"
echo "[*] Architecture: $(uname -m)"
echo "[*] Current User: $(whoami)"
echo "[*] Active Shell: ${SHELL:-unknown}"

# ------------------------------------------------------------------------------
# 2. Check Terminal Emulator (Ghostty)
# ------------------------------------------------------------------------------
echo ""
echo "--> Checking Terminal Emulator (Ghostty)..."
HAS_GHOSTTY=false
if [ "$OS_TYPE" = "Darwin" ]; then
  if [ -d "/Applications/Ghostty.app" ]; then
    echo "[+] Ghostty: installed (/Applications/Ghostty.app)"
    HAS_GHOSTTY=true
  else
    echo "[-] Ghostty: missing from /Applications"
  fi
else
  if command -v ghostty &>/dev/null; then
    echo "[+] Ghostty: installed ($(command -v ghostty))"
    HAS_GHOSTTY=true
  else
    echo "[-] Ghostty: missing"
  fi
fi

# ------------------------------------------------------------------------------
# 3. Check Shells (Bash & Zsh)
# ------------------------------------------------------------------------------
echo ""
echo "--> Checking Shells (Bash & Zsh)..."

BASH_INSTALLED=false
if command -v bash &>/dev/null; then
  echo "[+] Bash: installed ($(command -v bash))"
  BASH_INSTALLED=true
else
  echo "[-] Bash: missing"
fi

ZSH_INSTALLED=false
if command -v zsh &>/dev/null; then
  ZSH_PATH="$(command -v zsh)"
  ZSH_VERSION_STR="$("$ZSH_PATH" --version 2>/dev/null || echo 'unknown')"
  echo "[+] Zsh:  installed at $ZSH_PATH ($ZSH_VERSION_STR)"
  ZSH_INSTALLED=true
else
  echo "[-] Zsh:  NOT installed (will be installed via $PKG_MGR during --apply)"
fi

# ------------------------------------------------------------------------------
# 4. Check Core CLI Tools
# ------------------------------------------------------------------------------
echo ""
echo "--> Checking CLI Tools..."

check_tool() {
  local tool="$1"
  if command -v "$tool" &>/dev/null; then
    local path
    path="$(command -v "$tool")"
    echo "[+] $tool: installed at $path"
    return 0
  else
    echo "[-] $tool: missing"
    return 1
  fi
}

HAS_EZA=false && check_tool eza && HAS_EZA=true || true
HAS_STARSHIP=false && check_tool starship && HAS_STARSHIP=true || true
HAS_FASTFETCH=false && check_tool fastfetch && HAS_FASTFETCH=true || true

# ------------------------------------------------------------------------------
# 5. Check Zsh Plugins
# ------------------------------------------------------------------------------
echo ""
echo "--> Checking Zsh Plugins..."

find_plugin() {
  local plugin_name="$1"
  local found=""
  local candidates=(
    "${HOMEBREW_PREFIX:-/opt/homebrew}/share/${plugin_name}/${plugin_name}.zsh"
    "/usr/local/share/${plugin_name}/${plugin_name}.zsh"
    "/usr/share/${plugin_name}/${plugin_name}.zsh"
    "/usr/share/zsh/plugins/${plugin_name}/${plugin_name}.zsh"
    "$HOME/.zsh/${plugin_name}/${plugin_name}.zsh"
  )

  for p in "${candidates[@]}"; do
    if [ -f "$p" ]; then
      found="$p"
      break
    fi
  done

  if [ -n "$found" ]; then
    echo "[+] $plugin_name: found at $found"
    return 0
  else
    echo "[-] $plugin_name: missing"
    return 1
  fi
}

HAS_AUTOSUGGESTIONS=false && find_plugin "zsh-autosuggestions" && HAS_AUTOSUGGESTIONS=true || true
HAS_SYNTAX_HIGHLIGHT=false && find_plugin "zsh-syntax-highlighting" && HAS_SYNTAX_HIGHLIGHT=true || true

# ------------------------------------------------------------------------------
# 6. Check Configuration Files
# ------------------------------------------------------------------------------
echo ""
echo "--> Checking Configuration Files..."

CONFIG_FILES=(
  "$HOME/.bash_profile"
  "$HOME/.bashrc"
  "$HOME/.zprofile"
  "$HOME/.zshrc"
  "$HOME/.config/ghostty/config"
  "$HOME/.config/starship.toml"
  "$HOME/.config/fastfetch/config.jsonc"
)

MISSING_CONFIGS=()
for cfg in "${CONFIG_FILES[@]}"; do
  if [ -f "$cfg" ]; then
    echo "[+] Config found: $cfg"
  else
    echo "[-] Config missing: $cfg"
    MISSING_CONFIGS+=("$cfg")
  fi
done

# Ghostty config validation
if [ "$OS_TYPE" = "Darwin" ] && [ -x "/Applications/Ghostty.app/Contents/MacOS/ghostty" ] && [ -f "$HOME/.config/ghostty/config" ]; then
  if /Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config --config-file="$HOME/.config/ghostty/config" &>/dev/null; then
    echo "[+] Ghostty config validation: passed"
  else
    echo "[!] Ghostty config validation: failed"
  fi
elif command -v ghostty &>/dev/null && [ -f "$HOME/.config/ghostty/config" ]; then
  if ghostty +validate-config --config-file="$HOME/.config/ghostty/config" &>/dev/null; then
    echo "[+] Ghostty config validation: passed"
  else
    echo "[!] Ghostty config validation: failed"
  fi
fi

# ------------------------------------------------------------------------------
# 7. Audit Summary
# ------------------------------------------------------------------------------
echo ""
echo "======================================================================"
echo " Audit Summary"
echo "======================================================================"

ALL_OK=true
[ "$HAS_GHOSTTY" = false ] && ALL_OK=false
[ "$BASH_INSTALLED" = false ] && ALL_OK=false
[ "$ZSH_INSTALLED" = false ] && ALL_OK=false
[ "$HAS_EZA" = false ] && ALL_OK=false
[ "$HAS_STARSHIP" = false ] && ALL_OK=false
[ "$HAS_FASTFETCH" = false ] && ALL_OK=false
[ "$HAS_AUTOSUGGESTIONS" = false ] && ALL_OK=false
[ "$HAS_SYNTAX_HIGHLIGHT" = false ] && ALL_OK=false
[ ${#MISSING_CONFIGS[@]} -gt 0 ] && ALL_OK=false

if [ "$ALL_OK" = true ]; then
  echo "[OK] All components, shells, and configurations are present and verified!"
  exit 0
fi

echo "[!] System has missing components or configurations."

if [ "$MODE" != "apply" ]; then
  echo ""
  echo "Inspection completed. To run vendor-recommended installations & setup, run:"
  echo "  $0 --apply"
  exit 0
fi

# ------------------------------------------------------------------------------
# 8. Apply Phase: Vendor-Official Package Manager Driven
# ------------------------------------------------------------------------------
if [ "$AUTO_CONFIRM" = false ]; then
  echo ""
  read -r -p "Proceed with package manager installation and configuration? [y/N] " resp
  case "$resp" in
    [yY][eE][sS]|[yY]) ;;
    *) echo "Aborted by user."; exit 0 ;;
  esac
fi

deploy_config() {
  local target="$1"
  local template="$2"

  if [ ! -f "$target" ]; then
    if [ -f "$template" ]; then
      echo "[+] Deploying $target from template..."
      mkdir -p "$(dirname "$target")"
      cp "$template" "$target"
    else
      echo "[-] Template $template not found."
    fi
  else
    echo "[*] Keeping existing: $target"
  fi
}

echo ""
echo "======================================================================"
echo " Step 1: Install & Configure Ghostty Terminal Emulator First"
echo " (Vendor official repo / maintainer endorsed)"
echo "======================================================================"
if [ "$HAS_GHOSTTY" = false ]; then
  case "$PKG_MGR" in
    brew)
      # macOS: Official vendor cask endorsed in Ghostty documentation
      echo "--> Installing Ghostty via official Homebrew cask..."
      brew install --cask ghostty
      ;;
    pacman)
      # Arch Linux: Official [extra] repository package
      echo "--> Installing Ghostty via pacman [extra]..."
      $SUDO_CMD pacman -S --noconfirm ghostty
      ;;
    dnf)
      # Fedora: Official Ghostty doc recommends scottames/ghostty COPR
      echo "--> Enabling vendor-recommended Ghostty COPR (scottames/ghostty)..."
      $SUDO_CMD dnf copr enable -y scottames/ghostty
      $SUDO_CMD dnf install -y ghostty
      ;;
    zypper)
      # openSUSE: Official OSS / X11:terminals repository
      echo "--> Installing Ghostty via zypper..."
      $SUDO_CMD zypper --non-interactive install ghostty || true
      ;;
    apt)
      # Debian / Ubuntu
      if apt-cache show ghostty &>/dev/null; then
        echo "--> Installing Ghostty via apt repository..."
        $SUDO_CMD apt-get install -y ghostty
      elif command -v flatpak &>/dev/null; then
        echo "--> Installing Ghostty via Flathub (official packaging)..."
        flatpak install -y flathub com.mitchellh.ghostty
      else
        echo "[*] For Debian/Ubuntu, Ghostty documentation recommends installing via"
        echo "    the official vendor .deb package from https://github.com/ghostty-org/ghostty/releases"
      fi
      ;;
  esac
fi

mkdir -p "$HOME/.config/ghostty"
deploy_config "$HOME/.config/ghostty/config" "$RESOURCES_DIR/ghostty.config.template"

echo ""
echo "======================================================================"
echo " Step 2: Setup & Configure Bash Environment (Immediate Parity)"
echo "======================================================================"
deploy_config "$HOME/.bash_profile" "$RESOURCES_DIR/bash_profile.template"
deploy_config "$HOME/.bashrc" "$RESOURCES_DIR/bashrc.template"
echo "[+] Bash environment configured with eza aliases, history, and Starship support."

echo ""
echo "======================================================================"
echo " Step 3: Install & Configure Zsh Shell"
echo "======================================================================"
if [ "$ZSH_INSTALLED" = false ]; then
  echo "--> Installing Zsh via official distribution package manager..."
  case "$PKG_MGR" in
    apt)    $SUDO_CMD apt-get update && $SUDO_CMD apt-get install -y zsh ;;
    dnf)    $SUDO_CMD dnf install -y zsh ;;
    zypper) $SUDO_CMD zypper --non-interactive install zsh ;;
    pacman) $SUDO_CMD pacman -S --noconfirm zsh ;;
    brew)   brew install zsh ;;
    *)      echo "[-] Please install zsh manually." ;;
  esac
fi

deploy_config "$HOME/.zprofile" "$RESOURCES_DIR/zprofile.template"
deploy_config "$HOME/.zshrc" "$RESOURCES_DIR/zshrc.template"
echo "[+] Zsh environment configured."

echo ""
echo "======================================================================"
echo " Step 4: Install Core CLI Tools via Official Vendor Repositories"
echo "======================================================================"
case "$PKG_MGR" in
  brew)
    # macOS / Linux Homebrew: Official bottles
    MISSING_BREW=()
    ! check_tool eza &>/dev/null && MISSING_BREW+=(eza)
    ! check_tool starship &>/dev/null && MISSING_BREW+=(starship)
    ! check_tool fastfetch &>/dev/null && MISSING_BREW+=(fastfetch)
    ! find_plugin "zsh-autosuggestions" &>/dev/null && MISSING_BREW+=(zsh-autosuggestions)
    ! find_plugin "zsh-syntax-highlighting" &>/dev/null && MISSING_BREW+=(zsh-syntax-highlighting)

    if [ ${#MISSING_BREW[@]} -gt 0 ]; then
      echo "--> Installing missing formulas via Homebrew: ${MISSING_BREW[*]}..."
      brew install "${MISSING_BREW[@]}"
    fi
    ;;

  dnf)
    # Fedora:
    # - eza: official Fedora core repos
    # - fastfetch: official Fedora core repos
    # - starship: official starship.rs doc recommends COPR atim/starship
    # - zsh plugins: official Fedora core repos
    $SUDO_CMD dnf install -y zsh-autosuggestions zsh-syntax-highlighting eza fastfetch || true

    if ! check_tool starship &>/dev/null; then
      echo "--> Enabling official Starship COPR (atim/starship) per starship.rs docs..."
      $SUDO_CMD dnf copr enable -y atim/starship
      $SUDO_CMD dnf install -y starship
    fi
    ;;

  zypper)
    # openSUSE:
    # - eza, starship, fastfetch, zsh plugins are in official openSUSE OSS repos
    echo "--> Installing packages via zypper (openSUSE official OSS)..."
    $SUDO_CMD zypper --non-interactive install \
      eza starship fastfetch zsh-autosuggestions zsh-syntax-highlighting || true
    ;;

  apt)
    # Debian / Ubuntu:
    $SUDO_CMD apt-get update
    $SUDO_CMD apt-get install -y zsh-autosuggestions zsh-syntax-highlighting

    # eza: Official eza-community apt repository (gierens.de) per eza INSTALL.md
    if ! check_tool eza &>/dev/null; then
      if apt-cache show eza &>/dev/null; then
        $SUDO_CMD apt-get install -y eza
      else
        echo "--> Adding official eza vendor repository (deb.gierens.de)..."
        $SUDO_CMD apt-get install -y gpg wget
        $SUDO_CMD mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | $SUDO_CMD gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | $SUDO_CMD tee /etc/apt/sources.list.d/gierens.list
        $SUDO_CMD chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        $SUDO_CMD apt-get update
        $SUDO_CMD apt-get install -y eza
      fi
    fi

    # fastfetch: Official vendor PPA (zhangsongcui3371) or native package per fastfetch docs
    if ! check_tool fastfetch &>/dev/null; then
      if apt-cache show fastfetch &>/dev/null; then
        $SUDO_CMD apt-get install -y fastfetch
      elif command -v add-apt-repository &>/dev/null; then
        echo "--> Adding official Fastfetch PPA (ppa:zhangsongcui3371/fastfetch)..."
        $SUDO_CMD add-apt-repository -y ppa:zhangsongcui3371/fastfetch
        $SUDO_CMD apt-get update
        $SUDO_CMD apt-get install -y fastfetch
      fi
    fi

    # starship: Native apt or official starship.rs installer
    if ! check_tool starship &>/dev/null; then
      if apt-cache show starship &>/dev/null; then
        $SUDO_CMD apt-get install -y starship
      else
        echo "--> Installing Starship via official starship.rs vendor script..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
      fi
    fi
    ;;

  pacman)
    # Arch Linux: Official [extra] repos
    echo "--> Installing packages via pacman..."
    $SUDO_CMD pacman -S --noconfirm eza starship fastfetch zsh-autosuggestions zsh-syntax-highlighting || true
    ;;
esac

# Deploy shared configuration templates
mkdir -p "$HOME/.config/fastfetch"
deploy_config "$HOME/.config/starship.toml" "$RESOURCES_DIR/starship.toml.template"
deploy_config "$HOME/.config/fastfetch/config.jsonc" "$RESOURCES_DIR/fastfetch.jsonc.template"

# ------------------------------------------------------------------------------
# 9. Shell Switch Guidance
# ------------------------------------------------------------------------------
if command -v zsh &>/dev/null; then
  ZSH_BIN="$(command -v zsh)"
  if [ "${SHELL:-}" != "$ZSH_BIN" ]; then
    echo ""
    echo "[*] Notice: Current login shell is '$SHELL'."
    echo "    To set Zsh as your default shell, run:"
    echo "      chsh -s \"$ZSH_BIN\""
  fi
fi

echo ""
echo "[+] Modern terminal setup successfully applied via official vendor package managers!"
