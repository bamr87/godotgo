#!/usr/bin/env python3
"""Generate the framework API reference from the addon's own doc comments.

docs/reference/framework-api.md lists every class, signal, enum, constant,
property and method of framework/addons/godotgo/, and it is derived rather than
written: each entry is a declaration copied from the script and the `##` doc
comment above it, so the reference can never drift from the code. Explanation
and design reasoning stay hand-written in docs/framework.md.

What is listed, per script: the `class_name` (or the file path when there is
none), what it extends, the class doc comment, and every top-level member
whose name does not start with an underscore. `_init` is listed as the
constructor; other underscore methods are engine callbacks or private.

Usage:
    python3 tools/gen_framework_api.py            # rewrite the reference
    python3 tools/gen_framework_api.py --check    # exit 1 when it is stale

Only the Python standard library is used. tools/verify.sh runs the check in
its `pins` stage, as a warning until the Claude workflows may run this script.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import textwrap

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = "framework/addons/godotgo"
OUTPUT = "docs/reference/framework-api.md"
COMMAND = "python3 tools/gen_framework_api.py"

MEMBER_RE = re.compile(
    r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?(signal|enum|const|var|func)\s+(\w+)"
)
GROUPS = [
    ("signal", "Signals"),
    ("enum", "Enums"),
    ("const", "Constants"),
    ("var", "Properties"),
    ("func", "Methods"),
]


# --------------------------------------------------------------------------- #
# parsing
# --------------------------------------------------------------------------- #


def doc_text(line: str) -> str:
    """The text of one `##` line, keeping indentation past the first space."""
    text = line.lstrip()[2:]
    return text[1:] if text.startswith(" ") else text


def bracket_depth(text: str) -> int:
    depth = 0
    for ch in text:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
    return depth


def declaration(lines: list[str], start: int) -> tuple[str, int]:
    """The member declaration beginning at lines[start], joined onto one line.

    Returns the declaration and the index of its last line. Multi-line
    function signatures are collapsed; a multi-line constant value is elided.
    """
    first = lines[start].rstrip()
    kind = MEMBER_RE.match(first).group(1)
    if kind == "func":
        parts, end = [first.strip()], start
        while bracket_depth(" ".join(parts)) > 0 and end + 1 < len(lines):
            end += 1
            parts.append(lines[end].strip())
        text = " ".join(parts)
        text = re.sub(r"\(\s+", "(", text)
        text = re.sub(r",?\s+\)", ")", text)
        text = re.sub(r"\s+", " ", text)
        return text.rstrip(":").rstrip(), end
    end = start
    depth = bracket_depth(first)
    while depth > 0 and end + 1 < len(lines):
        end += 1
        depth += bracket_depth(lines[end])
    if end > start:
        opener = first.rstrip()[-1]
        closer = {"{": "}", "[": "]", "(": ")"}.get(opener, "")
        return first.strip() + "…" + closer, end
    return first.strip(), end


def parse(path: str) -> dict:
    with open(os.path.join(ROOT, path), encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    script = {
        "path": os.path.relpath(path, ADDON).replace(os.sep, "/"),
        "class_name": "",
        "extends": "",
        "tool": False,
        "doc": [],
        "members": [],
    }
    pending: list[str] = []
    seen_member = False
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if line[:1] in (" ", "\t"):
            i += 1
            continue
        if stripped.startswith("##"):
            pending.append(doc_text(line))
        elif not stripped:
            if pending and not seen_member and not script["doc"]:
                script["doc"] = pending
            pending = []
        elif stripped == "@tool":
            script["tool"] = True
        elif stripped.startswith("class_name "):
            script["class_name"] = stripped.split()[1]
        elif stripped.startswith("extends "):
            script["extends"] = stripped.split()[1]
            if pending and not script["doc"]:
                script["doc"], pending = pending, []
        elif MEMBER_RE.match(stripped):
            kind, name = MEMBER_RE.match(stripped).groups()
            text, i = declaration(lines, i)
            seen_member = True
            public = not name.startswith("_") or name == "_init"
            if public:
                script["members"].append(
                    {"kind": kind, "name": name, "decl": text, "doc": pending}
                )
            pending = []
        else:
            pending = []
        i += 1
    if pending and not script["doc"] and not seen_member:
        script["doc"] = pending
    return script


def scripts() -> list[dict]:
    found = []
    for base, dirs, names in os.walk(os.path.join(ROOT, ADDON)):
        dirs.sort()
        for name in sorted(names):
            if name.endswith(".gd"):
                full = os.path.join(base, name)
                found.append(os.path.relpath(full, ROOT).replace(os.sep, "/"))
    return [parse(p) for p in sorted(found)]


# --------------------------------------------------------------------------- #
# rendering
# --------------------------------------------------------------------------- #


def slug(heading: str) -> str:
    """GitHub's anchor for a heading."""
    text = heading.strip().lower()
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")


def inline(text: str, classes: set[str]) -> str:
    """Godot doc-comment BBCode to Markdown, for one paragraph."""
    spans: list[str] = []

    def keep(code: str) -> str:
        spans.append("`" + code + "`")
        return "\0%d\0" % (len(spans) - 1)

    text = re.sub(r"\[code\](.*?)\[/code\]", lambda m: keep(m.group(1)), text)
    text = re.sub(r"\[method ([\w.]+)\]", lambda m: keep(m.group(1) + "()"), text)
    text = re.sub(
        r"\[(?:member|signal|constant|param|enum) ([\w.]+)\]",
        lambda m: keep(m.group(1)),
        text,
    )
    text = text.replace("*", "\\*")
    text = re.sub(r"\[b\](.*?)\[/b\]", r"**\1**", text)
    text = re.sub(r"\[i\](.*?)\[/i\]", r"*\1*", text)

    def ref(m: re.Match) -> str:
        name = m.group(1)
        code = keep(name)
        return "[%s](#%s)" % (code, slug(name)) if name in classes else code

    text = re.sub(r"\[([A-Z]\w*)\]", ref, text)
    for n, code in enumerate(spans):
        text = text.replace("\0%d\0" % n, code)
    return text


def blocks(doc: list[str], classes: set[str]) -> list[tuple[str, str]]:
    """A doc comment as ("para", text), ("code", gdscript) and ("text", preformatted) blocks."""
    out: list[tuple[str, str]] = []
    para: list[str] = []
    code: list[str] | None = None
    pre: list[str] = []

    def flush_para() -> None:
        if para:
            out.append(("para", inline(" ".join(para), classes)))
            para.clear()

    def flush_pre() -> None:
        if pre:
            out.append(("text", textwrap.dedent("\n".join(pre))))
            pre.clear()

    for line in doc:
        if code is not None:
            if line.strip() == "[/codeblock]":
                out.append(("code", "\n".join(code)))
                code = None
            else:
                code.append(line)
            continue
        if line.strip() == "[codeblock]":
            flush_para()
            flush_pre()
            code = []
        elif line.startswith("  "):
            flush_para()
            pre.append(line)
        elif not line.strip():
            flush_para()
            flush_pre()
        else:
            flush_pre()
            para.append(line.strip())
    flush_para()
    flush_pre()
    return out


def first_sentence(doc: list[str], classes: set[str]) -> str:
    for kind, text in blocks(doc, classes):
        if kind == "para":
            m = re.match(r"(.+?[.!?])(\s|$)", text)
            return (m.group(1) if m else text).strip()
    return ""


def title(script: dict) -> str:
    return script["class_name"] or script["path"]


def render(found: list[dict]) -> str:
    classes = {s["class_name"] for s in found if s["class_name"]}
    out = [
        "<!-- GENERATED by %s — do not edit by hand. Edit the `##` doc comments in"
        " %s/ and rerun it. -->" % (COMMAND, ADDON),
        "# Framework API reference",
        "",
        "> Every class, signal, constant, property and method of the shared"
        " `addons/godotgo` framework, generated from the `##` doc comments in"
        " `%s/`." % ADDON,
        "",
        "Why each piece exists and how the pieces fit together is in"
        " [the framework guide](../framework.md). Paths below are relative to"
        " `%s/`; members whose names start with an underscore are private or"
        " engine callbacks and are not listed." % ADDON,
        "",
        "| Class or script | File | Summary |",
        "| --- | --- | --- |",
    ]
    for s in found:
        name = title(s)
        summary = first_sentence(s["doc"], classes).replace("|", "\\|")
        out.append("| [%s](#%s) | `%s` | %s |" % (name, slug(name), s["path"], summary))
    for s in found:
        out += ["", "## " + title(s), ""]
        facts = []
        if s["class_name"]:
            facts.append("`%s`" % s["path"])
        if s["extends"]:
            facts.append("extends `%s`" % s["extends"])
        if s["tool"]:
            facts.append("`@tool`")
        out.append(" · ".join(facts))
        for kind, text in blocks(s["doc"], classes):
            out.append("")
            if kind == "para":
                out.append(text)
            else:
                out += ["```" + ("gdscript" if kind == "code" else "text"), text, "```"]
        for kind, heading in GROUPS:
            members = [m for m in s["members"] if m["kind"] == kind]
            if not members:
                continue
            out += ["", "### " + heading, ""]
            for m in members:
                decl = m["decl"]
                if m["name"] == "_init" and s["class_name"]:
                    decl = decl.replace("func _init", "%s.new" % s["class_name"], 1)
                    decl = re.sub(r"\s*->\s*void$", "", decl)
                parts = blocks(m["doc"], classes)
                prose = " ".join(t for k, t in parts if k == "para")
                out.append("- `%s`" % decl + (" — " + prose if prose else ""))
                for k, t in parts:
                    if k != "para":
                        out += ["", "  ```" + ("gdscript" if k == "code" else "text")] + ["  " + c for c in t.splitlines()]
                        out += ["  ```", ""]
    out.append("")
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--check", action="store_true", help="exit 1 when the reference is stale")
    args = parser.parse_args(argv)
    text = render(scripts())
    path = os.path.join(ROOT, OUTPUT)
    try:
        with open(path, encoding="utf-8") as fh:
            current = fh.read()
    except OSError:
        current = ""
    if args.check:
        if current != text:
            print("%s is stale: run %s" % (OUTPUT, COMMAND), file=sys.stderr)
            return 1
        print("%s is current" % OUTPUT)
        return 0
    if current != text:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        print("wrote %s" % OUTPUT)
    else:
        print("%s already current" % OUTPUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
