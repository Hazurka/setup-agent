---
name: vscode-setup
description: >-
  Use this skill to configure, audit, maintain, or replicate the VS Code environment
  to aesthetically match Ghostty and the terminal setup (Catppuccin Mocha theme,
  JetBrains Mono Nerd Font typography, and coding ligatures) while preserving
  the user's existing icon theme (vscode-icons), enabling native syntax highlighting
  for .env and .gitignore files, and setting up official developer tooling for
  Terraform, Go, Node.js, and Frontend (ESLint, Prettier, format-on-save).
---

# VS Code Setup Skill (Synchronized with Ghostty & Developer Tooling)

This skill configures and verifies Visual Studio Code so its themes, colors, and typography match the Ghostty terminal environment, while strictly preserving your existing icon theme (`vscode-icons`), activating native `.env`/`.gitignore` syntax highlighting, and configuring official tooling for **Terraform**, **Go**, and **JavaScript / TypeScript / Frontend**.

## Core Configuration Principles

1. **Theme & Typography Match**:
   - Official **Catppuccin Mocha** color theme with **mauve** accent color.
   - **JetBrainsMono Nerd Font** with coding ligatures (`!=`, `=>`, `===`, `->`) enabled for both editor and integrated terminal.
2. **Preserve Icon Theme**: Retains `"workbench.iconTheme": "vscode-icons"`.
3. **Native Syntax Highlighting**:
   - `.gitignore`: Core `"ignore"` grammar (`git-base`).
   - `.env`: Core `"properties"` TextMate grammar (`source.ini`).
4. **Developer Tooling (Official Vendor Extensions Only)**:
   - **Terraform**: `HashiCorp.terraform` with automatic `terraform fmt` format on save.
   - **Go**: `golang.Go` (Go Team at Google) with `source.organizeImports` on save.
   - **JavaScript / TypeScript / Frontend**: `dbaeumer.vscode-eslint` (Microsoft) and `esbenp.prettier-vscode` (Prettier) with format on save.

---

## Configuration Reference: `settings.json`

macOS: `~/Library/Application Support/Code/User/settings.json`  
Linux: `~/.config/Code/User/settings.json`

```json
{
  "workbench.iconTheme": "vscode-icons",
  "workbench.colorTheme": "Catppuccin Mocha",
  "catppuccin.accentColor": "mauve",
  "editor.fontFamily": "'JetBrainsMono Nerd Font', 'JetBrains Mono', Menlo, Monaco, 'Courier New', monospace",
  "editor.fontSize": 14,
  "editor.lineHeight": 1.5,
  "editor.fontLigatures": true,
  "editor.semanticHighlighting.enabled": true,
  "terminal.integrated.fontFamily": "'JetBrainsMono Nerd Font', 'JetBrains Mono', monospace",
  "terminal.integrated.fontSize": 14,
  "terminal.integrated.lineHeight": 1.2,
  "terminal.integrated.minimumContrastRatio": 1,
  "window.titleBarStyle": "custom",
  "files.associations": {
    ".env*": "properties",
    "*.env": "properties",
    ".gitignore*": "ignore",
    "*ignore": "ignore"
  },
  "[terraform]": {
    "editor.defaultFormatter": "hashicorp.terraform",
    "editor.formatOnSave": true
  },
  "[terraform-vars]": {
    "editor.defaultFormatter": "hashicorp.terraform",
    "editor.formatOnSave": true
  },
  "[go]": {
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      "source.organizeImports": "always"
    }
  },
  "[go.mod]": {
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      "source.organizeImports": "always"
    }
  },
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[javascriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[typescriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[json]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[jsonc]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[html]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[css]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  }
}
```

---

## Installed Extensions (Vendor Official)

Extension ID                     | Description                          | Publisher / Vendor
:------------------------------- | :----------------------------------- | :-----------------
`Catppuccin.catppuccin-vsc`      | Catppuccin Theme                     | Catppuccin Team
`vscode-icons-team.vscode-icons` | Preserved File Icon Theme            | VSCode Icons Team
`hashicorp.terraform`            | Official Terraform HCL & Formatter   | HashiCorp
`golang.go`                      | Official Go language support & gopls | Go Team at Google
`dbaeumer.vscode-eslint`         | Official ESLint integration          | Microsoft
`esbenp.prettier-vscode`         | Official Prettier code formatter     | Prettier

---

## Audit & Apply Commands

```bash
# Audit VS Code setup:
~/.agents/skills/vscode-setup/scripts/verify-or-install.sh --check

# Apply VS Code setup:
~/.agents/skills/vscode-setup/scripts/verify-or-install.sh --apply
```
