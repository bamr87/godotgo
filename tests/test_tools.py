#!/usr/bin/env python3
"""Tests for the workspace's Godot-free tooling, using only the standard library.

`tools/verify.sh` is the gate for the framework and the games, and it needs
Godot. The Python generators beside it need nothing but `python3`, so they are
tested here, and the `standard` job in `.github/workflows/ci.yml` (the hub's
shared gate, bamr87/bamr87 `standard-ci.yml`) runs this suite on every push
and pull request:

- `tools/gen_assets.py`, run into an empty scratch root, writes exactly the
  bytes that are committed, and a second run writes the same bytes again;
- `tools/docs_index.py --check` passes on the checkout, so the index in
  `docs/README.md` is current, and it fails once a document is added without
  regenerating the index;
- `tools/gen_framework_api.py --check` fails once a framework doc comment
  changes without regenerating the reference. Whether the committed reference
  is current is deliberately not asserted here: `tools/verify.sh` keeps that an
  advisory warning while the Claude workflows cannot run the generator.

Every generator runs from a scratch copy or with a scratch root; the checkout
is only read.

Usage:
    python3 -m unittest discover -s tests -v
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
# The addon tools/gen_framework_api.py documents (its ADDON constant).
ADDON = "framework/addons/godotgo"
# Every tool here finishes in well under a second; this only stops a hang.
TIMEOUT = 120


def run(script: Path, *args: object, cwd: Path = ROOT) -> subprocess.CompletedProcess:
    """Runs a Python tool with this interpreter and captures its output."""
    return subprocess.run(
        [sys.executable, str(script), *(str(a) for a in args)],
        cwd=str(cwd),
        capture_output=True,
        text=True,
        timeout=TIMEOUT,
        check=False,
    )


def output(result: subprocess.CompletedProcess) -> str:
    return (result.stdout + result.stderr).strip()


def files_under(root: Path, skip: str) -> dict[str, bytes]:
    """Every file below `root` except those under `skip`, by POSIX relative path."""
    found = {}
    for path in sorted(root.rglob("*")):
        rel = path.relative_to(root).as_posix()
        if path.is_file() and not rel.startswith(skip + "/"):
            found[rel] = path.read_bytes()
    return found


def copy_into(scratch: Path, paths: list[Path]) -> None:
    """Copies checkout files into `scratch`, keeping their relative paths."""
    for path in paths:
        target = scratch / path.relative_to(ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)


def asset_projects() -> list[str]:
    """The projects tools/gen_assets.py writes into, as its --list names them."""
    listed = run(TOOLS / "gen_assets.py", "--list")
    if listed.returncode != 0:
        raise AssertionError("tools/gen_assets.py --list failed:\n" + output(listed))
    return [line for line in listed.stdout.splitlines() if line and not line.startswith("skip ")]


def generate_assets(scratch: Path, projects: list[str]) -> dict[str, bytes]:
    """Runs a copy of tools/gen_assets.py whose root is `scratch`; returns what it wrote."""
    copy_into(scratch, [TOOLS / "gen_assets.py"])
    for project in projects:
        (scratch / project).mkdir(parents=True, exist_ok=True)
    result = run(scratch / "tools" / "gen_assets.py", cwd=scratch)
    if result.returncode != 0:
        raise AssertionError("tools/gen_assets.py failed:\n" + output(result))
    return files_under(scratch, skip="tools")


class GenAssetsTest(unittest.TestCase):
    """tools/gen_assets.py writes every placeholder asset, byte-identically everywhere."""

    projects: list[str]
    written: dict[str, bytes]

    @classmethod
    def setUpClass(cls) -> None:
        scratch = tempfile.TemporaryDirectory(prefix="godotgo-assets-")
        cls.addClassCleanup(scratch.cleanup)
        cls.projects = asset_projects()
        cls.written = generate_assets(Path(scratch.name), cls.projects)

    def test_reproduces_the_committed_assets(self) -> None:
        """A run into an empty root writes exactly the committed bytes."""
        self.assertTrue(self.projects, "tools/gen_assets.py --list named no project")
        self.assertTrue(self.written, "tools/gen_assets.py wrote nothing")
        stale = []
        for rel, data in sorted(self.written.items()):
            committed = ROOT / rel
            if not committed.is_file():
                stale.append(rel + " (not in the checkout)")
            elif committed.read_bytes() != data:
                stale.append(rel)
        self.assertEqual(
            stale,
            [],
            "tools/gen_assets.py writes different bytes than are committed: "
            "run `python3 tools/gen_assets.py` and commit the result",
        )

    def test_a_second_run_writes_the_same_bytes(self) -> None:
        """Two runs into separate roots agree file for file and byte for byte."""
        with tempfile.TemporaryDirectory(prefix="godotgo-assets-") as again:
            second = generate_assets(Path(again), self.projects)
        self.assertEqual(sorted(second), sorted(self.written), "the two runs wrote different files")
        differing = [rel for rel in sorted(self.written) if second[rel] != self.written[rel]]
        self.assertEqual(differing, [], "the two runs wrote different bytes")


class DocsIndexTest(unittest.TestCase):
    """tools/docs_index.py derives the index in docs/README.md from each document."""

    def test_index_is_current(self) -> None:
        """docs/README.md lists every document with its current summary line."""
        result = run(TOOLS / "docs_index.py", "--check", "--root", ROOT)
        self.assertEqual(result.returncode, 0, output(result))

    def test_check_fails_on_a_document_missing_from_the_index(self) -> None:
        """--check fails once a document is added without regenerating the index."""
        documents = sorted(ROOT.glob("*.md")) + sorted((ROOT / "docs").rglob("*.md"))
        with tempfile.TemporaryDirectory(prefix="godotgo-docs-") as name:
            scratch = Path(name)
            copy_into(scratch, documents)
            index = TOOLS / "docs_index.py"
            wrote = run(index, "--write", "--root", scratch, cwd=scratch)
            self.assertEqual(wrote.returncode, 0, output(wrote))
            current = run(index, "--check", "--root", scratch, cwd=scratch)
            self.assertEqual(current.returncode, 0, "a freshly written index fails --check: " + output(current))
            (scratch / "docs" / "unindexed.md").write_text(
                "# Unindexed\n\n> A document added without regenerating the index.\n", encoding="utf-8"
            )
            stale = run(index, "--check", "--root", scratch, cwd=scratch)
        self.assertEqual(stale.returncode, 1, output(stale))
        self.assertIn("is stale", stale.stderr)


class FrameworkApiTest(unittest.TestCase):
    """tools/gen_framework_api.py derives docs/reference/framework-api.md from doc comments."""

    def test_check_fails_when_a_doc_comment_changes(self) -> None:
        """--check fails once a documented member is added without regenerating."""
        scripts = sorted((ROOT / ADDON).rglob("*.gd"))
        self.assertTrue(scripts, "no GDScript found under " + ADDON)
        with tempfile.TemporaryDirectory(prefix="godotgo-api-") as name:
            scratch = Path(name)
            copy_into(scratch, [TOOLS / "gen_framework_api.py"] + scripts)
            generator = scratch / "tools" / "gen_framework_api.py"
            wrote = run(generator, cwd=scratch)
            self.assertEqual(wrote.returncode, 0, output(wrote))
            current = run(generator, "--check", cwd=scratch)
            self.assertEqual(current.returncode, 0, "a freshly written reference fails --check: " + output(current))
            with open(scratch / scripts[0].relative_to(ROOT), "a", encoding="utf-8") as script:
                script.write(
                    "\n\n## Added by tests/test_tools.py without regenerating the reference.\n"
                    "func added_by_the_test() -> void:\n\tpass\n"
                )
            stale = run(generator, "--check", cwd=scratch)
        self.assertEqual(stale.returncode, 1, output(stale))
        self.assertIn("is stale", stale.stderr)


if __name__ == "__main__":
    unittest.main()
