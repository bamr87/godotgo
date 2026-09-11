#!/usr/bin/env bash
# Boot a game's main scene without a window and fail on any error or warning.
#
# Usage: tools/smoke.sh                  every game
#        tools/smoke.sh leap             one game
#        tools/smoke.sh leap --expect RE  also require a log line matching RE
#
# Every GodotGo game prints "[godotgo] session start ..." from Session.start(),
# which is the default expectation.
#
# Known, tolerated noise: Godot's dummy (headless) renderer sometimes reports
# "N RID allocations of type 'N13RendererDummy...' were leaked at exit" when
# particle or shader materials are alive at quit. Every other ERROR line fails.
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$GODOTGO_ROOT"

expect="\[godotgo\] session start"
names=()
while [ $# -gt 0 ]; do
	case "$1" in
		--expect) expect="$2"; shift 2 ;;
		*) names+=("$1"); shift ;;
	esac
done

projects=()
if [ ${#names[@]} -eq 0 ]; then
	while IFS= read -r p; do projects+=("$p"); done < <(godotgo_games)
else
	while IFS= read -r p; do projects+=("$p"); done < <(godotgo_resolve_many "${names[@]}") || exit 2
fi

status=0
for proj in "${projects[@]}"; do
	echo "==> $proj"
	log="$(mktemp)"
	HEADLESS=1 tools/run.sh "$proj" >"$log" 2>&1
	rc=$?
	grep -vE "^Godot Engine|^\s*$|RID allocations of type 'N13RendererDummy" "$log" | sed 's/^/    /'
	if [ $rc -ne 0 ]; then echo "    smoke: godot exited with $rc" >&2; status=1; fi
	if grep -vE "RID allocations of type 'N13RendererDummy" "$log" | grep -qE "SCRIPT ERROR|ERROR:|WARNING:"; then
		echo "    smoke: errors or warnings in output" >&2; status=1
	fi
	if [ -n "$expect" ] && ! grep -qE "$expect" "$log"; then
		echo "    smoke: expected log line not found: $expect" >&2; status=1
	fi
	rm -f "$log"
done
[ $status -eq 0 ] && echo "smoke: OK"
exit $status
