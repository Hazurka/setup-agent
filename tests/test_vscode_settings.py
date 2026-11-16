#!/usr/bin/env python3
"""Unit tests for skills/vscode-setup/scripts/vscode_settings.py."""

import glob
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.join(HERE, "..", "skills", "vscode-setup")
sys.path.insert(0, os.path.join(SKILL, "scripts"))

import vscode_settings as vs  # noqa: E402

TEMPLATE = os.path.join(SKILL, "assets", "settings.json.template")

JSONC = """{
    // user comment with "quotes"
    "editor.fontSize": 16, /* block
       comment */
    "http.proxy": "http://example.com//not-a-comment",
    "files.associations": {
        "*.mdx": "markdown",
    },
    "[go]": { "editor.tabSize": 8, },
}
"""


def run(*args):
    buf = io.StringIO()
    with redirect_stdout(buf):
        rc = vs.main(["vscode_settings.py", *args])
    return rc, buf.getvalue()


class StripJsonc(unittest.TestCase):
    def test_comments_and_trailing_commas(self):
        cleaned, had = vs.strip_jsonc(JSONC)
        data = json.loads(cleaned)
        self.assertTrue(had)
        self.assertEqual(data["http.proxy"], "http://example.com//not-a-comment")
        self.assertEqual(data["files.associations"], {"*.mdx": "markdown"})

    def test_escaped_quote_in_string(self):
        cleaned, _ = vs.strip_jsonc('{"a": "x\\"//y", }')
        self.assertEqual(json.loads(cleaned), {"a": 'x"//y'})


class Merge(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = os.path.join(self.tmp.name, "User", "settings.json")
        with open(TEMPLATE) as f:
            self.template = json.load(f)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, text):
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        with open(self.path, "w") as f:
            f.write(text)

    def read(self):
        with open(self.path) as f:
            return json.load(f)

    def test_missing_file_is_created(self):
        self.assertEqual(run("check", self.path, TEMPLATE)[0], 1)
        self.assertEqual(run("merge", self.path, TEMPLATE)[0], 0)
        self.assertEqual(self.read(), self.template)
        self.assertEqual(run("check", self.path, TEMPLATE)[0], 0)

    def test_deep_merge_keeps_user_settings_and_backs_up(self):
        self.write(JSONC)
        rc, out = run("merge", self.path, TEMPLATE)
        self.assertEqual(rc, 0)
        data = self.read()
        self.assertEqual(data["http.proxy"], "http://example.com//not-a-comment")
        self.assertEqual(data["files.associations"]["*.mdx"], "markdown")
        self.assertEqual(data["files.associations"][".env*"], "properties")
        self.assertEqual(data["[go]"]["editor.tabSize"], 8)
        self.assertTrue(data["[go]"]["editor.formatOnSave"])
        self.assertEqual(data["editor.fontSize"], self.template["editor.fontSize"])
        backups = glob.glob(self.path + ".bak-*")
        self.assertEqual(len(backups), 1)
        with open(backups[0]) as f:
            self.assertEqual(f.read(), JSONC)
        self.assertIn("Comments", out)
        self.assertEqual(run("check", self.path, TEMPLATE)[0], 0)

    def test_up_to_date_file_is_not_rewritten(self):
        self.write(json.dumps(self.template))
        rc, out = run("merge", self.path, TEMPLATE)
        self.assertEqual(rc, 0)
        self.assertIn("already up to date", out)
        self.assertEqual(glob.glob(self.path + ".bak-*"), [])

    def test_unparseable_file_is_left_alone(self):
        broken = '{ "editor.fontSize": 14 "oops" }'
        self.write(broken)
        self.assertEqual(run("check", self.path, TEMPLATE)[0], 2)
        self.assertEqual(run("merge", self.path, TEMPLATE)[0], 2)
        with open(self.path) as f:
            self.assertEqual(f.read(), broken)
        self.assertEqual(glob.glob(self.path + ".bak-*"), [])

    def test_dry_run_changes_nothing(self):
        self.write(JSONC)
        rc, out = run("merge", self.path, TEMPLATE, "--dry-run")
        self.assertEqual(rc, 0)
        self.assertIn("[dry-run]", out)
        with open(self.path) as f:
            self.assertEqual(f.read(), JSONC)

    def test_empty_file(self):
        self.write("")
        self.assertEqual(run("merge", self.path, TEMPLATE)[0], 0)
        self.assertEqual(self.read(), self.template)


if __name__ == "__main__":
    unittest.main(verbosity=1)
