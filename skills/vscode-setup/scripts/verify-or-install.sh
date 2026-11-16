#!/usr/bin/env bash
# ==============================================================================
# verify-or-install.sh (vscode-setup)
# Multi-platform audit & installation script for VS Code environment.
# Supported OS: macOS & Linux.
# Preserves icon theme ("vscode-icons") while synchronizing:
#   - Catppuccin Mocha theme & palette
#   - JetBrains Mono Nerd Font typography & coding ligatures
#   - Terminal font & contrast settings
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
      echo "  --check   Audit VS Code setup and report status (default)"
      echo "  --apply   Install Catppuccin extension and configure settings.json"
      echo "  -y        Non-interactive mode (automatically confirm prompts)"
      exit 0
      ;;
  esac
done

echo "======================================================================"
echo " VS Code Environment Inspector & Installer"
echo " (Synchronized with Ghostty, Catppuccin Mocha & JetBrains Mono)"
echo "======================================================================"

OS_TYPE="$(uname -s)"
SETTINGS_PATH=""

if [ "$OS_TYPE" = "Darwin" ]; then
  SETTINGS_PATH="$HOME/Library/Application Support/Code/User/settings.json"
else
  SETTINGS_PATH="$HOME/.config/Code/User/settings.json"
fi

echo "[*] OS:             $OS_TYPE"
echo "[*] Settings Path:  $SETTINGS_PATH"

# 1. Check VS Code CLI
HAS_CODE_CLI=false
if command -v code &>/dev/null; then
  echo "[+] VS Code CLI:   found ($(which code))"
  HAS_CODE_CLI=true
else
  echo "[-] VS Code CLI:   not found in PATH"
fi

# 2. Check Extensions
HAS_CATPPUCCIN_EXT=false
HAS_ICONS_EXT=false
HAS_TERRAFORM_EXT=false
HAS_GO_EXT=false
HAS_ESLINT_EXT=false
HAS_PRETTIER_EXT=false

if [ "$HAS_CODE_CLI" = true ]; then
  EXT_LIST="$(code --list-extensions 2>/dev/null || true)"
  if echo "$EXT_LIST" | grep -qi "Catppuccin.catppuccin-vsc"; then
    echo "[+] Catppuccin Theme Extension: installed"
    HAS_CATPPUCCIN_EXT=true
  else
    echo "[-] Catppuccin Theme Extension: missing"
  fi

  if echo "$EXT_LIST" | grep -qi "vscode-icons"; then
    echo "[+] Icon Theme Extension (vscode-icons): preserved & installed"
    HAS_ICONS_EXT=true
  else
    echo "[!] Icon Theme Extension (vscode-icons): missing"
  fi

  if echo "$EXT_LIST" | grep -qi "hashicorp.terraform"; then
    echo "[+] Terraform Extension (hashicorp.terraform): installed"
    HAS_TERRAFORM_EXT=true
  else
    echo "[-] Terraform Extension (hashicorp.terraform): missing"
  fi

  if echo "$EXT_LIST" | grep -qi "golang.go"; then
    echo "[+] Go Extension (golang.go): installed"
    HAS_GO_EXT=true
  else
    echo "[-] Go Extension (golang.go): missing"
  fi

  if echo "$EXT_LIST" | grep -qi "dbaeumer.vscode-eslint"; then
    echo "[+] ESLint Extension (dbaeumer.vscode-eslint): installed"
    HAS_ESLINT_EXT=true
  else
    echo "[-] ESLint Extension (dbaeumer.vscode-eslint): missing"
  fi

  if echo "$EXT_LIST" | grep -qi "esbenp.prettier-vscode"; then
    echo "[+] Prettier Extension (esbenp.prettier-vscode): installed"
    HAS_PRETTIER_EXT=true
  else
    echo "[-] Prettier Extension (esbenp.prettier-vscode): missing"
  fi
fi

# 3. Check settings.json
HAS_SETTINGS_FILE=false
COLOR_THEME_OK=false
ICON_THEME_OK=false
FONT_OK=false
ASSOCIATIONS_OK=false

if [ -f "$SETTINGS_PATH" ]; then
  HAS_SETTINGS_FILE=true
  echo "[+] settings.json found."

  if grep -q '"workbench.colorTheme": *"Catppuccin Mocha"' "$SETTINGS_PATH"; then
    echo "[+] workbench.colorTheme: Catppuccin Mocha"
    COLOR_THEME_OK=true
  else
    echo "[-] workbench.colorTheme: not set to Catppuccin Mocha"
  fi

  if grep -q '"workbench.iconTheme": *"vscode-icons"' "$SETTINGS_PATH"; then
    echo "[+] workbench.iconTheme: vscode-icons (preserved)"
    ICON_THEME_OK=true
  else
    echo "[-] workbench.iconTheme: not set to vscode-icons"
  fi

  if grep -q "JetBrains" "$SETTINGS_PATH"; then
    echo "[+] Editor & Terminal Font: JetBrains Mono configured"
    FONT_OK=true
  else
    echo "[-] Editor & Terminal Font: JetBrains Mono not configured"
  fi

  if grep -q '"\.env\*"' "$SETTINGS_PATH" && grep -q '"\.gitignore\*"' "$SETTINGS_PATH"; then
    echo "[+] Syntax Highlighting: .env and .gitignore associations configured"
    ASSOCIATIONS_OK=true
  else
    echo "[-] Syntax Highlighting: .env and .gitignore associations missing"
  fi
else
  echo "[-] settings.json not found."
fi

# 4. Summary
echo ""
echo "======================================================================"
echo " Audit Summary"
echo "======================================================================"

ALL_OK=true
[ "$HAS_CATPPUCCIN_EXT" = false ] && ALL_OK=false
[ "$HAS_TERRAFORM_EXT" = false ] && ALL_OK=false
[ "$HAS_GO_EXT" = false ] && ALL_OK=false
[ "$HAS_ESLINT_EXT" = false ] && ALL_OK=false
[ "$HAS_PRETTIER_EXT" = false ] && ALL_OK=false
[ "$HAS_SETTINGS_FILE" = false ] && ALL_OK=false
[ "$COLOR_THEME_OK" = false ] && ALL_OK=false
[ "$ICON_THEME_OK" = false ] && ALL_OK=false
[ "$FONT_OK" = false ] && ALL_OK=false
[ "$ASSOCIATIONS_OK" = false ] && ALL_OK=false

if [ "$ALL_OK" = true ]; then
  echo "[OK] VS Code styling and developer tooling are fully operational!"
  exit 0
fi

echo "[!] VS Code setup needs configuration or missing extensions."

if [ "$MODE" != "apply" ]; then
  echo ""
  echo "Audit completed. To apply changes, run:"
  echo "  $0 --apply"
  exit 0
fi

# 5. Apply
if [ "$AUTO_CONFIRM" = false ]; then
  echo ""
  read -r -p "Apply VS Code configuration and extensions now? [y/N] " resp
  case "$resp" in
    [yY][eE][sS]|[yY]) ;;
    *) echo "Aborted by user."; exit 0 ;;
  esac
fi

if [ "$HAS_CODE_CLI" = true ]; then
  [ "$HAS_CATPPUCCIN_EXT" = false ] && code --install-extension Catppuccin.catppuccin-vsc
  [ "$HAS_TERRAFORM_EXT" = false ] && code --install-extension HashiCorp.terraform
  [ "$HAS_GO_EXT" = false ] && code --install-extension golang.Go
  [ "$HAS_ESLINT_EXT" = false ] && code --install-extension dbaeumer.vscode-eslint
  [ "$HAS_PRETTIER_EXT" = false ] && code --install-extension esbenp.prettier-vscode
fi

mkdir -p "$(dirname "$SETTINGS_PATH")"
if [ ! -f "$SETTINGS_PATH" ]; then
  echo "--> Deploying settings.json from template..."
  cp "$RESOURCES_DIR/settings.json.template" "$SETTINGS_PATH"
else
  # Use python to safely merge settings without destroying other keys
  python3 -c '
import json, sys

path = sys.argv[1]
template_path = sys.argv[2]

try:
    with open(path, "r") as f:
        data = json.load(f)
except Exception:
    data = {}

with open(template_path, "r") as f:
    template = json.load(f)

for k, v in template.items():
    data[k] = v

with open(path, "w") as f:
    json.dump(data, f, indent=4)
print("[+] Successfully merged settings into " + path)
' "$SETTINGS_PATH" "$RESOURCES_DIR/settings.json.template"
fi

echo "[+] VS Code setup applied successfully!"
