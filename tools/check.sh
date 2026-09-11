#!/usr/bin/env bash
# Validate Godot projects headlessly: import, load every script, scene and
# resource inside a live SceneTree (so autoloads and class_names resolve), then
# gdlint + gdformat --check when gdtoolkit is installed.
#
# Usage: tools/check.sh                     every project in the workspace
#        tools/check.sh leap                one project
#        tools/check.sh leap scripts/x.gd   specific files in that project
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$GODOTGO_ROOT"

GODOT="tools/godot.sh"
status=0

check_project() {
	local proj="$1"; shift
	local files=("$@")
	echo "==> $proj"
	if [ ${#files[@]} -eq 0 ]; then
		if ! "$GODOT" --headless --path "$proj" --import >/tmp/godotgo-import.log 2>&1; then
			cat /tmp/godotgo-import.log >&2
			status=1
		fi
		while IFS= read -r f; do files+=("$f"); done < <(godotgo_source_files "$proj")
	fi
	[ ${#files[@]} -eq 0 ] && { echo "    (no source files)"; return; }

	local out rc
	out="$("$GODOT" --headless --path "$proj" \
		--script res://addons/godotgo/tools/check_scripts.gd -- "${files[@]}" 2>&1 | grep -v '^Godot Engine')"
	rc=${PIPESTATUS[0]}
	if [ "$rc" -ne 0 ] || grep -qE "SCRIPT ERROR|^ERROR:|^FAIL " <<<"$out"; then
		echo "$out" >&2
		status=1
	else
		echo "    $(tail -1 <<<"$out")"
	fi

	local gd_files=() f
	for f in "${files[@]}"; do [[ "$f" == *.gd ]] && gd_files+=("$proj/$f"); done
	[ ${#gd_files[@]} -eq 0 ] && return
	local gdlint gdformat
	gdlint="$(godotgo_gdtool gdlint)"
	gdformat="$(godotgo_gdtool gdformat)"
	if [ -n "$gdlint" ]; then
		"$gdlint" "${gd_files[@]}" >/dev/null 2>/tmp/godotgo-lint.log || { cat /tmp/godotgo-lint.log >&2; status=1; }
	fi
	if [ -n "$gdformat" ]; then
		"$gdformat" --check "${gd_files[@]}" >/dev/null 2>/tmp/godotgo-fmt.log \
			|| { cat /tmp/godotgo-fmt.log >&2; echo "    fix with: $gdformat ${gd_files[*]}" >&2; status=1; }
	fi
	if [ -z "$gdlint" ]; then
		echo "    (gdlint skipped: python3 -m venv .venv && .venv/bin/pip install gdtoolkit)"
	fi
	return 0
}

# "tools/check.sh <project> <file> ..." narrows to specific files in one project;
# anything else is a list of whole projects (empty means all of them).
one=""
[ $# -ge 2 ] && one="$(godotgo_resolve "$1" 2>/dev/null || true)"
if [ -n "$one" ] && [ -f "$GODOTGO_ROOT/$one/$2" ]; then
	shift
	check_project "$one" "$@"
else
	projects=()
	while IFS= read -r p; do projects+=("$p"); done < <(godotgo_resolve_many "$@") || exit 2
	for p in "${projects[@]}"; do check_project "$p"; done
fi

[ $status -eq 0 ] && echo "OK"
exit $status
