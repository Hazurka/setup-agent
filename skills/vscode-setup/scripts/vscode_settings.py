#!/usr/bin/env python3
"""Audit or merge the vscode-setup template into a VS Code settings.json.

VS Code stores settings as JSONC (comments and trailing commas allowed), so
the file is parsed with a small JSONC reader. Merging is deep: nested objects
such as "files.associations" or "[go]" keep the user's other keys. A file that
cannot be parsed is never rewritten.

Usage:
  vscode_settings.py check <settings.json> <template.json>
  vscode_settings.py merge <settings.json> <template.json> [--dry-run]

Exit codes: 0 = matches / merged, 1 = differs or file missing, 2 = parse error.
"""

import json
import os
import shutil
import sys
import time


def strip_jsonc(text):
    """Remove // and /* */ comments and trailing commas outside of strings."""
    out = []
    i, n = 0, len(text)
    in_string = False
    had_comments = False
    while i < n:
        c = text[i]
        if in_string:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_string = False
            i += 1
        elif c == '"':
            in_string = True
            out.append(c)
            i += 1
        elif text.startswith("//", i):
            had_comments = True
            while i < n and text[i] != "\n":
                i += 1
        elif text.startswith("/*", i):
            had_comments = True
            end = text.find("*/", i + 2)
            i = n if end == -1 else end + 2
        elif c == ",":
            j = i + 1
            while j < n and text[j] in " \t\r\n":
                j += 1
            if j < n and text[j] in "}]":
                i += 1  # trailing comma
            else:
                out.append(c)
                i += 1
        else:
            out.append(c)
            i += 1
    return "".join(out), had_comments


def load_jsonc(path):
    with open(path, encoding="utf-8") as f:
        raw = f.read()
    cleaned, had_comments = strip_jsonc(raw)
    if not cleaned.strip():
        return {}, had_comments
    data = json.loads(cleaned)
    if not isinstance(data, dict):
        raise ValueError("top-level value is not an object")
    return data, had_comments


def diff_keys(current, template, prefix=""):
    """Return template key paths whose values are absent or different."""
    changed = []
    for key, want in template.items():
        path = f"{prefix}{key}"
        have = current.get(key) if isinstance(current, dict) else None
        if isinstance(want, dict) and isinstance(have, dict):
            changed += diff_keys(have, want, path + " > ")
        elif have != want:
            changed.append(path)
    return changed


def deep_merge(current, template):
    merged = dict(current)
    for key, want in template.items():
        have = merged.get(key)
        if isinstance(want, dict) and isinstance(have, dict):
            merged[key] = deep_merge(have, want)
        else:
            merged[key] = want
    return merged


def main(argv):
    if len(argv) < 4 or argv[1] not in ("check", "merge"):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    action, settings_path, template_path = argv[1], argv[2], argv[3]
    dry_run = "--dry-run" in argv[4:]

    with open(template_path, encoding="utf-8") as f:
        template = json.load(f)

    exists = os.path.isfile(settings_path)
    try:
        current, had_comments = load_jsonc(settings_path) if exists else ({}, False)
    except (ValueError, json.JSONDecodeError) as exc:
        print(f"[-] Cannot parse {settings_path}: {exc}")
        print("    Fix the file by hand; it was not modified.")
        return 2

    changed = diff_keys(current, template)

    if action == "check":
        if not exists:
            print(f"[-] settings.json missing: {settings_path}")
            return 1
        if not changed:
            print("[+] settings.json contains every template setting")
            return 0
        print(f"[-] settings.json differs from template in {len(changed)} setting(s):")
        for path in changed:
            print(f"      {path}")
        return 1

    if exists and not changed:
        print("[+] settings.json already up to date")
        return 0
    if dry_run:
        print(f"  [dry-run] would update {len(changed)} setting(s) in {settings_path}")
        for path in changed:
            print(f"      {path}")
        return 0

    os.makedirs(os.path.dirname(settings_path) or ".", exist_ok=True)
    if exists:
        backup = f"{settings_path}.bak-{time.strftime('%Y%m%d%H%M%S')}"
        shutil.copy2(settings_path, backup)
        print(f"[+] Backup: {backup}")
        if had_comments:
            print("[*] Comments in settings.json are not preserved; they remain in the backup.")
    merged = deep_merge(current, template)
    tmp = settings_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(merged, f, indent=4, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, settings_path)
    print(f"[+] Updated {len(changed)} setting(s) in {settings_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
