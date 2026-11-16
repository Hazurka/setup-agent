# setup-agent

I got tired of setting up my terminal and VS Code from scratch every time I switched machines. Every new laptop or fresh Linux install meant the same routine: install Ghostty, fix the prompt, hunt down the right font, copy dotfiles around, remember which VS Code extensions I actually use. So I turned my setup into a skill my AI agent can run for me.

Now I just open Claude Code, Codex or Antigravity and say:

> *"Set up my dev environment."*

The agent checks what's missing, shows me a list, and only installs things after I say yes. I wanted it to work with whatever agent I happen to be using that day, so it's built on the open [Agent Skills](https://agentskills.io/specification) format. That means it should work with **Claude Code**, **OpenAI Codex**, **Google Antigravity**, **Gemini CLI** and any other agent that supports skills.

It's tuned to my taste (Catppuccin Mocha everywhere, JetBrains Mono, Zsh + Starship), but everything lives in plain template files, so it's easy to make it yours.

**Feel free to use it, fork it and bend it to your own setup.** If you add support for another distro, a new tool or a different editor, or you just find a bug, issues and pull requests are very welcome. 🙌

## What you get

| | |
| :-- | :-- |
| **Terminal** | [Ghostty](https://ghostty.org) with the Catppuccin Mocha theme and JetBrains Mono font |
| **Shell** | Zsh *and* Bash, configured the same way: history, completion, autosuggestions, syntax highlighting |
| **Prompt** | [Starship](https://starship.rs): git status plus Node, Go, Terraform, React, Angular and Vue info when you're in such a project |
| **Tools** | [eza](https://eza.rocks) (a nicer `ls` with icons) and [Fastfetch](https://github.com/fastfetch-cli/fastfetch) (system info when a terminal opens) |
| **VS Code** | Catppuccin Mocha, JetBrains Mono with ligatures, vscode-icons, `.env` and `.gitignore` highlighting, and format-on-save for Terraform, Go and JS/TS (ESLint + Prettier) |

Everything is installed with your system's own package manager (Homebrew, dnf, zypper, apt or pacman), from official sources only.

---

## Quick start

### 1. Before you begin

You need `git`. Then, depending on your system:

- **macOS:** install [Homebrew](https://brew.sh) if you don't have it:
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```
- **Linux:** make sure your user can run `sudo`.

### 2. Download and install the skills

```bash
git clone https://github.com/Hazurka/setup-agent.git ~/Projects/setup-agent
~/Projects/setup-agent/install.sh
```

This makes the skills available to all supported agents at once. You should see a `[+] linked …` line for each skill and agent.

### 3. Ask your agent

Open your agent (for example `claude`, `codex` or `agy`) in any folder and ask:

| Say this | What happens |
| :-- | :-- |
| *"Set up my dev environment"* | Terminal, then VS Code |
| *"Set up my terminal"* | Only the terminal, shell, prompt and tools |
| *"Set up VS Code"* | Only VS Code |
| *"Check my dev environment"* | Report what's missing, change nothing |

The agent will:

1. **Check** your machine and list what's missing.
2. **Ask** before changing anything.
3. **Install** the missing pieces.
4. **Help with leftovers.** If something can't be installed automatically (e.g. Ghostty on Debian), it suggests an official alternative and waits for your OK.
5. **Re-check** until everything passes.

### 4. Open a new terminal

Open Ghostty (or a new terminal window) to see the result. If your login shell isn't Zsh yet, the setup prints the `chsh` command that switches it.

---

## Running it without an agent

The skills are plain scripts, so you can run them yourself:

```bash
cd ~/Projects/setup-agent

# See what's missing (changes nothing)
bash skills/terminal-setup/scripts/verify-or-install.sh --check
bash skills/vscode-setup/scripts/verify-or-install.sh --check

# Preview what would be installed
bash skills/terminal-setup/scripts/verify-or-install.sh --apply --dry-run

# Install (asks for confirmation first)
bash skills/terminal-setup/scripts/verify-or-install.sh --apply
bash skills/vscode-setup/scripts/verify-or-install.sh --apply
```

A check looks like this:

```text
--> Shells & CLI tools
[+] zsh: /bin/zsh
[+] starship: /opt/homebrew/bin/starship
[-] fastfetch: missing

--> Config files
[+] current:  ~/.config/starship.toml
[~] differs:  ~/.zshrc (kept; --diff to view, --update-configs to replace)
```

`[+]` means OK, `[-]` means missing, and `[~]` means you have your own version of that file (it is left alone).

---

## Your files are safe

- **Existing dotfiles are never overwritten.** Missing ones are created; files you already have are only reported as `[~] differs`.
  - To see the difference: `--check --diff`
  - To replace them with the templates: `--apply --update-configs` (the old file is kept as `<file>.bak-<timestamp>`)
- **VS Code settings are merged, not replaced.** Only the settings this project needs are changed; the rest of your `settings.json` stays. A backup is made before every change, and a file that can't be read is never touched.
- **Nothing is installed without asking.** The agent asks first, and the script asks too (unless you pass `-y`).

## Keeping up to date

```bash
cd ~/Projects/setup-agent && git pull
```

The skills are linked, not copied, so every agent sees the update immediately.

## Customising

The config templates live in `skills/terminal-setup/assets/` (shell, Ghostty, Starship, Fastfetch) and `skills/vscode-setup/assets/` (VS Code settings). Edit them, then apply them to your machine:

```bash
bash skills/terminal-setup/scripts/verify-or-install.sh --apply --update-configs
bash skills/vscode-setup/scripts/verify-or-install.sh --apply
```

## Removing

```bash
~/Projects/setup-agent/install.sh --uninstall
```

This removes the skills from your agents. The tools and configs that were installed stay, and you can remove them with your package manager. Skill folders you had before installing are kept in `~/.local/share/setup-agent/backups/`.

## Installer options

| Command | What it does |
| :-- | :-- |
| `install.sh` | Link the skills into all agents |
| `install.sh --check` | Show where the skills are installed |
| `install.sh --agents claude,codex` | Only these agents (`claude`, `codex`, `antigravity`) |
| `install.sh --uninstall` | Remove the links |

Skills are linked into these folders:

| Agent | Folder |
| :-- | :-- |
| OpenAI Codex, Gemini CLI | `~/.agents/skills/` |
| Claude Code | `~/.claude/skills/` |
| Google Antigravity | `~/.gemini/config/skills/` |

**Claude Code only:** you can also install this repo as a plugin instead of running `install.sh`:

```
/plugin marketplace add Hazurka/setup-agent
/plugin install setup-agent@setup-agent
```

---

## Supported systems

| System | Status |
| :-- | :-- |
| macOS (with Homebrew) | ✅ Fully automatic |
| Fedora | ✅ Fully automatic |
| Arch Linux and derivatives | ✅ Fully automatic |
| openSUSE Tumbleweed (x86_64) | ✅ Fully automatic |
| openSUSE on ARM | Automatic except the Zsh plugins, which the agent installs with you |
| Debian 13, Ubuntu 25.04+ | Automatic except Ghostty, which the agent installs with you |
| Debian 12, Ubuntu 24.04 | Automatic except Ghostty, Starship and Fastfetch, which the agent installs with you |
| Rocky, Alma, RHEL, CentOS | Not supported by the scripts; the agent can still help tool by tool |

## Troubleshooting

**The agent doesn't seem to know the skill.**
Run `~/Projects/setup-agent/install.sh --check`, then restart the agent.

**"No TTY to confirm on"**
The script won't ask questions when it can't show a prompt. Agents pass `-y` after you've approved. When you run it yourself, run it in a normal terminal.

**Linux: it stops at `sudo`**
Run `sudo -v` first so sudo doesn't need to ask for your password mid-install. In Claude Code you can type `! sudo -v`.

**Icons show up as squares**
Your terminal or editor isn't using a Nerd Font. Run the terminal setup (it installs JetBrains Mono) and pick *JetBrainsMono Nerd Font* in your terminal's settings. Ghostty works out of the box.

**`settings.json could not be parsed`**
Your VS Code settings file has a syntax error. The script doesn't touch it; fix the line it points to (or ask your agent to) and run it again.

---

## Development

```bash
tests/run.sh                    # quick: lint, skill format, unit tests, simulated distros
tests/containers/run.sh         # slow: real installs in Linux containers (needs podman or docker)
tests/containers/run.sh fedora  # one distro
```

See [AGENTS.md](AGENTS.md) for the rules the scripts follow. Each skill's `references/install-sources.md` lists the official fallbacks the agent uses when a script can't finish.

## License

[MIT](LICENSE) © 2026 Hazurka
