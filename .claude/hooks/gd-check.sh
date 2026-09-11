#!/usr/bin/env bash
# PostToolUse hook: after Claude edits a .gd/.tscn/.tres file, load it with the
# owning project's Godot so parse errors, missing autoloads and broken scene
# references surface immediately. Exit 2 (blocking feedback) on failure.
#
# The workspace holds several Godot projects, so the hook walks up from the
# edited file to the nearest project.godot and validates inside that project.
set -o pipefail
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0
ROOT="$PWD"

file="$(python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null)"
case "$file" in
	*.gd|*.tscn|*.tres) ;;
	*) exit 0 ;;
esac
[[ -f "$file" ]] || exit 0

# Nearest enclosing Godot project.
proj_dir="$(cd "$(dirname "$file")" && pwd)"
while [[ "$proj_dir" != "/" && ! -f "$proj_dir/project.godot" ]]; do
	proj_dir="$(dirname "$proj_dir")"
done
if [[ ! -f "$proj_dir/project.godot" ]]; then
	# Shared addon file: validate through the framework project that owns it.
	proj_dir="$ROOT/framework"
	[[ -f "$proj_dir/project.godot" ]] || exit 0
fi

abs="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
rel="${abs#"$proj_dir"/}"
# A file outside every project - agent tooling under .claude/, for instance -
# has no res:// path, and asking Godot to load one produces res:///abs/path and
# a confusing failure. Godot can still run such a script by absolute path
# (--script /abs/file.gd), but running it is not checking it, so skip.
[[ "$rel" == /* ]] && exit 0

if [[ "$rel" == *.gd ]]; then
	cls="$(grep -Eo '^class_name[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$abs" | awk '{print $2}')"
	if [[ -n "$cls" ]] && ! grep -q "\"$cls\"" "$proj_dir/.godot/global_script_class_cache.cfg" 2>/dev/null; then
		tools/godot.sh --headless --path "$proj_dir" --import >/dev/null 2>&1
	fi
fi

out="$(tools/godot.sh --headless --path "$proj_dir" \
	--script res://addons/godotgo/tools/check_scripts.gd -- "$rel" 2>&1 | grep -v '^Godot Engine')"
rc=${PIPESTATUS[0]}
if [[ $rc -ne 0 ]] || grep -qE "SCRIPT ERROR|^ERROR:|^FAIL " <<<"$out"; then
	echo "Godot failed to load $rel (project: ${proj_dir#"$ROOT"/}):" >&2
	echo "$out" >&2
	exit 2
fi
exit 0
