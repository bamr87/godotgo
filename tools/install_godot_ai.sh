#!/usr/bin/env bash
# Install the Godot AI editor addon (github.com/hi-godot/godot-ai, MIT) into
# every project in this workspace, so a live editor can be driven over MCP.
#
# Usage: tools/install_godot_ai.sh [--force] [--uninstall]
#
# One copy is fetched into vendor/godot_ai and symlinked into each project's
# addons/, the same shape the framework addon uses, so five projects share one
# tree. The version comes from tools/lib.sh.
#
# Everything this writes is gitignored. It deliberately does NOT enable the
# plugin, because enabling means editing project.godot, and that file is tracked
# while the addon it would point at is not: committing those lines breaks the
# project for everyone who never installed it, CI included. tools/godot_ai.sh
# edit adds them for the length of an editor session and takes them out again.
#
# The upstream install is "download a zip from the asset store and unzip it".
# This verifies the release's published SHA-256 first: the archive carries a
# signed manifest and there is no reason not to check it.
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$GODOTGO_ROOT"

force=0
uninstall=0
for arg in "$@"; do
	case "$arg" in
		--force) force=1 ;;
		--uninstall) uninstall=1 ;;
		*) echo "usage: tools/install_godot_ai.sh [--force] [--uninstall]" >&2; exit 2 ;;
	esac
done

tag="v${GODOTGO_GODOT_AI_VERSION}"
dest="$GODOTGO_ROOT/vendor/godot_ai"
plugin_line='res://addons/godot_ai/plugin.cfg'
# Godot AI adds this itself the first time its plugin loads in an editor,
# writing into a tracked project.godot while its own tree stays gitignored.
# Managing it here keeps install and uninstall symmetric, so a checkout is
# never left pointing at a script that is not there.
helper_autoload='_mcp_game_helper'

# Projects only. templates/blank is deliberately left alone: it is committed,
# and an enable line for a gitignored addon would be a dangling reference in
# every game scaffolded on a machine that does not have it. tools/new_game.sh
# adds the link and the line when this install is actually present.
godotgo_addon_hosts() {
	godotgo_projects
}

if [ "$uninstall" -eq 1 ]; then
	while IFS= read -r proj; do
		link="$GODOTGO_ROOT/$proj/addons/godot_ai"
		[ -L "$link" ] && rm -f "$link" && echo "    unlinked $proj/addons/godot_ai"
		# Also clears anything an interrupted editor session left behind.
		godotgo_set_editor_plugin "$GODOTGO_ROOT/$proj/project.godot" "$plugin_line" off
		godotgo_set_autoload "$GODOTGO_ROOT/$proj/project.godot" "$helper_autoload" ""
	done < <(godotgo_addon_hosts)
	rm -rf "$dest"
	[ -d "$GODOTGO_ROOT/vendor" ] && rmdir "$GODOTGO_ROOT/vendor" 2>/dev/null
	echo "==> removed godot-ai"
	exit 0
fi

if [ -f "$dest/plugin.cfg" ] && [ "$force" -eq 0 ]; then
	have="$(sed -n 's/^version="\(.*\)"$/\1/p' "$dest/plugin.cfg")"
	if [ "$have" = "$GODOTGO_GODOT_AI_VERSION" ]; then
		echo "already installed: godot-ai $have"
	else
		echo "replacing godot-ai $have with $GODOTGO_GODOT_AI_VERSION"
		force=1
	fi
fi

if [ ! -f "$dest/plugin.cfg" ] || [ "$force" -eq 1 ]; then
	base="https://github.com/hi-godot/godot-ai/releases/download/$tag"
	tmp="$(mktemp -d)"
	trap 'rm -rf "$tmp"' EXIT

	echo "==> downloading godot-ai $tag"
	curl -fL --progress-bar -o "$tmp/plugin.zip" "$base/godot-ai-v4-plugin.zip" \
		|| { echo "download failed: $base/godot-ai-v4-plugin.zip" >&2; exit 1; }
	curl -fsSL -o "$tmp/manifest.json" "$base/godot-ai-v4-plugin.manifest.json" \
		|| { echo "manifest download failed" >&2; exit 1; }

	want="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["asset"]["sha256"])' "$tmp/manifest.json")"
	got="$(shasum -a 256 "$tmp/plugin.zip" | awk '{print $1}')"
	if [ -z "$want" ] || [ "$want" != "$got" ]; then
		echo "checksum mismatch for godot-ai-v4-plugin.zip" >&2
		echo "  published $want" >&2
		echo "  received  $got" >&2
		exit 1
	fi
	echo "    sha256 verified against the published manifest"

	unzip -q "$tmp/plugin.zip" -d "$tmp/out" || { echo "unzip failed" >&2; exit 1; }
	[ -f "$tmp/out/addons/godot_ai/plugin.cfg" ] \
		|| { echo "unexpected archive layout: no addons/godot_ai/plugin.cfg" >&2; exit 1; }
	rm -rf "$dest"
	mkdir -p "$(dirname "$dest")"
	mv "$tmp/out/addons/godot_ai" "$dest"
fi

installed="$(sed -n 's/^version="\(.*\)"$/\1/p' "$dest/plugin.cfg")"
echo "==> godot-ai $installed in ${dest#"$GODOTGO_ROOT"/}"

while IFS= read -r proj; do
	mkdir -p "$GODOTGO_ROOT/$proj/addons"
	# Relative, so the link keeps working wherever the workspace is checked out
	# and inside the container, where /workspace is a different absolute path.
	up="$(echo "$proj" | awk -F/ '{for(i=0;i<=NF;i++) printf "../"}')"
	ln -sfn "${up}vendor/godot_ai" "$GODOTGO_ROOT/$proj/addons/godot_ai"
	echo "    $proj"
done < <(godotgo_addon_hosts)

if ! command -v uvx >/dev/null 2>&1; then
	echo ""
	echo "warning: uvx is not on PATH, and godot-ai runs its MCP server through it." >&2
	echo "  install uv with one of:" >&2
	echo "    brew install uv" >&2
	echo "    curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
	echo "  then re-run tools/godot_ai.sh doctor" >&2
fi

echo ""
echo "next: tools/godot_ai.sh doctor    # check the whole path is ready"
echo "      tools/godot_ai.sh edit leap # open the editor with the bridge live"
