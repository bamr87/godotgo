#!/usr/bin/env bash
# Locate the Godot 4 binary and exec it with the given arguments.
#
# Resolution order: $GODOT_BIN, the workspace's own pinned copy in .godot-bin
# (put there by tools/install_godot.sh), then `godot`/`godot4` on PATH and the
# usual macOS app bundles. The pinned copy comes first so the host runs the same
# engine as the container and CI; nothing outside the workspace is touched.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

candidates=(
	"${GODOT_BIN:-}"
	"$here/.godot-bin/godot"
	"$(command -v godot 2>/dev/null || true)"
	"$(command -v godot4 2>/dev/null || true)"
	"/Applications/Godot.app/Contents/MacOS/Godot"
	"$HOME/Applications/Godot.app/Contents/MacOS/Godot"
	"$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
	"/usr/local/bin/godot"
	"/opt/homebrew/bin/godot"
)

for bin in "${candidates[@]}"; do
	if [[ -n "$bin" && -x "$bin" ]]; then
		exec "$bin" "$@"
	fi
done

echo "godot.sh: Godot 4 binary not found. Set GODOT_BIN=/path/to/Godot or put 'godot' on PATH." >&2
exit 127
