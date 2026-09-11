#!/usr/bin/env bash
# Container entrypoint. Runs the given command inside the project directory.
# When DISPLAY is unset and a command needs a window (Material Maker, non-headless
# Godot), wrap it with xvfb-run: set XVFB=1.
set -e
cd /workspace 2>/dev/null || true
if [[ "${XVFB:-0}" == "1" ]]; then
	exec xvfb-run -a -s "-screen 0 1280x720x24" "$@"
fi
exec "$@"
