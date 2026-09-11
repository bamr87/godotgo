#!/usr/bin/env bash
# The full verification pass: check, test and smoke every project (or the ones
# named). This is what CI and the Claude agents run.
#
# Usage: tools/verify.sh [project ...]
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$GODOTGO_ROOT"

echo "### pins"; godotgo_check_version_pins || exit 1
godotgo_check_project_refs || exit 1
echo "    Godot $GODOTGO_GODOT_VERSION everywhere, no dangling project references"
echo ""; echo "### check"; tools/check.sh "$@" || exit 1
echo ""; echo "### test"; tools/test.sh "$@" || exit 1
echo ""; echo "### smoke"
if [ $# -eq 0 ]; then tools/smoke.sh || exit 1; else
	for n in "$@"; do
		p="$(godotgo_resolve "$n")" || exit 2
		[ "$p" = "framework" ] && continue      # no main scene
		tools/smoke.sh "$n" || exit 1
	done
fi
echo ""; echo "VERIFY OK"
