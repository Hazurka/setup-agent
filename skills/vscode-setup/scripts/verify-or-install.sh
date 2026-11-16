#!/usr/bin/env bash
# ==============================================================================
# verify-or-install.sh (vscode-setup)
# Audit or apply the VS Code setup that matches the Ghostty terminal:
#   Catppuccin Mocha, JetBrains Mono (Nerd) font with ligatures, vscode-icons,
#   .env/.gitignore highlighting, Terraform / Go / ESLint / Prettier tooling.
# settings.json is deep-merged (other settings kept) after a timestamped backup.
#
# Exit codes: 0 = complete (after apply: verified complete)
#             1 = something missing or a step failed
#             2 = usage / environment error
# Compatible with macOS /bin/bash 3.2.
# ==============================================================================

# Helpers below are invoked indirectly through try().
# shellcheck disable=SC2329

set -euo pipefail

MODE="check"
AUTO_CONFIRM=false
DRY_RUN=false
SETTINGS_PATH=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [--check | --apply] [options]

Modes:
  --check              Audit only, change nothing (default)
  --apply              Install missing extensions and merge settings.json

Options:
  -y, --yes            Do not prompt (required when there is no TTY, e.g. agents)
  --dry-run            With --apply: print what would change instead of changing it
  --settings <path>    Use this settings.json instead of auto-detecting
  -h, --help           Show this help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --apply|--install) MODE="apply" ;;
    --check|--audit)   MODE="check" ;;
    -y|--yes)          AUTO_CONFIRM=true ;;
    --dry-run)         DRY_RUN=true ;;
    --settings)
      [ $# -ge 2 ] || { echo "--settings needs a path" >&2; exit 2; }
      SETTINGS_PATH="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$SKILL_DIR/assets/settings.json.template"
SETTINGS_TOOL="$SKILL_DIR/scripts/vscode_settings.py"

# Test hook: the test-suite uses this to simulate other platforms.
OS_TYPE="${SETUP_AGENT_OS_TYPE:-$(uname -s)}"

EXTENSIONS=(
  catppuccin.catppuccin-vsc
  vscode-icons-team.vscode-icons
  hashicorp.terraform
  golang.go
  dbaeumer.vscode-eslint
  esbenp.prettier-vscode
)

FAILED_STEPS=()
MANUAL_STEPS=()

run() {
  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] $*"
    return 0
  fi
  "$@"
}

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
# Locate VS Code (stable, Insiders, Flatpak) and its settings.json
# ------------------------------------------------------------------------------
CODE_CLI=()

find_code_cli() {
  local c
  CODE_CLI=()
  for c in code code-insiders; do
    if command -v "$c" &>/dev/null; then
      CODE_CLI=("$c")
      return 0
    fi
  done
  if [ "$OS_TYPE" = "Darwin" ]; then
    for c in "/Applications/Visual Studio Code.app" "$HOME/Applications/Visual Studio Code.app"; do
      if [ -x "$c/Contents/Resources/app/bin/code" ]; then
        CODE_CLI=("$c/Contents/Resources/app/bin/code")
        return 0
      fi
    done
  elif command -v flatpak &>/dev/null && flatpak info com.visualstudio.code &>/dev/null; then
    CODE_CLI=(flatpak run com.visualstudio.code)
    return 0
  fi
  return 1
}

detect_settings_path() {
  local dir
  if [ "$OS_TYPE" = "Darwin" ]; then
    for dir in "$HOME/Library/Application Support/Code" "$HOME/Library/Application Support/Code - Insiders"; do
      if [ -d "$dir" ]; then
        echo "$dir/User/settings.json"
        return
      fi
    done
    echo "$HOME/Library/Application Support/Code/User/settings.json"
  else
    for dir in "$HOME/.config/Code" "$HOME/.var/app/com.visualstudio.code/config/Code" "$HOME/.config/Code - Insiders"; do
      if [ -d "$dir" ]; then
        echo "$dir/User/settings.json"
        return
      fi
    done
    echo "$HOME/.config/Code/User/settings.json"
  fi
}

[ -n "$SETTINGS_PATH" ] || SETTINGS_PATH="$(detect_settings_path)"

font_installed() {
  local f
  if [ "$OS_TYPE" = "Darwin" ]; then
    for f in "$HOME"/Library/Fonts/JetBrainsMono* /Library/Fonts/JetBrainsMono*; do
      [ -e "$f" ] && return 0
    done
    return 1
  fi
  # Capture first: `fc-list | grep -q` fails under pipefail (SIGPIPE).
  local fonts=""
  if command -v fc-list &>/dev/null; then
    fonts="$(fc-list 2>/dev/null || true)"
  fi
  if [ -z "$fonts" ]; then
    fonts="$(find /usr/share/fonts /usr/local/share/fonts "$HOME/.local/share/fonts" "$HOME/.fonts" \
      -iname '*JetBrains*Mono*' 2>/dev/null || true)"
  fi
  grep -qiE "JetBrains ?Mono" <<< "$fonts"
}

echo "======================================================================"
echo " VS Code Environment Audit (Catppuccin Mocha + JetBrains Mono)"
echo "======================================================================"
echo "[*] OS:            $OS_TYPE"
echo "[*] settings.json: $SETTINGS_PATH"
[ "$DRY_RUN" = true ] && echo "[*] Dry run:       commands are printed, not executed"

# ------------------------------------------------------------------------------
# Audit
# ------------------------------------------------------------------------------
MISSING=()
MISSING_EXTS=()
SETTINGS_STATE=0

audit() {
  MISSING=()
  MISSING_EXTS=()
  local installed ext

  echo ""
  echo "--> VS Code"
  if find_code_cli; then
    echo "[+] CLI: ${CODE_CLI[*]}"
  else
    echo "[-] VS Code CLI not found"
    MISSING+=(vscode)
  fi

  if ! command -v python3 &>/dev/null; then
    echo "[-] python3 not found (needed to merge settings.json)"
    MISSING+=(python3)
  fi

  echo ""
  echo "--> Extensions"
  if [ ${#CODE_CLI[@]} -gt 0 ]; then
    installed="$("${CODE_CLI[@]}" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"
    for ext in "${EXTENSIONS[@]}"; do
      if grep -qxF "$ext" <<< "$installed"; then
        echo "[+] $ext"
      else
        echo "[-] $ext: missing"
        MISSING_EXTS+=("$ext")
      fi
    done
    if [ ${#MISSING_EXTS[@]} -gt 0 ]; then MISSING+=(extensions); fi
  else
    echo "[-] skipped (no VS Code CLI)"
    MISSING_EXTS=("${EXTENSIONS[@]}")
  fi

  echo ""
  echo "--> settings.json"
  SETTINGS_STATE=0
  if command -v python3 &>/dev/null; then
    python3 -I "$SETTINGS_TOOL" check "$SETTINGS_PATH" "$TEMPLATE" || SETTINGS_STATE=$?
    if [ "$SETTINGS_STATE" -ne 0 ]; then MISSING+=(settings); fi
  fi

  echo ""
  echo "--> Font"
  if font_installed; then
    echo "[+] JetBrains Mono font installed"
  else
    echo "[!] JetBrains Mono font not found; the terminal-setup skill installs it"
  fi
}

audit

echo ""
echo "======================================================================"
if [ ${#MISSING[@]} -eq 0 ]; then
  echo "[OK] VS Code setup is complete."
  exit 0
fi
echo "[!] Missing: ${MISSING[*]}"

if [ "$MODE" != "apply" ]; then
  echo "Audit only. To apply, run:"
  echo "  $0 --apply"
  exit 1
fi

if [ "$SETTINGS_STATE" -eq 2 ]; then
  echo "[-] settings.json could not be parsed; fix it by hand before applying." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# Apply
# ------------------------------------------------------------------------------
if [ "$AUTO_CONFIRM" = false ] && [ "$DRY_RUN" = false ]; then
  if [ ! -t 0 ]; then
    echo "[-] No TTY to confirm on. Get the user's approval, then re-run with -y." >&2
    exit 2
  fi
  read -r -p "Apply VS Code extensions and settings now? [y/N] " resp
  case "$resp" in
    [yY][eE][sS]|[yY]) ;;
    *) echo "Aborted by user."; exit 1 ;;
  esac
fi

echo ""
echo "--> Step 1: VS Code"
if [ ${#CODE_CLI[@]} -eq 0 ]; then
  if [ "$OS_TYPE" = "Darwin" ] && command -v brew &>/dev/null; then
    try "install VS Code" run brew install --cask visual-studio-code
    if [ "$DRY_RUN" = false ]; then find_code_cli || true; fi
  else
    manual "Install VS Code from Microsoft's repository: https://code.visualstudio.com/docs/setup/linux"
  fi
fi

if ! command -v python3 &>/dev/null; then
  manual "Install python3 (needed to merge settings.json)"
fi

echo ""
echo "--> Step 2: Extensions"
if [ ${#CODE_CLI[@]} -gt 0 ] || [ "$DRY_RUN" = true ]; then
  for ext in ${MISSING_EXTS[@]+"${MISSING_EXTS[@]}"}; do
    try "install $ext" run ${CODE_CLI[@]+"${CODE_CLI[@]}"} --install-extension "$ext"
  done
else
  echo "[-] Skipped: no VS Code CLI"
fi

echo ""
echo "--> Step 3: settings.json (deep merge with backup)"
if command -v python3 &>/dev/null; then
  if [ "$DRY_RUN" = true ]; then
    python3 -I "$SETTINGS_TOOL" merge "$SETTINGS_PATH" "$TEMPLATE" --dry-run
  else
    try "merge settings.json" python3 -I "$SETTINGS_TOOL" merge "$SETTINGS_PATH" "$TEMPLATE"
  fi
fi

echo ""
echo "======================================================================"
if [ "$DRY_RUN" = true ]; then
  echo "[*] Dry run complete; nothing was changed."
  exit 0
fi

echo " Verification"
audit
echo ""
echo "======================================================================"
for step in ${FAILED_STEPS[@]+"${FAILED_STEPS[@]}"}; do echo "[!] Failed step: $step"; done
for step in ${MANUAL_STEPS[@]+"${MANUAL_STEPS[@]}"}; do echo "[*] Manual step: $step"; done
if [ ${#MISSING[@]} -eq 0 ] && [ ${#FAILED_STEPS[@]} -eq 0 ]; then
  echo "[OK] VS Code setup applied and verified."
  exit 0
fi
[ ${#MISSING[@]} -gt 0 ] && echo "[!] Still missing: ${MISSING[*]}"
exit 1
