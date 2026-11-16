#!/usr/bin/env bash
# install.sh in a throwaway $HOME: link, idempotency, backup of real folders,
# --check, --agents subset, --uninstall.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

FAKE_HOME="$(mktemp -d)"
trap 'rm -rf "$FAKE_HOME"' EXIT
export HOME="$FAKE_HOME"

# A pre-existing, non-symlink skill folder must be backed up, not deleted.
mkdir -p "$HOME/.claude/skills/terminal-setup"
echo "old" > "$HOME/.claude/skills/terminal-setup/SKILL.md"

capture "$REPO_DIR/install.sh"
assert_eq "install exits 0" "$RC" 0
for dir in .agents/skills .claude/skills .gemini/config/skills; do
  for skill in "$REPO_DIR"/skills/*/; do
    skill="${skill%/}"
    name="$(basename "$skill")"
    assert_eq "$dir/$name links to repo" "$(readlink "$HOME/$dir/$name")" "$skill"
  done
done
backup="$(find "$HOME/.local/share/setup-agent/backups/claude" -maxdepth 1 -name "terminal-setup-*" 2>/dev/null | head -1)"
assert_eq "existing folder backed up" "$(cat "$backup/SKILL.md" 2>/dev/null)" "old"

capture "$REPO_DIR/install.sh"
assert_contains "second run is idempotent" "$OUT" "already linked"
assert_not_contains "second run makes no new backups" "$OUT" "moved existing"

capture "$REPO_DIR/install.sh" --check
assert_eq "--check exits 0 when installed" "$RC" 0

capture "$REPO_DIR/install.sh" --uninstall --agents claude
assert_eq "uninstall exits 0" "$RC" 0
assert_true "claude links removed" [ ! -e "$HOME/.claude/skills/vscode-setup" ]
assert_true "other agents untouched" [ -L "$HOME/.agents/skills/vscode-setup" ]

capture "$REPO_DIR/install.sh" --check
assert_eq "--check exits 1 when something is missing" "$RC" 1

capture "$REPO_DIR/install.sh" --agents bogus
assert_eq "unknown agent rejected" "$RC" 2

finish
