#!/usr/bin/env bash
# Drive Claude Code non-interactively against any project in this workspace.
#
# Every subcommand ends by running the framework's own verification
# (tools/verify.sh), so Claude's work is judged by the same gate CI uses. The
# fix and build loops re-feed failures to Claude until the gate is green or the
# attempt budget runs out.
#
# Usage:
#   tools/claude.sh fix <project> [--attempts N]
#       Make tools/verify.sh green again.
#   tools/claude.sh build <project> "<what to build>" [--attempts N]
#       Implement a change, then verify it.
#   tools/claude.sh improve <project> [--focus "area"] [--attempts N]
#       Pick one worthwhile improvement, make it, verify it.
#   tools/claude.sh review <project>
#       Read-only review. Writes nothing.
#   tools/claude.sh new <slug> "<game concept>" [--attempts N]
#       Scaffold a new game and build the concept in it.
#
# Options:
#   --attempts N     verify/repair rounds before giving up (default 3)
#   --budget USD     spend ceiling passed to Claude (default 10)
#   --model NAME     model override
#   --dry-run        print the prompt and the command, run nothing
#   --yes            skip the confirmation prompt
#
# Authentication:
#   export CLAUDE_CODE_OAUTH_TOKEN=...   # from `claude setup-token`, Pro/Max/Team/Enterprise
#   An interactive `claude` login on this machine also works.
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$GODOTGO_ROOT"

ATTEMPTS=3
BUDGET=10
MODEL=""
DRY_RUN=0
ASSUME_YES=0
FOCUS=""

die() { echo "claude.sh: $*" >&2; exit 2; }

usage() { sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2; }

# ---------------------------------------------------------------- arguments --
cmd="${1:-}"; shift || usage
positional=()
while [ $# -gt 0 ]; do
	case "$1" in
		--attempts) ATTEMPTS="$2"; shift 2 ;;
		--budget) BUDGET="$2"; shift 2 ;;
		--model) MODEL="$2"; shift 2 ;;
		--focus) FOCUS="$2"; shift 2 ;;
		--dry-run) DRY_RUN=1; shift ;;
		--yes|-y) ASSUME_YES=1; shift ;;
		-h|--help) usage ;;
		*) positional+=("$1"); shift ;;
	esac
done
set -- ${positional[@]+"${positional[@]}"}

command -v claude >/dev/null 2>&1 || die "the 'claude' CLI is not on PATH (see https://code.claude.com/docs)"
if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
	echo "claude.sh: no CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY set." >&2
	echo "           Falling back to this machine's interactive Claude login." >&2
	echo "           For CI, run 'claude setup-token' and set CLAUDE_CODE_OAUTH_TOKEN." >&2
fi

# ------------------------------------------------------------------ prompts --
# Shared contract appended to every run's system prompt.
brief() {
	cat <<BRIEF
You are working in the GodotGo workspace, a Godot 4.7 game-building framework.

Layout: the repository root is NOT a Godot project. Each project is a directory
containing project.godot: framework/ (the shared addon plus its own tests) and
games/<slug>/. Every game symlinks addons/godotgo to framework/addons/godotgo.

Rules:
- Gameplay rules belong in the game's scripts/game.gd, a subclass of the
  framework Session. Scenes wire themselves to it and react to its signals, so
  rules stay testable without a display.
- Reuse the framework instead of reimplementing: Session, SaveSystem, ObjectPool,
  StateMachine, Rng, TextGrid, DebugOverlay, and the GodotGoTest base class.
- Do not edit framework/ to make one game easier. If the framework genuinely
  needs a change, make it deliberately and update framework/tests/unit/ too.
- GDScript: tabs, static typing, ## doc comments on public members, &"name" for
  actions and signals, ^"Path" for node paths, @export_range for tunables.
- Never invent a uid:// value. Generate one with
  tools/godot.sh --headless --path <project> --script res://addons/godotgo/tools/new_uid.gd
- Verify with tools/check.sh, tools/test.sh and tools/smoke.sh (or tools/verify.sh).
  Do not claim success until they pass. CLAUDE.md has the full detail.
BRIEF
}

# Tools Claude may use. Bash is restricted to this workspace's own scripts so an
# unattended run cannot reach for arbitrary commands.
ALLOWED_WRITE='Read,Glob,Grep,Edit,Write,MultiEdit,Bash(tools/check.sh*),Bash(tools/test.sh*),Bash(tools/smoke.sh*),Bash(tools/verify.sh*),Bash(tools/godot.sh --headless*),Bash(tools/new_game.sh*),Bash(python3 tools/gen_assets.py*),Bash(git status*),Bash(git diff*)'
ALLOWED_READ='Read,Glob,Grep,Bash(tools/check.sh*),Bash(tools/test.sh*),Bash(tools/smoke.sh*),Bash(tools/verify.sh*),Bash(git status*),Bash(git diff*),Bash(git log*)'

run_claude() {
	local prompt="$1" allowed="$2" mode="$3"
	local args=(--print --permission-mode "$mode" --allowedTools "$allowed" --max-budget-usd "$BUDGET")
	[ -n "$MODEL" ] && args+=(--model "$MODEL")
	args+=(--append-system-prompt "$(brief)")
	if [ "$DRY_RUN" = "1" ]; then
		echo "--- would run: claude ${args[*]}"
		echo "--- prompt:"; echo "$prompt"
		return 0
	fi
	printf '%s' "$prompt" | claude "${args[@]}"
}

confirm() {
	[ "$ASSUME_YES" = "1" ] && return 0
	[ "$DRY_RUN" = "1" ] && return 0
	if [ ! -t 0 ]; then
		die "not a terminal; pass --yes to run unattended"
	fi
	read -r -p "$1 [y/N] " reply
	[[ "$reply" =~ ^[Yy] ]] || die "cancelled"
}

# Runs verify, capturing output. Returns verify's exit status.
verify_into() {
	local proj="$1" out_file="$2"
	tools/verify.sh "$proj" >"$out_file" 2>&1
}

# The repair loop shared by fix, build, improve and new.
repair_loop() {
	local proj="$1" first_prompt="$2"
	local log; log="$(mktemp)"
	local attempt=1

	echo "### claude: $cmd $proj (up to $ATTEMPTS attempts, budget \$$BUDGET)"
	run_claude "$first_prompt" "$ALLOWED_WRITE" acceptEdits || die "claude exited non-zero"
	[ "$DRY_RUN" = "1" ] && return 0

	while true; do
		echo ""
		echo "### verify (attempt $attempt/$ATTEMPTS)"
		if verify_into "$proj" "$log"; then
			tail -5 "$log"
			echo ""
			echo "### VERIFY OK after $attempt attempt(s)"
			rm -f "$log"
			return 0
		fi
		tail -40 "$log"
		if [ "$attempt" -ge "$ATTEMPTS" ]; then
			echo ""
			echo "### still failing after $ATTEMPTS attempt(s); leaving the working tree as is" >&2
			rm -f "$log"
			return 1
		fi
		attempt=$((attempt + 1))
		echo ""
		echo "### claude: repairing"
		run_claude "$(printf 'The verification gate for project %s is failing. Fix the cause, not the symptom, then stop.\n\nOutput of tools/verify.sh %s:\n\n%s\n' \
			"$proj" "$proj" "$(cat "$log")")" "$ALLOWED_WRITE" acceptEdits || die "claude exited non-zero"
	done
}

# ----------------------------------------------------------------- commands --
case "$cmd" in
	fix)
		proj="$(godotgo_resolve "${1:-}")" || exit 2
		confirm "Let Claude edit $proj until tools/verify.sh passes?"
		log="$(mktemp)"
		if verify_into "$proj" "$log"; then
			cat "$log"; echo "### nothing to fix"; rm -f "$log"; exit 0
		fi
		prompt="$(printf 'Project %s fails its verification gate. Diagnose and fix the underlying cause, then stop.\n\nOutput of tools/verify.sh %s:\n\n%s\n' \
			"$proj" "$proj" "$(cat "$log")")"
		rm -f "$log"
		repair_loop "$proj" "$prompt"
		;;

	build)
		proj="$(godotgo_resolve "${1:-}")" || exit 2
		goal="${2:-}"
		[ -z "$goal" ] && die 'build needs a description: tools/claude.sh build <project> "add a double jump"'
		confirm "Let Claude implement in $proj: $goal?"
		repair_loop "$proj" "$(printf 'In the Godot project %s, implement the following, with tests:\n\n%s\n\nFollow the workspace conventions, extend the framework rather than duplicating it, and finish by making tools/verify.sh %s pass.\n' \
			"$proj" "$goal" "$proj")"
		;;

	improve)
		proj="$(godotgo_resolve "${1:-}")" || exit 2
		area="${FOCUS:-anything that measurably improves the game or its tests}"
		confirm "Let Claude pick and apply one improvement to $proj?"
		repair_loop "$proj" "$(printf 'Review the Godot project %s and choose ONE worthwhile improvement in this area: %s.\n\nPrefer a change that makes the game better to play, the code clearer, or the tests more honest. State what you chose and why in one short paragraph before you start, make just that change with tests, and finish by making tools/verify.sh %s pass. Do not make sweeping unrelated edits.\n' \
			"$proj" "$area" "$proj")"
		;;

	review)
		proj="$(godotgo_resolve "${1:-}")" || exit 2
		run_claude "$(printf 'Review the Godot project %s. Run tools/verify.sh %s first. Report findings most severe first with file:line references: runtime correctness, scene and resource integrity, Godot 4 idioms, performance, and whether the tests actually prove what they claim. Do not edit anything; end with a one-line verdict.\n' \
			"$proj" "$proj")" "$ALLOWED_READ" dontAsk
		;;

	new)
		slug="${1:-}"
		concept="${2:-}"
		[ -z "$slug" ] || [ -z "$concept" ] && die 'new needs a slug and a concept: tools/claude.sh new dodge "endless obstacle dodger"'
		[ -e "games/$slug" ] && die "games/$slug already exists"
		confirm "Scaffold games/$slug and let Claude build: $concept?"
		if [ "$DRY_RUN" != "1" ]; then
			tools/new_game.sh "$slug" --desc "$concept" || die "scaffolding failed"
		fi
		repair_loop "games/$slug" "$(printf 'The project games/%s was just scaffolded from templates/blank and currently contains placeholder gameplay. Replace it with this game:\n\n%s\n\nKeep the shape the template establishes: rules in scripts/game.gd as a Session subclass, scenes wired to its signals, a HUD driven by them, and a real test suite under tests/unit/. Generated placeholder art belongs in tools/gen_assets.py; if you need art, say so rather than committing binaries by hand. Finish by making tools/verify.sh games/%s pass.\n' \
			"$slug" "$concept" "$slug")"
		;;

	*) usage ;;
esac
