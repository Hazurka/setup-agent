# Finishing what the script could not

Read this when `scripts/verify-or-install.sh --apply` ends with `Manual step:` or `Failed step:` lines, or when `--check` still reports something missing. The script covers the tested paths. This file gives you the official sources for everything else, so you can propose a fix to the user.

## Ground rules

1. **Propose, then act.** Tell the user what you intend to run and where it comes from, and wait for approval. One approval covers one change; adding a repository needs its own approval.
2. **Prefer, in this order:** the distro's own package manager, then a repository or package published by the tool's vendor, then a user-local install under `~/.local` or `~/.zsh` that needs no root. Only use a vendor install script (`curl … | sh`) when the user explicitly agrees after you've offered the alternatives.
3. **Check before you trust this file.** Package names and repositories change. Confirm with the package manager's search (`apt-cache policy`, `dnf info`, `zypper se`, `pacman -Ss`, `brew info`) or the vendor page linked below.
4. **Finish with the script.** After your changes, run `bash scripts/verify-or-install.sh --check`. The job is done only when it exits 0. Summarise for the user what you installed outside the script, and how to update or remove it.

## Ghostty (Debian, Ubuntu)

Source: https://ghostty.org/docs/install/binary lists the packages that exist for each distro.

- If `apt-cache policy ghostty` shows a candidate, the script would already have used it. Re-run `apt-get update` and try again.
- Otherwise read the page above and offer the user the options it lists for their release (e.g. a `.deb` package, Snap, Flatpak). Say who maintains each option.
- Ghostty is a GUI app. In a headless or container environment, tell the user it was skipped rather than installing it.

## Starship (Debian 12, Ubuntu 24.04 and older)

Source: https://starship.rs/guide/#step-1-install-starship

Options in order of preference:
1. `snap install starship` if `snapd` is present (common on Ubuntu).
2. `brew install starship` if Homebrew on Linux is already installed.
3. `cargo install starship --locked` if a Rust toolchain is already installed. The binary goes to `~/.cargo/bin`, which must be on `PATH`.
4. The official install script, with the user's explicit agreement:
   `curl -sS https://starship.rs/install.sh | sh -s -- -b ~/.local/bin`
   (installs into `~/.local/bin`, which the templates already put on `PATH`).

## Fastfetch (Debian 12, Ubuntu without the PPA)

Source: https://github.com/fastfetch-cli/fastfetch#installation

- Debian 12: check whether `bookworm-backports` is enabled and offers it (`apt-cache policy fastfetch`).
- Otherwise use the vendor's `.deb` from https://github.com/fastfetch-cli/fastfetch/releases. Pick the asset matching `dpkg --print-architecture`, download it to a temporary directory, then run `sudo apt-get install ./<file>.deb` so apt tracks it.

## Zsh plugins (openSUSE on non-x86_64, or any distro without packages)

Source: the upstream repositories' INSTALL.md (manual installation).

```bash
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting
```

`~/.zshrc` from this skill already looks in `~/.zsh/<plugin>/`. Updates are `git -C ~/.zsh/<plugin> pull`.

## Nerd Font glyphs on Linux

Fedora and Debian/Ubuntu ship plain JetBrains Mono. Ghostty bundles Nerd symbols itself, so only VS Code's terminal needs this. If the user wants the icons there:

- Download `JetBrainsMono.tar.xz` from https://github.com/ryanoasis/nerd-fonts/releases/latest.
- Extract it into `~/.local/share/fonts/JetBrainsMonoNerd/`, then run `fc-cache -f`.

## Homebrew missing (macOS)

Source: https://brew.sh. The installer asks for the user's password and confirmation, so the user should run it themselves. In Claude Code, suggest they type:

```
! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then re-run the skill's apply step.

## Unsupported distributions (RHEL family, NixOS, others)

The script stops without changing anything. Work tool by tool instead:

- Check the distro's own repositories first. On RHEL-family systems, EPEL often has zsh plugins, fastfetch and fonts.
- Then check each tool's vendor install page (linked above, plus https://eza.rocks and https://github.com/eza-community/eza/blob/main/INSTALL.md).
- Don't enable repositories built for another distro (e.g. Fedora COPRs on RHEL).
- Deploy the configs by copying the files from `assets/` to the targets listed in `SKILL.md`. Back up any existing file first.

## A step failed

Read the error the script printed, then:

- **Package not found:** search for a renamed package with the package manager's search.
- **Network or mirror error:** retry once, then report it to the user.
- **Permission error:** Linux installs need sudo. Ask the user to run `sudo -v` (in Claude Code: `! sudo -v`) and retry.
- **Conflicts with a package installed some other way:** show the conflict to the user and let them decide.
