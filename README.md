# setup-agent

Agent skills that audit and set up a developer workstation on macOS and Linux:

- **terminal-setup**: Ghostty, Bash and Zsh with the same features, Starship prompt, eza, Fastfetch, zsh-autosuggestions, zsh-syntax-highlighting and the JetBrains Mono Nerd Font.
- **vscode-setup**: VS Code with Catppuccin Mocha, JetBrains Mono with ligatures, vscode-icons, and official Terraform, Go, ESLint and Prettier extensions with format-on-save.
- **dev-env-setup**: runs both, terminal first.

The skills follow the open [Agent Skills](https://agentskills.io/specification) format (`SKILL.md` plus `scripts/` and `assets/`). Claude Code, OpenAI Codex, Google Antigravity, Gemini CLI and other compatible agents can all use them.

Packages come only from native package managers and vendor-official repositories (Homebrew, dnf + vendor COPRs, zypper, apt + vendor repos/PPAs, pacman). There is no `curl | sh`.

## Install

```bash
git clone https://github.com/Hazurka/setup-agent.git ~/Projects/setup-agent
~/Projects/setup-agent/install.sh
```

`install.sh` symlinks each skill into every agent's user-level skill folder. A later `git pull` then updates all agents:

| Agent | Folder |
| :-- | :-- |
| OpenAI Codex, Gemini CLI | `~/.agents/skills/` |
| Claude Code | `~/.claude/skills/` |
| Google Antigravity | `~/.gemini/config/skills/` |

Options: `--check` (show status), `--uninstall`, `--agents claude,codex` (subset). If a folder with the same name already exists, it is moved to `~/.local/share/setup-agent/backups/`.

**Claude Code plugin (alternative):** this repo is also a plugin marketplace:

```
/plugin marketplace add Hazurka/setup-agent
/plugin install setup-agent@setup-agent
```

## Use

Ask your agent, e.g. *"set up my terminal"*, *"check my VS Code setup"* or *"bootstrap this new machine"*. The agent audits first, shows you what is missing, and applies changes only after you approve.

The scripts also work by hand:

```bash
bash skills/terminal-setup/scripts/verify-or-install.sh --check          # audit (default)
bash skills/terminal-setup/scripts/verify-or-install.sh --check --diff   # show config drift
bash skills/terminal-setup/scripts/verify-or-install.sh --apply --dry-run
bash skills/terminal-setup/scripts/verify-or-install.sh --apply
bash skills/vscode-setup/scripts/verify-or-install.sh --check
bash skills/vscode-setup/scripts/verify-or-install.sh --apply
```

Safety:

- Your existing dotfiles are never overwritten unless you pass `--update-configs`. Replaced files are kept as `<file>.bak-<timestamp>`.
- VS Code's `settings.json` is read as JSONC and deep-merged, so your other settings stay. It is backed up before every write, and never written if it can't be parsed.
- Each apply ends with a fresh audit. The exit code is non-zero if anything is still missing.

## Supported platforms

macOS (Homebrew), Fedora, openSUSE, Debian/Ubuntu (and derivatives), Arch (and derivatives). RHEL-family distributions are detected and reported as unsupported.

## Development

```bash
tests/run.sh
```

The test suite runs shellcheck, validates every `SKILL.md` against the Agent Skills spec, unit-tests the settings merge, tests `install.sh` in a throwaway `$HOME`, and dry-runs the terminal script against simulated macOS, Fedora, openSUSE, Debian, Ubuntu, Arch and Rocky systems.

## License

MIT
