#!/usr/bin/env bash
# Download the Godot release this workspace targets into .godot-bin/, so the
# host runs exactly the engine the container and CI run.
#
# Usage: tools/install_godot.sh [--force]
#
# tools/godot.sh prefers .godot-bin/godot over anything installed system-wide,
# so nothing outside the workspace is touched or replaced. The directory is
# gitignored. The version comes from tools/lib.sh.
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$GODOTGO_ROOT"

force=0
[ "${1:-}" = "--force" ] && force=1

tag="${GODOTGO_GODOT_VERSION}-${GODOTGO_GODOT_RELEASE}"
dest="$GODOTGO_ROOT/.godot-bin"
bin="$dest/godot"

if [ -x "$bin" ] && [ "$force" -eq 0 ]; then
	have="$("$bin" --version 2>/dev/null | head -1)"
	case "$have" in
		"${GODOTGO_GODOT_VERSION}."*) echo "already installed: $have"; exit 0 ;;
	esac
	echo "replacing $have with $tag"
fi

case "$(uname -s)" in
	Darwin) asset="Godot_v${tag}_macos.universal.zip" ;;
	Linux)
		case "$(uname -m)" in
			aarch64|arm64) asset="Godot_v${tag}_linux.arm64.zip" ;;
			*) asset="Godot_v${tag}_linux.x86_64.zip" ;;
		esac
		;;
	*) echo "unsupported platform $(uname -s); set GODOT_BIN by hand" >&2; exit 2 ;;
esac

url="https://github.com/godotengine/godot-builds/releases/download/${tag}/${asset}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "==> downloading $asset"
curl -fL --progress-bar -o "$tmp/godot.zip" "$url" || { echo "download failed: $url" >&2; exit 1; }
unzip -q "$tmp/godot.zip" -d "$tmp/out"

rm -rf "$dest"
mkdir -p "$dest"
if [ -d "$tmp/out/Godot.app" ]; then
	# macOS ships an app bundle; keep it whole and point the wrapper inside it.
	mv "$tmp/out/Godot.app" "$dest/Godot.app"
	ln -sf "Godot.app/Contents/MacOS/Godot" "$bin"
else
	mv "$tmp/out/"Godot_v* "$bin"
	chmod +x "$bin"
fi

installed="$("$bin" --version 2>/dev/null | head -1)"
echo "==> installed $installed at ${bin#"$GODOTGO_ROOT"/}"
case "$installed" in
	"${GODOTGO_GODOT_VERSION}."*) ;;
	*) echo "warning: expected ${GODOTGO_GODOT_VERSION}, got $installed" >&2 ;;
esac
