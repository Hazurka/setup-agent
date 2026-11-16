# AGENTS.md

Guidance for AI agents working on this repository.

## Layout

- `skills/<name>/SKILL.md`: one skill per folder, in the [Agent Skills](https://agentskills.io/specification) format. The frontmatter `name` must equal the folder name.
- `skills/<name>/scripts/`: executable helpers. `skills/<name>/assets/`: templates the scripts deploy. `skills/<name>/references/`: guidance the agent reads when a script can't finish (official sources, fallbacks).
- `install.sh`: symlinks skills into `~/.agents/skills`, `~/.claude/skills` and `~/.gemini/config/skills`.
- `.claude-plugin/`: Claude Code plugin and marketplace manifests.
- `tests/`: `tests/run.sh` runs everything. It needs `shellcheck` and `python3`.

## Rules

- Keep scripts compatible with macOS `/bin/bash` 3.2: no associative arrays, no `${var,,}`, and guard empty arrays with `${arr[@]+"${arr[@]}"}`.
- Scripts use `set -o pipefail`: never pipe into `grep -q` (an early exit makes the writer fail with SIGPIPE); capture output first and use `grep -q ... <<< "$out"`.
- Don't depend on diffutils (`cmp`, `diff`); minimal openSUSE/Fedora installs lack it.
- Install software only through native package managers and vendor-official repositories. If no such source exists, print a manual step; never `curl | sh`.
- Scripts own the tested, repeatable path and the definition of done (`--check`). Anything they can't do reliably becomes a `manual` step that the agent resolves with the user's approval using `references/`. Don't add untested branches to the scripts for rare cases.
- Every script must support `--check` (read-only, default), `--apply`, `-y` and `--dry-run`, and must re-audit after applying.
- Never overwrite user files without a timestamped backup.
- In `SKILL.md`, refer to files relative to the skill folder, never with absolute or `~/.agents/...` paths.
- Keep each `SKILL.md` body under 500 lines; move long reference material into `references/`.
- Run `tests/run.sh` before committing; after changing install logic also run `tests/containers/run.sh` for the affected distros. When you change a platform branch, add or update its simulation in `tests/test_terminal_dry_run.sh`.
