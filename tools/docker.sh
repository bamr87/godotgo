#!/usr/bin/env bash
# Run the workspace's tools inside Docker, so nothing but Docker is needed on
# the host and CI runs exactly what a laptop runs.
#
# Usage:
#   tools/docker.sh build [--no-cache]        build the toolchain image
#   tools/docker.sh verify [project ...]      tools/verify.sh in the container
#   tools/docker.sh check|test|smoke [args]   the matching tools/*.sh
#   tools/docker.sh export <project> [preset] release build (needs WITH_EXPORT_TEMPLATES=1)
#   tools/docker.sh new <slug> [options]      scaffold a game
#   tools/docker.sh godot -- <args>           raw Godot CLI
#   tools/docker.sh exec <cmd...>             any command in the container
#   tools/docker.sh shell                     interactive bash
#   tools/docker.sh mcp                       Godot MCP server on stdio (used by .mcp.json)
#   tools/docker.sh mm -- <args>              Material Maker CLI under Xvfb (see tools/mm.sh)
#   tools/docker.sh mm-build [--no-cache]     rebuild the Material Maker image
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$GODOTGO_ROOT"

# One source of truth for the engine version: compose reads it from here.
export GODOT_VERSION="$GODOTGO_GODOT_VERSION"

compose=(docker compose -f docker/compose.yml)
run=("${compose[@]}" run --rm)

cmd="${1:-verify}"; shift || true
case "$cmd" in
	build) exec "${compose[@]}" build godot "$@" ;;
	verify|check|test|smoke|export) exec "${run[@]}" godot "tools/$cmd.sh" "$@" ;;
	new) exec "${run[@]}" godot tools/new_game.sh "$@" ;;
	run) exec "${run[@]}" -e HEADLESS=1 godot tools/run.sh "$@" ;;
	godot) [[ "${1:-}" == "--" ]] && shift; exec "${run[@]}" godot godot "$@" ;;
	mm) [[ "${1:-}" == "--" ]] && shift; exec "${run[@]}" material-maker "$@" ;;
	mm-build) exec "${compose[@]}" build material-maker "$@" ;;
	exec) exec "${run[@]}" godot "$@" ;;
	shell) exec "${run[@]}" godot bash ;;
	mcp) exec "${run[@]}" -i --no-TTY mcp ;;
	*) echo "unknown command: $cmd" >&2; sed -n '2,/^set -o/p' "$0" | sed '$d' >&2; exit 2 ;;
esac
