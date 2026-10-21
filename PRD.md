# PRD — GodotGo

> Product requirements for [`bamr87/godotgo`](https://github.com/bamr87/godotgo).
> Derived from the README, agent docs, config and code in this repo. Anything not
> stated in those sources is marked **TBD**; success metrics are proposals.

## 1. Overview / problem

A Godot 4 game workspace: one reusable framework addon (`addons/godotgo`) symlinked into every game, five sample games that exercise it, project-aware tooling that verifies/tests/runs/exports every game identically, and a Claude Code integration that can build, test and improve them.

## 2. Target users

- Developers building small Godot 4 games who want a shared framework and tooling
- AI agents (Claude Code) improving games in a verifiable loop

## 3. Goals and non-goals

**Goals**

- Keep one framework shared across all games
- Make verification (`tools/verify.sh`) deterministic across host, Docker and CI with a pinned Godot (4.7.2)
- Scaffold new games that pass verification on creation

**Non-goals**

- Hand-drawn art (placeholder assets are generated)
- Making the optional Godot AI editor bridge a build input

## 4. Core features (current)

- Framework addon with zero-dependency test runner
- Sample games: orb-run, leap, swarm, shift, cascade
- Tools: install_godot, verify, run, export, new_game
- Generated placeholder sprites/sounds/meshes (`tools/gen_assets.py`) checked in CI
- Docker image and CI verifying every project in parallel
- Claude Code settings, hooks, subagents and skills

## 5. Requirements

**Functional**

- `tools/verify.sh` checks engine-version pins, tests and smoke-boots every project
- `tools/new_game.sh` returns only verified scaffolds
- CI fails if regenerated assets differ from committed ones

**Non-functional**

- Engine version pinned in one place (`tools/lib.sh`)
- Commit `.gd.uid` and `.import` sidecars; never `.godot/`
- Scheduled improve agent gated by `vars.CLAUDE_IMPROVE_ENABLED`

## 6. Success metrics (proposed — not defined in sources)

- verify pass rate per project
- Time to scaffold a verified new game
- Games shipped/exported: TBD

## 7. Roadmap / open questions

- Export/distribution targets: TBD

## 8. Links

- [README.md](README.md) · [AGENTS.md](AGENTS.md) · [CLAUDE.md](CLAUDE.md) · [CHANGELOG.md](CHANGELOG.md) · [docs/framework.md](docs/framework.md) · [docs/verification.md](docs/verification.md)
