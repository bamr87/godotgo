# shellcheck shell=bash
# Shared helpers for the GodotGo workspace tools: locate the root, enumerate
# Godot projects, and resolve a friendly project name to a path.
#
# A "project" is any directory with a project.godot: the framework itself
# (framework/) and every game under games/.

GODOTGO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The Godot release this workspace targets, in one place. tools/install_godot.sh
# fetches it, tools/docker.sh passes it as a build argument, and the CI action
# reads it from here, so the host, the container and CI cannot drift apart.
# Every project's config/features declares the matching feature level.
GODOTGO_GODOT_VERSION="4.7.2"
GODOTGO_GODOT_RELEASE="stable"

# The Godot AI release this workspace integrates (github.com/hi-godot/godot-ai,
# MIT). tools/install_godot_ai.sh fetches it into vendor/ and symlinks it into
# every project; tools/godot_ai.sh launches its MCP bridge. It is an optional,
# editor-only dependency: the headless gate never loads it.
GODOTGO_GODOT_AI_VERSION="4.0.4"

# Fails if anything that names the Godot version has drifted from the value
# above. The Dockerfiles and compose carry their own default so they still build
# without tools/docker.sh, and every project declares a matching feature level;
# each of those is a copy, and a copy nobody checks is a copy that goes stale.
godotgo_check_version_pins() {
	local feature="${GODOTGO_GODOT_VERSION%.*}" bad=0 f want got p
	for f in docker/Dockerfile docker/Dockerfile.material-maker-src docker/compose.yml; do
		[ -f "$GODOTGO_ROOT/$f" ] || continue
		while IFS= read -r got; do
			[ "$got" = "$GODOTGO_GODOT_VERSION" ] && continue
			echo "  $f names Godot $got, tools/lib.sh says $GODOTGO_GODOT_VERSION" >&2
			bad=1
		done <<EOF
$(grep -oE 'GODOT_VERSION[:=]?[[:space:]]*"?\$?\{?GODOT_VERSION:-([0-9.]+)\}?"?|ARG GODOT_VERSION=[0-9.]+' "$GODOTGO_ROOT/$f" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
EOF
	done
	want="\"$feature\""
	while IFS= read -r p; do
		got="$(grep -o 'config/features=PackedStringArray([^)]*)' "$GODOTGO_ROOT/$p/project.godot" 2>/dev/null)"
		case "$got" in
			*"$want"*) ;;
			*) echo "  $p/project.godot config/features is $got, expected $want" >&2; bad=1 ;;
		esac
	done <<EOF
$(godotgo_projects; [ -f "$GODOTGO_ROOT/templates/blank/project.godot" ] && echo "templates/blank")
EOF
	# The Godot AI addon is optional and gitignored, so its absence is fine; an
	# installed copy at the wrong version is not, because the MCP bridge pins the
	# matching PyPI server and the two must be the same release.
	local cfg="$GODOTGO_ROOT/vendor/godot_ai/plugin.cfg"
	if [ -f "$cfg" ]; then
		got="$(sed -n 's/^version="\(.*\)"$/\1/p' "$cfg")"
		if [ "$got" != "$GODOTGO_GODOT_AI_VERSION" ]; then
			echo "  vendor/godot_ai is $got, tools/lib.sh says $GODOTGO_GODOT_AI_VERSION" >&2
			echo "  fix with tools/install_godot_ai.sh --force" >&2
			bad=1
		fi
	fi
	[ "$bad" -eq 0 ] || { echo "  version pins have drifted from tools/lib.sh" >&2; return 1; }
	return 0
}

# Adds or removes an addon from a project.godot's enabled-plugin list, leaving
# the rest of the file untouched. Godot reads this only in the editor, so a
# project whose optional addons are not installed still verifies headlessly.
#   godotgo_set_editor_plugin <project.godot> <res://.../plugin.cfg> on|off
godotgo_set_editor_plugin() {
	GODOTGO_PLUGIN_LINE="$2" python3 - "$1" "$3" <<'GODOTGO_PY'
import os, re, sys

path, want = sys.argv[1], sys.argv[2] == "on"
entry = os.environ["GODOTGO_PLUGIN_LINE"]
text = open(path).read()
m = re.search(r'^enabled=PackedStringArray\(([^)]*)\)$', text, re.M)
items = re.findall(r'"([^"]*)"', m.group(1)) if m else []
had = entry in items
if want and not had:
    items.append(entry)
elif not want and had:
    items = [i for i in items if i != entry]
else:
    sys.exit(0)

if not items and m:
    # Drop an emptied list rather than leaving enabled=PackedStringArray().
    text = re.sub(r'\n?\[editor_plugins\]\n\nenabled=PackedStringArray\([^)]*\)\n', '\n', text, count=1)
elif m:
    rendered = 'enabled=PackedStringArray(%s)' % ", ".join('"%s"' % i for i in items)
    text = text[:m.start()] + rendered + text[m.end():]
else:
    text = text.rstrip("\n") + '\n\n[editor_plugins]\n\nenabled=PackedStringArray("%s")\n' % entry
open(path, "w").write(text)
GODOTGO_PY
}

# Sets or removes an autoload entry in a project.godot.
#   godotgo_set_autoload <project.godot> <name> <res://path.gd>   add
#   godotgo_set_autoload <project.godot> <name> ""                remove
# Godot AI adds its own game-side helper autoload when its plugin is enabled,
# which lands in a tracked file while the script it points at is gitignored, so
# the installer has to put it back and take it away again deliberately.
godotgo_set_autoload() {
	GODOTGO_AUTOLOAD_NAME="$2" GODOTGO_AUTOLOAD_PATH="${3:-}" python3 - "$1" <<'GODOTGO_PY'
import os, re, sys

path = sys.argv[1]
name = os.environ["GODOTGO_AUTOLOAD_NAME"]
target = os.environ["GODOTGO_AUTOLOAD_PATH"]
text = open(path).read()
line_re = re.compile(r'^%s="\*?[^"]*"\n' % re.escape(name), re.M)

if not target:
    new = line_re.sub("", text)
    # An [autoload] section left with no entries is noise; drop it.
    new = re.sub(r'\n?\[autoload\]\n\n(?=\[)', '\n', new)
    if new != text:
        open(path, "w").write(new)
    sys.exit(0)

entry = '%s="*%s"\n' % (name, target)
if line_re.search(text):
    new = line_re.sub(entry, text)
elif re.search(r'^\[autoload\]$', text, re.M):
    new = re.sub(r'^(\[autoload\]\n\n)', r'\1' + entry.replace("\\", "\\\\"), text, count=1, flags=re.M)
else:
    new = text.rstrip("\n") + '\n\n[autoload]\n\n' + entry
if new != text:
    open(path, "w").write(new)
GODOTGO_PY
}

# Fails if a project.godot points at an autoload or editor plugin that is not
# on disk. Godot AI writes both into tracked files while its own tree is
# gitignored, so an orphaned reference is easy to create and, left alone, breaks
# the project for everyone who has not installed it - including CI.
godotgo_check_project_refs() {
	local bad=0 proj ref target
	while IFS= read -r proj; do
		while IFS= read -r ref; do
			[ -n "$ref" ] || continue
			target="$GODOTGO_ROOT/$proj/${ref#res://}"
			[ -e "$target" ] && continue
			echo "  $proj/project.godot references $ref, which is not on disk" >&2
			bad=1
		done <<EOF
$(grep -oE '"\*?res://[^"]+"' "$GODOTGO_ROOT/$proj/project.godot" 2>/dev/null | tr -d '"' | sed 's/^\*//')
EOF
	done <<EOF
$(godotgo_projects)
EOF
	[ "$bad" -eq 0 ] || {
		echo "  install the missing addon (tools/install_godot_ai.sh) or remove the reference" >&2
		return 1
	}
	return 0
}

# Prints every project in the workspace as a root-relative path, framework first.
godotgo_projects() {
	local p
	[ -f "$GODOTGO_ROOT/framework/project.godot" ] && echo "framework"
	for p in "$GODOTGO_ROOT"/games/*/project.godot; do
		[ -f "$p" ] || continue
		echo "games/$(basename "$(dirname "$p")")"
	done
	return 0
}

# Prints only the games (no framework).
godotgo_games() {
	godotgo_projects | grep '^games/' || true
}

# Resolves "leap", "games/leap", "framework" or a path to a root-relative path.
godotgo_resolve() {
	local name="${1:-}" p
	case "$name" in
		"") echo "godotgo: no project given" >&2; godotgo_list_to_stderr; return 2 ;;
		framework) p="framework" ;;
		*/*) p="${name#./}"; p="${p%/}" ;;
		*) p="games/$name" ;;
	esac
	if [ ! -f "$GODOTGO_ROOT/$p/project.godot" ]; then
		echo "godotgo: no Godot project at '$p'" >&2
		godotgo_list_to_stderr
		return 2
	fi
	echo "$p"
}

godotgo_list_to_stderr() {
	echo "known projects:" >&2
	godotgo_projects | sed 's/^/  /' >&2
}

# Expands the argument list into project paths; empty means every project.
godotgo_resolve_many() {
	local name p
	if [ $# -eq 0 ] || [ "${1:-}" = "all" ]; then
		godotgo_projects
		return 0
	fi
	for name in "$@"; do
		p="$(godotgo_resolve "$name")" || return 2
		echo "$p"
	done
}

# Lists a project's own source files (project-relative). The shared addon is a
# symlink inside games, so it is checked once, in the framework project.
godotgo_source_files() {
	local proj="$1" dir="$GODOTGO_ROOT/$1"
	if [ "$proj" = "framework" ]; then
		# addons/godotgo, not addons/*: a project may also carry vendored
		# third-party addons (tools/install_godot_ai.sh), and those are a
		# dependency to load, not source of ours to lint and format.
		( cd "$dir" && find addons/godotgo tests -type f \( -name '*.gd' -o -name '*.tscn' -o -name '*.tres' \) 2>/dev/null | sort )
	else
		( cd "$dir" && find . -type f \( -name '*.gd' -o -name '*.tscn' -o -name '*.tres' \) \
			-not -path './addons/*' -not -path './.godot/*' 2>/dev/null | sed 's|^\./||' | sort )
	fi
}

# Path to a gdtoolkit binary (gdlint, gdformat), or empty when it is not
# installed. The workspace .venv is preferred, but only after checking that it
# actually runs: the Docker image bind-mounts the host workspace, so a .venv
# built on the host has a shebang pointing at an interpreter the container does
# not have. In that case the image's own copy on PATH is the right one.
godotgo_gdtool() {
	local name="$1" venv="$GODOTGO_ROOT/.venv/bin/$1"
	if [ -x "$venv" ] && "$venv" --version >/dev/null 2>&1; then
		echo "$venv"
		return 0
	fi
	command -v "$name" 2>/dev/null || true
}
