#!/usr/bin/env bash
# Play a game with a window.
#
# Usage: tools/run.sh leap                       play a game's main scene
#        tools/run.sh leap res://scenes/x.tscn   play a specific scene
#        HEADLESS=1 tools/run.sh leap            windowless boot for ~2 s (CI)
#   Everything after the project goes to Godot as is.
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# Only the project argument: after it, --help belongs to Godot
# (tools/run.sh leap --help shows Godot's own help).
godotgo_help "${1:-}"
case "${1:-}" in -*) godotgo_reject_option "$1" ;; esac
cd "$GODOTGO_ROOT" || exit 1

proj="$(godotgo_resolve "${1:-}")" || exit 2
shift
extra=()
[ "${HEADLESS:-0}" = "1" ] && extra=(--headless --quit-after 120)
exec tools/godot.sh --path "$proj" ${extra[@]+"${extra[@]}"} "$@"
