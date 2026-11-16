#!/usr/bin/env bash
# vscode-setup end to end with a stub `code` CLI that remembers installed
# extensions, and a temporary settings.json.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

SCRIPT="$REPO_DIR/skills/vscode-setup/scripts/verify-or-install.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home"

cat > "$WORK/bin/code" <<EOF
#!/bin/sh
db="$WORK/extensions"
touch "\$db"
case "\$1" in
  --list-extensions) cat "\$db" ;;
  --install-extension) echo "\$2" >> "\$db"; echo "installed \$2" ;;
esac
EOF
chmod +x "$WORK/bin/code"
printf 'Catppuccin.catppuccin-vsc\nvscode-icons-team.vscode-icons\n' > "$WORK/extensions"

SETTINGS="$WORK/settings.json"
printf '{\n  // keep me\n  "editor.tabSize": 2,\n  "files.associations": { "*.mdx": "markdown", },\n}\n' > "$SETTINGS"

vs() {
  capture env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" TERM=dumb \
    /bin/bash "$SCRIPT" --settings "$SETTINGS" "$@" </dev/null
}

vs --check
assert_eq "check exits 1" "$RC" 1
assert_contains "case-insensitive match for installed ext" "$OUT" "[+] catppuccin.catppuccin-vsc"
assert_contains "lists missing ext" "$OUT" "[-] golang.go: missing"
assert_contains "lists differing settings" "$OUT" "workbench.colorTheme"

vs --apply --dry-run
assert_contains "dry-run shows install" "$OUT" "[dry-run] code --install-extension golang.go"
assert_contains "dry-run shows settings change" "$OUT" "[dry-run] would update"
assert_not_contains "dry-run installs nothing" "$(cat "$WORK/extensions")" "golang.go"

vs --apply
assert_eq "no TTY without -y exits 2" "$RC" 2

vs --apply -y
assert_eq "apply exits 0 after verification" "$RC" 0
assert_contains "verified" "$OUT" "[OK] VS Code setup applied and verified."
assert_not_contains "already-installed ext not reinstalled" "$OUT" "installed vscode-icons-team.vscode-icons"
merged="$(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["editor.tabSize"], d["files.associations"]["*.mdx"], d["workbench.colorTheme"])' "$SETTINGS")"
assert_eq "user settings kept, template applied" "$merged" "2 markdown Catppuccin Mocha"
assert_true "backup written" [ -n "$(find "$WORK" -name "settings.json.bak-*")" ]

vs --check
assert_eq "second check exits 0" "$RC" 0

printf '{ broken' > "$SETTINGS"
vs --apply -y
assert_eq "unparseable settings: apply refuses" "$RC" 1
assert_eq "unparseable settings left untouched" "$(cat "$SETTINGS")" "{ broken"

finish
