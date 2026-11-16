#!/usr/bin/env bash
# ==============================================================================
# install.sh — make this repo's skills discoverable by every supported agent.
#
# Each skill in ./skills is symlinked into each agent's user-level skill folder,
# so `git pull` updates all agents at once:
#   codex        ~/.agents/skills         (OpenAI Codex, Gemini CLI, others)
#   claude       ~/.claude/skills         (Claude Code)
#   antigravity  ~/.gemini/config/skills  (Google Antigravity)
#
# An existing non-symlink folder with the same name is moved to
# ~/.local/share/setup-agent/backups/ (outside the skill folders, so agents
# don't load it twice).
# Compatible with macOS /bin/bash 3.2.
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
BACKUP_ROOT="$HOME/.local/share/setup-agent/backups"

ACTION="install"
AGENTS="codex,claude,antigravity"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--check | --uninstall] [--agents list]

  (default)        Symlink every skill into each agent's skill folder
  --check          Show where each skill is installed, change nothing
  --uninstall      Remove symlinks that point into this repo
  --agents list    Comma-separated subset of: codex, claude, antigravity
  -h, --help       Show this help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check)     ACTION="check" ;;
    --uninstall) ACTION="uninstall" ;;
    --agents)
      [ $# -ge 2 ] || { echo "--agents needs a value" >&2; exit 2; }
      AGENTS="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

agent_dir() {
  case "$1" in
    codex)       echo "$HOME/.agents/skills" ;;
    claude)      echo "$HOME/.claude/skills" ;;
    antigravity) echo "$HOME/.gemini/config/skills" ;;
    *) return 1 ;;
  esac
}

points_into_repo() {
  [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]
}

STATUS=0
TS="$(date +%Y%m%d%H%M%S)"

IFS=',' read -r -a AGENT_LIST <<< "$AGENTS"
for agent in "${AGENT_LIST[@]}"; do
  if ! dest_dir="$(agent_dir "$agent")"; then
    echo "Unknown agent: $agent (expected codex, claude or antigravity)" >&2
    exit 2
  fi
  echo "[$agent] $dest_dir"

  for src in "$SKILLS_SRC"/*/; do
    src="${src%/}"
    name="$(basename "$src")"
    dest="$dest_dir/$name"

    case "$ACTION" in
      check)
        if points_into_repo "$dest" "$src"; then
          echo "  [+] $name"
        elif [ -e "$dest" ] || [ -L "$dest" ]; then
          echo "  [~] $name exists but is not linked to this repo"
          STATUS=1
        else
          echo "  [-] $name not installed"
          STATUS=1
        fi
        ;;

      uninstall)
        if points_into_repo "$dest" "$src"; then
          rm "$dest"
          echo "  [-] removed $name"
        fi
        ;;

      install)
        mkdir -p "$dest_dir"
        if points_into_repo "$dest" "$src"; then
          echo "  [=] $name already linked"
          continue
        fi
        if [ -L "$dest" ]; then
          rm "$dest"
        elif [ -e "$dest" ]; then
          backup="$BACKUP_ROOT/$agent/$name-$TS"
          mkdir -p "$(dirname "$backup")"
          mv "$dest" "$backup"
          echo "  [*] moved existing $name to $backup"
        fi
        ln -s "$src" "$dest"
        echo "  [+] linked $name"
        ;;
    esac
  done
done

exit "$STATUS"
