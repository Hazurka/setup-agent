# Finishing what the script could not

Read this when `scripts/verify-or-install.sh --apply` ends with `Manual step:` or `Failed step:` lines, or when `--check` still reports something missing.

## Ground rules

1. **Propose, then act.** Tell the user what you will run and where it comes from, and wait for approval. Adding a package repository needs its own approval.
2. **Use official sources:** Microsoft's packages for VS Code, and the Visual Studio Marketplace for extensions.
3. **Never replace `settings.json` wholesale.** Only edit it through the script, or by changing the specific keys the user agreed to.
4. **Finish with the script.** Run `bash scripts/verify-or-install.sh --check`. The job is done only when it exits 0.

## VS Code is not installed (Linux)

Source: https://code.visualstudio.com/docs/setup/linux

- Debian/Ubuntu: add Microsoft's apt repository (`packages.microsoft.com`) as that page describes, then `sudo apt-get install code`.
- Fedora/RHEL and openSUSE: add Microsoft's yum/zypper repository from the same page, then install `code`.
- Arch: the `code` package in `extra` is the open-source build. Microsoft's Marketplace and some extensions are not available in it. Explain the difference and let the user choose; Microsoft's own build is only available from the AUR (`visual-studio-code-bin`), which is community-maintained.
- Snap: `sudo snap install code --classic` (published by Microsoft) is an alternative where snapd is available.

After installing, re-run the script so it finds the `code` CLI.

## `code` CLI not found but VS Code is installed

- macOS: the script already looks inside `/Applications/Visual Studio Code.app`. If VS Code is installed elsewhere, the user can run *Shell Command: Install 'code' command in PATH* from the Command Palette.
- Flatpak: the script uses `flatpak run com.visualstudio.code`. If that fails, check `flatpak list`.

## An extension fails to install

- Retry once; Marketplace errors are often temporary.
- Check that the ID still exists: https://marketplace.visualstudio.com/items?itemName=<id>.
- Behind a proxy, VS Code honours `http.proxy` in `settings.json`. Ask the user for the value rather than guessing.

## settings.json cannot be parsed

The script refuses to touch it and prints the parser error with its position.

1. Show the user the lines around that position.
2. Propose the smallest fix (usually a missing comma or quote).
3. After the user approves, apply it and re-run `--apply`.

## python3 missing

The settings merge needs python3. Install it with the system package manager (`python3` on every supported distro). On macOS, run `xcode-select --install` or `brew install python`.

## Font missing

The font is installed by the `terminal-setup` skill. Run that skill (or its font step) rather than installing the font from here.
