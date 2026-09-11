#!/usr/bin/env bash
# Export a Material Maker material into the project with the Docker image.
#
# Usage: tools/mm.sh <material.ptex> [output-dir]
#   output-dir defaults to the .ptex's own folder when it lives under materials/,
#   otherwise materials/<ptex-basename>/ (created if missing).
#   Produces <name>.tres (StandardMaterial3D) plus <name>_albedo.png, _orm.png,
#   _normal.png, _emission.png, _heightmap.png as connected in the graph.
#   Textures are 2048x2048 (Material Maker 1.7 ignores --size on the CLI).
#   An existing <name>.tres is left untouched (so hand edits survive); delete it
#   first to have Material Maker regenerate it.
#
# Environment: MM_TARGET (default "Godot/Godot 4 Standard"), MM_TIMEOUT seconds.
set -o pipefail
cd "$(dirname "$0")/.."

ptex="$1"
if [[ -z "$ptex" || ! -f "$ptex" ]]; then
	echo "usage: tools/mm.sh <material.ptex> [output-dir]" >&2
	exit 2
fi
case "$ptex" in
	/*) echo "pass a path inside the repo (relative to its root)" >&2; exit 2 ;;
esac

name="$(basename "${ptex%.ptex}")"
ptex_dir="$(dirname "$ptex")"
case "$ptex_dir" in
	materials/*) default_out="$ptex_dir" ;;
	*) default_out="materials/$name" ;;
esac
out="${2:-$default_out}"
mkdir -p "$out"
target="${MM_TARGET:-Godot/Godot 4 Standard}"

stamp="$(mktemp)"
echo "==> material maker: $ptex -> $out (target: $target)"
docker compose -f docker/compose.yml run --rm \
	-e MM_TIMEOUT="${MM_TIMEOUT:-900}" \
	material-maker --export-material -t "$target" -o "/workspace/$out" "/workspace/$ptex" 2>&1 \
	| grep -vE "^(Godot Engine|xvfb-run)" || true

fresh="$(find "$out" -newer "$stamp" -type f \( -name "$name.tres" -o -name "${name}_*.png" \) | sort)"
rm -f "$stamp"
if [[ -n "$fresh" ]]; then
	echo "==> exported:"; echo "$fresh" | sed 's/^/    /'
	[[ -f "$out/$name.tres" ]] && ! grep -q "$name.tres" <<<"$fresh" && echo "    (kept existing $out/$name.tres)"
	echo "==> run tools/check.sh (or tools/docker.sh check) so Godot imports the new PNGs"
	exit 0
fi
echo "==> export failed: nothing was written to $out" >&2
exit 1
