#!/usr/bin/env bash
# Drive the Godot AI MCP bridge for a project in this workspace.
#
# Usage:
#   tools/godot_ai.sh doctor [project]     check every link in the chain
#   tools/godot_ai.sh edit <project>       open the editor with the bridge live
#   tools/godot_ai.sh attach               stdio MCP server (what .mcp.json runs)
#   tools/godot_ai.sh status               is an editor bridge listening?
#
# Godot AI's own setup is a Configure button in an editor dock that writes an
# entry into ~/.claude.json. This wrapper exists so the workspace does not need
# it: `attach` is what the committed .mcp.json runs, so a fresh clone is wired
# without anyone opening a dock, and two things are decided here rather than by
# a default.
#
#   Telemetry. Off. This workspace runs agents unattended; sending anything
#              about a user's project to a third party should be a choice made
#              on purpose, so GODOTGO_AI_TELEMETRY=1 turns it back on.
#   Version.   Pinned in tools/lib.sh, so the bridge and the installed addon
#              cannot drift.
#
# One editor at a time holds the bridge. Godot AI reads its ports from
# EditorSettings, which Godot keeps per install rather than per project, so
# there is no way to give each game its own pair from out here; `status` says
# which project currently has it instead of pretending otherwise.
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$GODOTGO_ROOT"

ADDON_DIR="$GODOTGO_ROOT/vendor/godot_ai"

# Godot AI's own defaults, which the editor plugin reads from EditorSettings
# (godot_ai/http_port, godot_ai/ws_port). Change them there and pass the same
# values here with GODOTGO_AI_HTTP_PORT / GODOTGO_AI_WS_PORT.
HTTP_PORT="${GODOTGO_AI_HTTP_PORT:-8000}"
WS_PORT="${GODOTGO_AI_WS_PORT:-9500}"

# What `edit` adds to project.godot for the length of a session, and takes out
# again afterwards. The autoload is Godot AI's own; it writes it on enable.
PLUGIN_LINE='res://addons/godot_ai/plugin.cfg'
HELPER_AUTOLOAD='_mcp_game_helper'

# Telemetry is off unless asked for, on BOTH paths. The server takes a flag; the
# editor plugin does not - it reads the godot_ai/telemetry_enabled EditorSetting,
# which defaults to ON, and EditorSettings are per install rather than per
# project so the repo cannot carry the preference. The addon documents
# GODOT_AI_DISABLE_TELEMETRY as the override that wins over that setting, which
# is what makes this a decision the workspace can actually make.
if [ "${GODOTGO_AI_TELEMETRY:-0}" = "1" ]; then
	unset GODOT_AI_DISABLE_TELEMETRY
else
	export GODOT_AI_DISABLE_TELEMETRY=1
fi

# True when something is accepting connections there. Uses bash's own /dev/tcp
# so it works in the container too, where lsof is not installed.
godotgo_ai_listening() {
	(exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null && exec 3>&- && return 0
	return 1
}

# The project path of any running Godot editor, so `status` can say which one
# holds the bridge rather than only that something does.
godotgo_ai_editor_projects() {
	ps -eo args= 2>/dev/null | sed -n 's/.*--path \([^ ]*\).*/\1/p' | sort -u
}

# Names whatever holds a port. "Listening" on its own is ambiguous - port 8000
# is popular - and an unrelated process squatting it is the failure that looks
# most like the bridge simply not working.
godotgo_ai_port_holder() {
	command -v lsof >/dev/null 2>&1 || { echo ""; return 0; }
	lsof -nP -iTCP:"$1" -sTCP:LISTEN 2>/dev/null | awk 'NR==2 {print $1}'
}

godotgo_ai_require_installed() {
	[ -f "$ADDON_DIR/plugin.cfg" ] && return 0
	echo "godot-ai is not installed; run tools/install_godot_ai.sh" >&2
	return 1
}

cmd="${1:-doctor}"; shift || true

case "$cmd" in
status)
	if godotgo_ai_listening "$WS_PORT"; then
		echo "editor bridge   listening on ws=$WS_PORT"
		while IFS= read -r path; do
			[ -n "$path" ] || continue
			echo "editor project  $path"
		done < <(godotgo_ai_editor_projects)
	else
		echo "editor bridge   not listening on ws=$WS_PORT"
		echo "                open one with tools/godot_ai.sh edit <project>"
	fi
	if godotgo_ai_listening "$HTTP_PORT"; then
		holder="$(godotgo_ai_port_holder "$HTTP_PORT")"
		echo "mcp server      http=$HTTP_PORT held by ${holder:-an unknown process}"
		echo "                if that is not godot-ai, set GODOTGO_AI_HTTP_PORT"
	else
		echo "mcp server      not running (an MCP client starts it through attach)"
	fi
	;;

edit)
	[ $# -ge 1 ] || { echo "usage: tools/godot_ai.sh edit <project>" >&2; exit 2; }
	proj="$(godotgo_resolve "$1")" || exit 2
	godotgo_ai_require_installed || exit 1
	if godotgo_ai_listening "$WS_PORT"; then
		echo "warning: something already holds ws=$WS_PORT; only one editor can" >&2
		echo "         serve the bridge. tools/godot_ai.sh status says which." >&2
	fi
	project_file="$GODOTGO_ROOT/$proj/project.godot"
	# Enabling an editor plugin means editing project.godot, which is tracked
	# while vendor/godot_ai is not. So the wiring lives exactly as long as the
	# session does: added here, removed on the way out however that happens,
	# including the game-helper autoload Godot AI adds for itself while running.
	# A checkout is therefore never left carrying a reference it cannot resolve.
	godotgo_ai_unwire() {
		godotgo_set_editor_plugin "$project_file" "$PLUGIN_LINE" off
		godotgo_set_autoload "$project_file" "$HELPER_AUTOLOAD" ""
		echo "==> unwired $proj; project.godot is back to its committed state"
	}
	trap godotgo_ai_unwire EXIT INT TERM
	godotgo_set_editor_plugin "$project_file" "$PLUGIN_LINE" on
	echo "==> $proj with the Godot AI bridge (http=$HTTP_PORT ws=$WS_PORT)"
	echo "    the dock reports the connection; an MCP client attaches separately"
	tools/godot.sh --editor --path "$proj"
	;;

attach)
	# Runs as an MCP server on stdio. Nothing may be printed here that is not
	# JSON-RPC, so every diagnostic goes to stderr. It talks to whichever editor
	# holds the bridge, so it takes no project of its own.
	godotgo_ai_require_installed || exit 1
	uvx="$(command -v uvx 2>/dev/null)"
	if [ -z "$uvx" ]; then
		echo "uvx is not on PATH; install uv (brew install uv) then retry" >&2
		exit 1
	fi
	args=(--link-mode copy --from "godot-ai==$GODOTGO_GODOT_AI_VERSION" godot-ai
		attach --port "$HTTP_PORT" --ws-port "$WS_PORT")
	[ "${GODOTGO_AI_TELEMETRY:-0}" = "1" ] || args+=(--disable-telemetry)
	exec "$uvx" "${args[@]}"
	;;

doctor)
	proj="$(godotgo_resolve "${1:-framework}")" || exit 2
	bad=0
	echo "==> godot-ai for $proj"

	if [ -f "$ADDON_DIR/plugin.cfg" ]; then
		have="$(sed -n 's/^version="\(.*\)"$/\1/p' "$ADDON_DIR/plugin.cfg")"
		if [ "$have" = "$GODOTGO_GODOT_AI_VERSION" ]; then
			echo "    addon        $have"
		else
			echo "    addon        $have, but tools/lib.sh pins $GODOTGO_GODOT_AI_VERSION" >&2
			echo "                 fix with tools/install_godot_ai.sh --force" >&2
			bad=1
		fi
	else
		echo "    addon        missing; run tools/install_godot_ai.sh" >&2
		bad=1
	fi

	link="$GODOTGO_ROOT/$proj/addons/godot_ai"
	if [ -d "$link/." ]; then
		echo "    link         $proj/addons/godot_ai"
	else
		echo "    link         missing or broken at $proj/addons/godot_ai" >&2
		bad=1
	fi

	if grep -q 'res://addons/godot_ai/plugin.cfg' "$GODOTGO_ROOT/$proj/project.godot" 2>/dev/null; then
		echo "    enabled      yes (a session is wiring it; not for committing)"
	else
		echo "    enabled      no, as committed; tools/godot_ai.sh edit adds it"
	fi

	if command -v uvx >/dev/null 2>&1; then
		echo "    uvx          $(command -v uvx)"
	else
		echo "    uvx          not found; brew install uv" >&2
		bad=1
	fi

	if grep -q '"godot-ai"' "$GODOTGO_ROOT/.mcp.json" 2>/dev/null; then
		echo "    mcp client   .mcp.json registers godot-ai"
	else
		echo "    mcp client   .mcp.json has no godot-ai entry" >&2
		bad=1
	fi

	if [ "${GODOTGO_AI_TELEMETRY:-0}" = "1" ]; then
		echo "    telemetry    on (GODOTGO_AI_TELEMETRY=1)"
	else
		echo "    telemetry    off (GODOT_AI_DISABLE_TELEMETRY=1, editor and server)"
	fi

	if godotgo_ai_listening "$WS_PORT"; then
		echo "    bridge       an editor is serving ws=$WS_PORT"
	else
		echo "    bridge       no editor yet (tools/godot_ai.sh edit $proj)"
	fi
	if godotgo_ai_listening "$HTTP_PORT"; then
		holder="$(godotgo_ai_port_holder "$HTTP_PORT")"
		case "$holder" in
			""|*godot*|*python*|*uv*) echo "    http port    $HTTP_PORT in use by ${holder:-an unknown process}" ;;
			*)
				echo "    http port    $HTTP_PORT is held by $holder, not godot-ai;" >&2
				echo "                 set GODOTGO_AI_HTTP_PORT to a free port" >&2
				bad=1
				;;
		esac
	fi

	echo ""
	if [ "$bad" -eq 0 ]; then
		echo "    ready: open the editor with tools/godot_ai.sh edit $proj,"
		echo "    then the godot-ai MCP server reaches it from this workspace."
	else
		echo "    not ready; see above" >&2
	fi
	exit "$bad"
	;;

*)
	echo "unknown command: $cmd" >&2
	sed -n '2,/^set -o/p' "$0" | sed '$d' >&2
	exit 2
	;;
esac
