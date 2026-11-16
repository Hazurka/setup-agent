---
name: terminal-setup
description: >-
  Audits, installs, or repairs a modern terminal environment on macOS and Linux
  (Fedora, openSUSE, Debian/Ubuntu, Arch): Ghostty, Bash and Zsh with feature
  parity, Starship prompt, eza, Fastfetch, zsh-autosuggestions,
  zsh-syntax-highlighting, and the JetBrains Mono Nerd Font, using only
  vendor-official package repositories. Use when the user wants to set up a new
  machine, bootstrap or check their dotfiles, fix their shell prompt or
  terminal, or sync terminal configs to the canonical templates.
license: MIT
compatibility: macOS (Homebrew) or Linux with dnf, zypper, apt or pacman; bash 3.2+; sudo on Linux for installs.
metadata:
  repository: https://github.com/Hazurka/setup-agent
---

# Terminal Setup

Sets up Ghostty, Bash/Zsh, Starship, eza, Fastfetch, the Zsh plugins and the JetBrains Mono font. Everything is done by one script; all paths below are relative to this skill's directory.

## Workflow

1. **Audit first** (read-only, always safe):
   ```bash
   bash scripts/verify-or-install.sh --check
   ```
   Exit code 0 means complete; 1 means something is missing. Lines start with `[+]` ok, `[-]` missing, `[~]` config exists but differs from the template.

2. **Show the user what is missing and get approval** before changing anything. To show exactly what would run:
   ```bash
   bash scripts/verify-or-install.sh --apply --dry-run
   ```

3. **Apply** after approval. Agents have no TTY, so pass `-y`:
   ```bash
   bash scripts/verify-or-install.sh --apply -y
   ```
   The script re-audits at the end and exits non-zero if anything is still missing, listing failed and manual steps.

4. **Finish the rest yourself, with approval.** For each `Manual step:` or `Failed step:` line, read [references/install-sources.md](references/install-sources.md). Propose a concrete fix to the user (command plus source), apply it once approved, and repeat `--check` until it exits 0. If the user declines a fix, leave that item and say so in your summary.

## Rules

- **Existing configs are never overwritten by default.** Missing ones are deployed from `assets/`. Use `--check --diff` to show differences. Only pass `--update-configs` when the user explicitly asks to replace their configs; each replaced file is backed up as `<file>.bak-<timestamp>`.
- **Linux installs need sudo.** If `sudo` would prompt for a password, ask the user to run `sudo -v` in their terminal first (in Claude Code: `! sudo -v`), or have them run the apply command themselves.
- **macOS needs Homebrew.** If it is missing the script stops and points to https://brew.sh; do not install Homebrew without the user's approval.
- The script never runs `curl | sh`. Where no package exists (e.g. Starship on Debian 12) it prints a manual step for you to resolve in step 4. A vendor install script is the last option there, and only with the user's explicit agreement.
- Changing the login shell (`chsh`) needs the user's password; tell the user the command, don't run it.

## Package sources

Tool | macOS | Fedora | openSUSE | Debian / Ubuntu | Arch
:-- | :-- | :-- | :-- | :-- | :--
Ghostty | cask `ghostty` | COPR `scottames/ghostty` | OSS | apt (if packaged), else Flathub, else manual | extra
Starship | `starship` | COPR `atim/starship` | OSS | apt (Debian 13+ / Ubuntu 25.04+), else manual | extra
eza | `eza` | Fedora | OSS | apt, else vendor repo `deb.gierens.de` | extra
Fastfetch | `fastfetch` | Fedora | OSS | apt, else PPA `zhangsongcui3371/fastfetch` (Ubuntu only) | extra
Zsh + plugins | brew | Fedora | zsh: OSS; plugins: zsh-users OBS repos (x86_64 only, else manual) | apt | extra
Font | cask `font-jetbrains-mono-nerd-font` | `jetbrains-mono-fonts-all` | `jetbrains-mono-fonts` + `nerdfonts-symbolsonly-fonts` | `fonts-jetbrains-mono` | `ttf-jetbrains-mono-nerd`

On Fedora and Debian/Ubuntu the distro font is plain JetBrains Mono (openSUSE adds the Nerd symbols package). Ghostty bundles Nerd Font symbols, so the terminal is fine. VS Code's integrated terminal will lack prompt icons unless the user installs the Nerd Font from https://github.com/ryanoasis/nerd-fonts/releases.

RHEL-family systems (Rocky, Alma, CentOS) are reported as unsupported because the COPRs above are Fedora-only.

## Files deployed

Template (`assets/`) | Target
:-- | :--
`bash_profile.template`, `bashrc.template` | `~/.bash_profile`, `~/.bashrc`
`zprofile.template`, `zshrc.template` | `~/.zprofile`, `~/.zshrc`
`ghostty.config.template` | `~/.config/ghostty/config`
`starship.toml.template` | `~/.config/starship.toml`
`fastfetch.jsonc.template` | `~/.config/fastfetch/config.jsonc`

The audit also loads the Ghostty and fastfetch configs to confirm they parse.

The fastfetch config runs on every login shell (from `~/.bash_profile` / `~/.zprofile`). It shows OS, host, uptime, packages, shell, terminal, terminal font, CPU, memory and battery with Nerd Font icons, followed by the colour palette. To change what it shows, edit `assets/fastfetch.jsonc.template` (module list: `fastfetch --list-modules`) and redeploy with `--apply --update-configs`.

The Starship config uses Catppuccin Mocha colours and shows package version, Node/Bun/Deno, React/Angular/Vue, Go and Terraform modules when the current directory is such a project.
