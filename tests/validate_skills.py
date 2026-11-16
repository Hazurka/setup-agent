#!/usr/bin/env python3
"""Validate every skills/*/SKILL.md against the Agent Skills specification.

https://agentskills.io/specification: required name + description; name is
1-64 chars of lowercase letters, digits and single hyphens, equal to the folder
name; description 1-1024 chars; compatibility <= 500 chars; metadata is a
string map; body should stay under 500 lines. Uses a small parser for the YAML
subset the frontmatter uses, so no PyYAML is needed.
"""

import os
import re
import sys

ALLOWED = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def parse_frontmatter(text):
    if not text.startswith("---\n"):
        raise ValueError("SKILL.md must start with '---' frontmatter")
    end = text.find("\n---\n", 4)
    if end == -1:
        raise ValueError("frontmatter is not closed with '---'")
    lines = text[4:end].split("\n")
    body = text[end + 5:]
    data, i = {}, 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        m = re.match(r"^([A-Za-z][\w-]*):\s*(.*)$", line)
        if not m:
            raise ValueError(f"cannot parse frontmatter line: {line!r}")
        key, value = m.group(1), m.group(2)
        i += 1
        if value in (">", ">-", "|", "|-"):
            block = []
            while i < len(lines) and (lines[i].startswith("  ") or not lines[i].strip()):
                block.append(lines[i].strip())
                i += 1
            sep = " " if value.startswith(">") else "\n"
            data[key] = sep.join(b for b in block if b).strip()
        elif value == "":
            nested = {}
            while i < len(lines) and lines[i].startswith("  "):
                nm = re.match(r"^\s+([\w.-]+):\s*(.*)$", lines[i])
                if not nm:
                    raise ValueError(f"cannot parse nested line: {lines[i]!r}")
                nested[nm.group(1)] = nm.group(2).strip().strip('"')
                i += 1
            data[key] = nested
        else:
            data[key] = value.strip().strip('"')
    return data, body


def validate(skill_dir):
    errors = []
    path = os.path.join(skill_dir, "SKILL.md")
    folder = os.path.basename(skill_dir.rstrip("/"))
    if not os.path.isfile(path):
        return [f"{folder}: SKILL.md missing"]
    with open(path, encoding="utf-8") as f:
        text = f.read()
    try:
        fm, body = parse_frontmatter(text)
    except ValueError as exc:
        return [f"{folder}: {exc}"]

    for key in fm:
        if key not in ALLOWED:
            errors.append(f"unknown frontmatter field '{key}'")
    name = fm.get("name", "")
    if not name:
        errors.append("name is required")
    elif len(name) > 64 or not NAME_RE.match(name):
        errors.append(f"invalid name '{name}'")
    elif name != folder:
        errors.append(f"name '{name}' does not match folder '{folder}'")
    desc = fm.get("description", "")
    if not desc:
        errors.append("description is required")
    elif len(desc) > 1024:
        errors.append(f"description is {len(desc)} chars (max 1024)")
    if len(fm.get("compatibility", "")) > 500:
        errors.append("compatibility exceeds 500 chars")
    if "metadata" in fm and not isinstance(fm["metadata"], dict):
        errors.append("metadata must be a map")
    body_lines = body.count("\n")
    if body_lines >= 500:
        errors.append(f"body is {body_lines} lines (keep under 500)")

    # Files referenced as scripts/... or assets/... must exist.
    for ref in sorted(set(re.findall(r"(?:\.\./[\w-]+/)?(?:scripts|assets)/[\w.-]+", body))):
        if not os.path.exists(os.path.normpath(os.path.join(skill_dir, ref))):
            errors.append(f"referenced file not found: {ref}")
    if "~/.agents" in body or "/Users/" in body:
        errors.append("body uses an absolute/home path; use paths relative to the skill folder")
    return [f"{folder}: {e}" for e in errors]


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "skills")
    skills = sorted(d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d)))
    all_errors = []
    for name in skills:
        errs = validate(os.path.join(root, name))
        print(f"  {'ok  ' if not errs else 'FAIL'} {name}")
        all_errors += errs
    for e in all_errors:
        print(f"       {e}")
    return 1 if all_errors or not skills else 0


if __name__ == "__main__":
    sys.exit(main())
