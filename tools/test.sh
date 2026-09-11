#!/usr/bin/env bash
# Run headless test suites (tests/unit/test_*.gd) with the framework's runner.
#
# Usage: tools/test.sh                every project
#        tools/test.sh leap           one project
#        tools/test.sh leap player    only tests whose file or method matches
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$GODOTGO_ROOT"

# Arguments may name projects and, at most, one filter. Anything that resolves
# to a project is one; the first thing that does not is the filter. Getting this
# wrong once made a multi-project run silently test nothing, so it is explicit.
filter=""
projects=()
for arg in "$@"; do
	if [ "$arg" = "all" ]; then
		continue
	elif p="$(godotgo_resolve "$arg" 2>/dev/null)"; then
		projects+=("$p")
	elif [ -z "$filter" ]; then
		filter="$arg"
	else
		echo "godotgo: '$arg' is neither a project nor usable as a second filter" >&2
		godotgo_list_to_stderr
		exit 2
	fi
done
if [ ${#projects[@]} -eq 0 ]; then
	while IFS= read -r p; do projects+=("$p"); done < <(godotgo_projects)
fi

args=()
[ -n "$filter" ] && args=(-- "--filter=$filter")

status=0
total=0
for proj in "${projects[@]}"; do
	[ -d "$proj/tests/unit" ] || continue
	echo "==> $proj"
	out="$(tools/godot.sh --headless --path "$proj" \
		--script res://addons/godotgo/testing/test_runner.gd ${args[@]+"${args[@]}"} 2>&1 | grep -v '^Godot Engine')"
	rc=${PIPESTATUS[0]}
	echo "$out" | grep -vE "^\s*$"
	[ "$rc" -ne 0 ] && status=1
	# A GDScript fault (calling a method that does not exist, a bad cast) prints
	# SCRIPT ERROR and keeps going, so a broken assertion can otherwise be
	# reported as a pass. Deliberate push_error diagnostics print plain ERROR
	# and are left alone.
	if grep -q "SCRIPT ERROR" <<<"$out"; then
		echo "  a script fault occurred during the run; see the SCRIPT ERROR above" >&2
		status=1
	fi
	n="$(grep -oE "(PASSED|FAILED): [0-9]+" <<<"$out" | head -1 | grep -oE "[0-9]+" || echo 0)"
	total=$((total + n))
done
echo ""
[ $status -eq 0 ] && echo "ALL PASSED ($total tests across ${#projects[@]} projects)" || echo "TESTS FAILED" >&2
exit $status
