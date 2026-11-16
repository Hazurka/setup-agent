# AGENTS.md

Guidance for AI agents working on this repository.

## Layout

- `skills/<name>/SKILL.md`: one skill per folder, in the [Agent Skills](https://agentskills.io/specification) format. The frontmatter `name` must equal the folder name.
- `skills/<name>/scripts/`: executable helpers. `skills/<name>/assets/`: templates the scripts deploy.
- `install.sh`: symlinks skills into `~/.agents/skills`, `~/.claude/skills` and `~/.gemini/config/skills`.
- `.claude-plugin/`: Claude Code plugin and marketplace manifests.
- `tests/`: `tests/run.sh` runs everything. It needs `shellcheck` and `python3`.

## Rules

- Keep scripts compatible with macOS `/bin/bash` 3.2: no associative arrays, no `${var,,}`, and guard empty arrays with `${arr[@]+"${arr[@]}"}`.
- Install software only through native package managers and vendor-official repositories. If no such source exists, print a manual step; never `curl | sh`.
- Every script must support `--check` (read-only, default), `--apply`, `-y` and `--dry-run`, and must re-audit after applying.
- Never overwrite user files without a timestamped backup.
- In `SKILL.md`, refer to files relative to the skill folder, never with absolute or `~/.agents/...` paths.
- Keep each `SKILL.md` body under 500 lines; move long reference material into `references/`.
- Run `tests/run.sh` before committing. When you change a platform branch, add or update its simulation in `tests/test_terminal_dry_run.sh`.
