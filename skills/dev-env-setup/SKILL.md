---
name: dev-env-setup
description: >-
  Sets up or audits the user's whole developer workstation in one pass by
  running the terminal-setup skill (Ghostty, Bash/Zsh, Starship, eza,
  Fastfetch, JetBrains Mono font) and then the vscode-setup skill (Catppuccin
  Mocha, extensions, settings.json). Use when the user asks to set up a new
  machine, bootstrap their environment, or check that everything is in place;
  for a single area use terminal-setup or vscode-setup directly.
license: MIT
compatibility: Requires the terminal-setup and vscode-setup skills installed next to this one.
metadata:
  repository: https://github.com/Hazurka/setup-agent
---

# Developer Environment Setup

Runs the two sibling skills in order. The terminal goes first because it installs the font VS Code uses. Paths are relative to this skill's directory.

## Workflow

1. Audit both (read-only):
   ```bash
   bash ../terminal-setup/scripts/verify-or-install.sh --check
   bash ../vscode-setup/scripts/verify-or-install.sh --check
   ```
2. Summarise what is missing for the user in one short list and ask for approval. If both audits exit 0, report that everything is in place and stop.
3. Apply only the parts that were incomplete, terminal first:
   ```bash
   bash ../terminal-setup/scripts/verify-or-install.sh --apply -y
   bash ../vscode-setup/scripts/verify-or-install.sh --apply -y
   ```
4. Report the final verification of each script, including any failed or manual steps.

Follow the rules in `../terminal-setup/SKILL.md` and `../vscode-setup/SKILL.md` (sudo, Homebrew, `--update-configs` only on explicit request). If the sibling directories are not found, tell the user to install the full repository with its `install.sh`.
