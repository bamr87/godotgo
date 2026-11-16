#!/usr/bin/env bash
# Export a release build of a game.
#
# Usage: tools/export.sh <project> [preset] [output]
#   Presets live in the project's export_presets.cfg ("Linux x86_64", "Linux arm64").
#   Without a preset the one matching this machine's CPU is used.
#   Output defaults to build/<slug>.<arch> at the workspace root. A relative
#   output is taken from the workspace root, an absolute one as it is.
#   Pass '' as the preset to keep the default and still name an output.
#
# Godot export templates are required. They are baked into the toolchain image
# when it is built with WITH_EXPORT_TEMPLATES=1, so the usual invocation is
# `tools/docker.sh export <project>`.
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
godotgo_help "$@"
godotgo_no_options "$@"
cd "$GODOTGO_ROOT" || exit 1

proj="$(godotgo_resolve "${1:-}")" || exit 2
shift
case "$(uname -m)" in
	arm64|aarch64) arch=arm64 ;;
	*) arch=x86_64 ;;
esac
preset="${1:-Linux $arch}"
slug="$(basename "$proj")"
out="${2:-build/$slug.$arch}"
# Godot gets an absolute path and the result is looked for at that same path.
case "$out" in
	/*) abs="$out" ;;
	*) abs="$GODOTGO_ROOT/$out" ;;
esac

if [ ! -f "$proj/export_presets.cfg" ]; then
	echo "$proj has no export_presets.cfg; copy one from games/leap and adjust export_path" >&2
	exit 2
fi
mkdir -p "$(dirname "$abs")"

echo "==> export $proj '$preset' -> $abs"
# A failed import (a missing class_name, say) is the usual reason an export
# fails, so its output is shown rather than discarded, and nothing is exported.
import_log="$(mktemp)"
trap 'rm -f "$import_log"' EXIT
tools/godot.sh --headless --path "$proj" --import >"$import_log" 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then
	{
		echo "==> import failed (Godot exited $rc):"
		grep -vE "^Godot Engine|^\s*$" "$import_log" | tail -40
	} >&2
	exit 1
fi
tools/godot.sh --headless --path "$proj" --export-release "$preset" "$abs" 2>&1 \
	| grep -vE "^Godot Engine|savepack|^\s*$" | tail -20
if [ -x "$abs" ]; then
	echo "==> exported $abs ($(du -h "$abs" | cut -f1))"
	exit 0
fi
echo "==> export failed: $abs was not created (are export templates installed?)" >&2
exit 1
