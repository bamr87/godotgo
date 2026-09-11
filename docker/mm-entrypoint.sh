#!/usr/bin/env bash
# Runs Material Maker under Xvfb. Arguments are passed straight to the binary,
# e.g.  --export-material -t "Godot/Godot 4 Standard" -o /project/materials/x /project/materials/x/x.ptex
# Material Maker sometimes crashes or hangs on quit after writing its files, so
# a timeout bounds the run; callers should judge success by the output files.
set -o pipefail
cd /workspace 2>/dev/null || true
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-root}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
# MM_EXTRA: extra Godot engine flags (e.g. "--verbose --rendering-method mobile").
# Engine flags are consumed before Material Maker parses its own arguments, so
# they can safely precede --export-material.
# shellcheck disable=SC2086
exec timeout --signal=TERM --kill-after=10 "${MM_TIMEOUT:-900}" \
	xvfb-run -a -s "-screen 0 1280x720x24" \
	"${MM_BIN:-/opt/material-maker/material_maker.x86_64}" ${MM_EXTRA:-} "$@"
