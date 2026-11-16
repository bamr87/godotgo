#!/usr/bin/env bash
# The command-line contract of tools/*.sh, checked without Godot or Docker:
#   - every tool answers -h/--help with its usage on stdout and exit 0, before
#     it downloads anything, writes anything or starts Godot or Docker;
#   - an unknown option, or an option missing its value, is a usage error:
#     exit 2 with the reason on stderr, never a hang and never real work.
#
# Usage: tests/test_cli.sh
#
# The tools run from a scratch copy of tools/ beside two empty projects, with
# stand-ins for the engine, docker, curl and claude that record every call, so
# nothing real is launched, fetched or written. Every run sits under a 5 s
# watchdog (perl's alarm, because macOS has no `timeout`), so a parser that
# loops forever fails here in seconds. tools/verify.sh runs this in its pins
# stage. It must pass under macOS's bash 3.2 as well as bash 5.
set -o pipefail

command -v perl >/dev/null 2>&1 || { echo "tests/test_cli.sh needs perl for its watchdog" >&2; exit 1; }

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/godotgo-cli.XXXXXX")" || exit 1
trap 'rm -rf "$scratch"' EXIT

ws="$scratch/ws"       # the workspace the tools run in
stubs="$scratch/bin"   # first on PATH, and GODOT_BIN
export STUB_CALLS="$scratch/calls"   # one line per stand-in call

mkdir -p "$ws" "$stubs"
cp -R "$root/tools" "$ws/tools"
mkdir -p "$ws/framework" "$ws/games/leap/tests/unit" "$ws/templates/blank"
: >"$ws/framework/project.godot"
: >"$ws/games/leap/project.godot"
: >"$ws/games/leap/export_presets.cfg"

# Commands nothing here should reach: record the call and fail.
for name in docker curl claude uvx; do
	cat >"$stubs/$name" <<STUB
#!/bin/sh
echo "$name \$*" >>"\$STUB_CALLS"
exit 1
STUB
done

# The engine: records the call and plays just enough of Godot for the paths
# tested here. --import fails when STUB_IMPORT_FAIL=1; --export-release writes
# an executable at the path it is given, as a real export does (and fails when
# its directory does not exist); a headless boot prints the session line
# smoke.sh waits for; the test runner reports one passing test.
cat >"$stubs/godot" <<'STUB'
#!/bin/sh
echo "godot $*" >>"$STUB_CALLS"
while [ $# -gt 0 ]; do
	case "$1" in
		--import)
			if [ "${STUB_IMPORT_FAIL:-0}" = "1" ]; then
				echo "stub engine: Parse Error: Could not find type \"Missing\""
				exit 1
			fi
			exit 0 ;;
		--export-release) printf '#!/bin/sh\n' >"$3" && chmod +x "$3"; exit $? ;;
		--quit-after) echo "[godotgo] session start (stub engine)"; exit 0 ;;
		--script) case "$2" in *test_runner.gd) echo "PASSED: 1"; exit 0 ;; esac ;;
	esac
	shift
done
exit 1
STUB
chmod +x "$stubs"/*

checks=0
failures=0
last=""

# run <tool> [args ...]: tools/<tool>.sh in the scratch workspace, under the
# watchdog, with the shell running this file. Sets $rc; output lands in
# $scratch/out and $scratch/err, stand-in calls in $STUB_CALLS.
run() {
	local tool="$1"
	shift
	last="tools/$tool.sh $*"
	: >"$STUB_CALLS"
	(
		cd "$ws" || exit 1
		PATH="$stubs:$PATH" GODOT_BIN="$stubs/godot" \
			perl -e 'alarm 5; exec @ARGV; exit 127' "$BASH" "tools/$tool.sh" "$@"
	) >"$scratch/out" 2>"$scratch/err"
	rc=$?
}

fail() {
	failures=$((failures + 1))
	{
		echo "FAIL $last: $*"
		sed -n '1,8s/^/    stderr| /p' "$scratch/err"
	} >&2
}

expect_rc() {
	checks=$((checks + 1))
	[ "$rc" -eq "$1" ] && return 0
	if [ "$rc" -eq 142 ]; then
		fail "killed by the 5 s watchdog (it hung); expected exit $1"
	else
		fail "exit $rc; expected $1"
	fi
}

# expect_in out|err <text>, expect_not_in out|err <text>: fixed-string search.
expect_in() {
	checks=$((checks + 1))
	grep -qF -- "$2" "$scratch/$1" || fail "std$1 does not contain: $2"
}
expect_not_in() {
	checks=$((checks + 1))
	! grep -qF -- "$2" "$scratch/$1" || fail "std$1 contains: $2"
}
expect_empty() {
	checks=$((checks + 1))
	[ ! -s "$scratch/$1" ] || fail "std$1 is not empty: $(head -1 "$scratch/$1")"
}
expect_nothing_ran() {
	checks=$((checks + 1))
	[ ! -s "$STUB_CALLS" ] || fail "it reached: $(tr '\n' ';' <"$STUB_CALLS")"
}
expect_call() {
	checks=$((checks + 1))
	grep -qF -- "$1" "$STUB_CALLS" || fail "no call containing: $1 (calls: $(tr '\n' ';' <"$STUB_CALLS"))"
}
expect_file() {
	checks=$((checks + 1))
	[ -x "$1" ] || fail "no executable at $1"
}
expect_no_file() {
	checks=$((checks + 1))
	[ ! -e "$1" ] || fail "$1 exists"
}

# --- -h/--help: usage on stdout, exit 0, nothing started --------------------
for tool in check claude docker export godot_ai install_godot install_godot_ai mm new_game run smoke test verify; do
	header="$(sed -n '2s/^# \{0,1\}//p' "$ws/tools/$tool.sh")"
	for flag in -h --help; do
		run "$tool" "$flag"
		expect_rc 0
		expect_in out "Usage:"
		checks=$((checks + 1))
		[ "$(sed -n 1p "$scratch/out")" = "$header" ] || fail "stdout does not start with the header: $(sed -n 1p "$scratch/out")"
		expect_not_in out "set -o pipefail"
		expect_empty err
		expect_nothing_ran
	done
done
expect_no_file "$ws/.godot-bin"

# Anywhere among the arguments, for the tools that own all of them.
run verify leap --help
expect_rc 0
expect_not_in out "### pins"
run new_game dodge --title Dodge -h
expect_rc 0
expect_nothing_ran
expect_no_file "$ws/games/dodge"
# docker.sh reads only its first argument: after a command, --help is that
# command's, so it reaches the container (the docker stand-in here).
run docker verify --help
expect_call "godot tools/verify.sh --help"

# --- unknown options: exit 2 with the reason and usage, before any work ------
for tool in verify check test smoke run export install_godot; do
	run "$tool" --bogus
	expect_rc 2
	expect_in err "unknown option '--bogus'"
	expect_in err "--help"
	expect_in err "Usage:"
	expect_empty out
	expect_nothing_ran
done
run new_game dodge --bogus
expect_rc 2
expect_in err "unknown option '--bogus'"
expect_nothing_ran
run verify leap --bogus
expect_rc 2
expect_not_in out "### pins"
# test.sh used to take an unknown option for its filter and run every suite.
run test leap -v
expect_rc 2
expect_nothing_ran
expect_no_file "$ws/.godot-bin"

# --- an option missing its value: exit 2 at once, not an endless loop ---------
for flag in --title --desc --template; do
	run new_game dodge "$flag"
	expect_rc 2
	expect_in err "$flag needs a value"
	expect_nothing_ran
done
expect_no_file "$ws/games/dodge"
run smoke leap --expect
expect_rc 2
expect_in err "--expect needs a value"
expect_nothing_ran
# These must fail before claude.sh looks for the claude CLI.
for flag in --attempts --budget --model --focus; do
	run claude fix leap "$flag"
	expect_rc 2
	expect_in err "$flag needs a value"
	expect_nothing_ran
done

# --- valid invocations behave as before ---------------------------------------
run claude
expect_rc 2
expect_in err "Usage:"
run claude fix leap --dry-run
expect_rc 0
expect_in out "--- would run: claude"
expect_in out "--- prompt:"
checks=$((checks + 1))
! grep -q '^claude ' "$STUB_CALLS" || fail "--dry-run ran claude"
run smoke leap --expect 'session start'
expect_rc 0
expect_in out "smoke: OK"
run smoke leap --expect 'a line the game never prints'
expect_rc 1
run test leap player
expect_rc 0
expect_call "--filter=player"

if [ "$failures" -eq 0 ]; then
	echo "tools CLI: all $checks checks passed"
	exit 0
fi
echo "tools CLI: $failures of $checks checks failed" >&2
exit 1
