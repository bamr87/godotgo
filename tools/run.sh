#!/usr/bin/env bash
# Play a game with a window.
#
# Usage: tools/run.sh leap                       play a game's main scene
#        tools/run.sh leap res://scenes/x.tscn   play a specific scene
#        HEADLESS=1 tools/run.sh leap            windowless boot for ~2 s (CI)
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$GODOTGO_ROOT"

proj="$(godotgo_resolve "${1:-}")" || exit 2
shift
extra=()
[ "${HEADLESS:-0}" = "1" ] && extra=(--headless --quit-after 120)
exec tools/godot.sh --path "$proj" ${extra[@]+"${extra[@]}"} "$@"
