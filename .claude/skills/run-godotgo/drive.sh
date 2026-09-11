#!/usr/bin/env bash
# Run a GodotGo game for real, drive it with scripted input, and write PNG
# screenshots you can look at.
#
# Usage:
#   .claude/skills/run-godotgo/drive.sh <game> [steps] [out-dir]
#   .claude/skills/run-godotgo/drive.sh leap wait:60,shot:boot,state
#   .claude/skills/run-godotgo/drive.sh swarm 'press:fire:30,shot:shooting,state'
#
#   GODOTGO_DRIVE_HOST=1   run on the host with a real window instead of the
#                          container (macOS: this opens a window you can watch)
#
# Steps are handed straight to driver.gd; see its header for the grammar:
#   wait:N  press:ACTION:N  tap:ACTION  shot:NAME  state
# Frame counts are PHYSICS frames, so 60 is one second of game time.
#
# By default everything happens inside the toolchain container under Xvfb with
# Mesa's lavapipe software Vulkan, which is why this needs no GPU, no display
# and nothing installed but Docker. That is also the difference between this and
# tools/smoke.sh: smoke boots with --headless, which selects the dummy renderer,
# so it proves a scene loads but cannot produce a pixel or read a score.
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../../tools/lib.sh"
cd "$GODOTGO_ROOT"

game="${1:-}"
steps="${2:-wait:60,shot:boot,state}"
out="${3:-build/shots}"
if [ -z "$game" ]; then
	echo "usage: .claude/skills/run-godotgo/drive.sh <game> [steps] [out-dir]" >&2
	echo "games: $(godotgo_games | sed 's|games/||' | tr '\n' ' ')" >&2
	exit 2
fi
proj="$(godotgo_resolve "$game")" || exit 2
if [ "$proj" = "framework" ]; then
	echo "framework has no main scene; drive a game instead" >&2
	exit 2
fi
mkdir -p "$out"

# driver.gd sits outside every Godot project, which res:// cannot address, so it
# is passed as an absolute filesystem path. Godot's --script accepts that.
driver_rel=".claude/skills/run-godotgo/driver.gd"

if [ "${GODOTGO_DRIVE_HOST:-0}" = "1" ]; then
	echo "==> $proj on the host (a window will open)"
	exec tools/godot.sh --path "$proj" --audio-driver Dummy \
		--script "$GODOTGO_ROOT/$driver_rel" \
		-- "--out=$GODOTGO_ROOT/$out" "--steps=$steps"
fi

echo "==> $proj in the container under Xvfb -> $out"
# --audio-driver Dummy: the image has no sound card, and ALSA's failure to open
# one prints a dozen lines of noise plus an ERROR before falling back anyway.
docker compose -f docker/compose.yml run --rm godot bash -lc "
set -o pipefail
Xvfb :99 -screen 0 1280x720x24 >/tmp/xvfb.log 2>&1 &
# Xvfb needs a moment to create the socket; without this Godot exits with
# 'Unable to open X display' on a cold container.
for i in \$(seq 1 25); do [ -e /tmp/.X11-unix/X99 ] && break; sleep 0.2; done
export DISPLAY=:99
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json
godot --path '$proj' --audio-driver Dummy --script '/workspace/$driver_rel' \
  -- '--out=/workspace/$out' '--steps=$steps'
" 2>&1 | grep -vE "^ (Container|Network) |^$"
rc=${PIPESTATUS[0]}

shots="$(find "$out" -name '*.png' -newermt '-2 minutes' 2>/dev/null | sort)"
[ -n "$shots" ] && { echo "==> screenshots:"; echo "$shots" | sed 's/^/    /'; }
[ "$rc" -eq 0 ] || echo "==> driver exited $rc" >&2
exit "$rc"
