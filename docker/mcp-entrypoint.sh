#!/usr/bin/env bash
# Starts a virtual X display (so run_project / launch_editor can open a window)
# and then runs the Godot MCP server on stdio. Xvfb is started directly rather
# than via xvfb-run because xvfb-run merges the child's stderr into stdout,
# which would corrupt the JSON-RPC stream.
set -e
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-root}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
export DISPLAY=":99"
Xvfb "$DISPLAY" -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 &
for _ in $(seq 1 50); do
	[[ -S "/tmp/.X11-unix/X99" ]] && break
	sleep 0.1
done
cd /workspace 2>/dev/null || true
exec godot-mcp "$@"
