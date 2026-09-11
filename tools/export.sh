#!/usr/bin/env bash
# Export a release build of a game.
#
# Usage: tools/export.sh <project> [preset] [output]
#   Presets live in the project's export_presets.cfg ("Linux x86_64", "Linux arm64").
#   Without a preset the one matching this machine's CPU is used.
#   Output defaults to build/<slug>.<arch> at the workspace root.
#
# Godot export templates are required. They are baked into the toolchain image
# when it is built with WITH_EXPORT_TEMPLATES=1, so the usual invocation is
# `tools/docker.sh export <project>`.
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$GODOTGO_ROOT"

proj="$(godotgo_resolve "${1:-}")" || exit 2
shift
case "$(uname -m)" in
	arm64|aarch64) arch=arm64 ;;
	*) arch=x86_64 ;;
esac
preset="${1:-Linux $arch}"
slug="$(basename "$proj")"
out="${2:-build/$slug.$arch}"

if [ ! -f "$proj/export_presets.cfg" ]; then
	echo "$proj has no export_presets.cfg; copy one from games/leap and adjust export_path" >&2
	exit 2
fi
mkdir -p "$(dirname "$out")"

echo "==> export $proj '$preset' -> $out"
tools/godot.sh --headless --path "$proj" --import >/dev/null 2>&1
tools/godot.sh --headless --path "$proj" --export-release "$preset" "$GODOTGO_ROOT/$out" 2>&1 \
	| grep -vE "^Godot Engine|savepack|^\s*$" | tail -20
if [ -x "$out" ]; then
	echo "==> exported $out ($(du -h "$out" | cut -f1))"
	exit 0
fi
echo "==> export failed: $out was not created (are export templates installed?)" >&2
exit 1
