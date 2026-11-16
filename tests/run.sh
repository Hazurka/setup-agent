#!/usr/bin/env bash
# Run the whole test suite. Requires shellcheck and python3.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

STATUS=0
section() { echo ""; echo "== $1"; }
check() { "$@" || STATUS=1; }

section "shellcheck"
SCRIPTS=(install.sh skills/*/scripts/*.sh tests/*.sh)
if shellcheck -s bash -x "${SCRIPTS[@]}"; then
  echo "  ok   ${#SCRIPTS[@]} scripts"
else
  STATUS=1
fi

section "bash -n with /bin/bash (3.2 on macOS)"
for f in "${SCRIPTS[@]}"; do check /bin/bash -n "$f"; done
echo "  done"

section "SKILL.md spec"
check python3 -I tests/validate_skills.py

section "assets parse"
check python3 -I -c 'import json; json.load(open("skills/vscode-setup/assets/settings.json.template"))'
if command -v zsh >/dev/null; then check zsh -n skills/terminal-setup/assets/zshrc.template skills/terminal-setup/assets/zprofile.template; fi
check /bin/bash -n skills/terminal-setup/assets/bashrc.template
check /bin/bash -n skills/terminal-setup/assets/bash_profile.template
echo "  done"

section "vscode_settings.py"
check python3 -I tests/test_vscode_settings.py

section "install.sh"
check /bin/bash tests/test_install.sh

section "vscode-setup script"
check /bin/bash tests/test_vscode_script.sh

section "terminal-setup platform simulations"
check /bin/bash tests/test_terminal_dry_run.sh

echo ""
if [ "$STATUS" -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "SOME TESTS FAILED"; fi
exit "$STATUS"
