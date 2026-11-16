---
name: vscode-setup
description: >-
  Audits or applies a VS Code setup that matches the Ghostty terminal:
  Catppuccin Mocha theme, JetBrains Mono Nerd Font with ligatures, the
  vscode-icons icon theme, .env and .gitignore highlighting, and official
  extensions with format-on-save for Terraform, Go, and JavaScript/TypeScript
  (ESLint, Prettier). Merges into the existing settings.json without losing
  other settings. Use when the user wants to set up, fix, theme, or sync VS Code,
  or install its extensions on macOS or Linux.
license: MIT
compatibility: macOS or Linux with VS Code (stable, Insiders or Flatpak) and python3.
metadata:
  repository: https://github.com/Hazurka/setup-agent
---

# VS Code Setup

Installs the extensions listed below and merges `assets/settings.json.template` into the user's `settings.json`. All paths are relative to this skill's directory.

## Workflow

1. **Audit first** (read-only):
   ```bash
   bash scripts/verify-or-install.sh --check
   ```
   Exit 0 = complete, 1 = something missing. It lists each missing extension and each template setting that is absent or different.

2. **Show the user the result and get approval.** Preview with:
   ```bash
   bash scripts/verify-or-install.sh --apply --dry-run
   ```

3. **Apply** after approval (`-y` because agents have no TTY):
   ```bash
   bash scripts/verify-or-install.sh --apply -y
   ```
   The script re-audits at the end and exits non-zero if anything is still missing.

## How settings.json is handled

- Parsed as JSONC, so comments and trailing commas are fine.
- **Deep merge:** only the keys in the template are set. Nested objects such as `files.associations` or `[go]` keep the user's other entries. Everything else is untouched.
- A timestamped backup (`settings.json.bak-<timestamp>`) is written before any change. Comments are not kept in the rewritten file but stay in the backup; mention this to the user if the script says so.
- If the file cannot be parsed, nothing is written and the script exits 1. Ask the user to fix the file rather than replacing it.
- The settings file is auto-detected (stable, Insiders, Flatpak). Override with `--settings <path>`.

## Extensions

Extension ID | Purpose
:-- | :--
`catppuccin.catppuccin-vsc` | Catppuccin Mocha theme (mauve accent)
`vscode-icons-team.vscode-icons` | File icon theme (`workbench.iconTheme`)
`hashicorp.terraform` | Terraform language server, `terraform fmt` on save
`golang.go` | Go support, organise imports on save
`dbaeumer.vscode-eslint` | ESLint
`esbenp.prettier-vscode` | Prettier, default formatter for JS/TS/JSON/HTML/CSS

## Notes

- If VS Code is missing: on macOS with Homebrew the apply step installs the `visual-studio-code` cask; on Linux it prints Microsoft's install page as a manual step.
- The font itself is installed by the `terminal-setup` skill; this skill only warns if it is missing.
