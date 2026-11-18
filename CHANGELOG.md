# Changelog

## [0.3.0](https://github.com/bamr87/godotgo/compare/v0.2.0...v0.3.0) (2026-11-18)


### Added

* **cascade:** pay a near-clear bonus for won boards with few tiles left ([d4b1d4b](https://github.com/bamr87/godotgo/commit/d4b1d4bc346d95bf298767f1af36465d83bedf16))
* **cascade:** pay a near-clear bonus for won boards with few tiles left ([f3e0b31](https://github.com/bamr87/godotgo/commit/f3e0b31ce37ace42539859e9622146a8922a91a6))


### Fixed

* **tools:** answer --help, exit 2 on bad options, and fix export.sh output paths ([1fcda27](https://github.com/bamr87/godotgo/commit/1fcda2763d87d4cd373b9c090625ce68acd0bb97))
* **tools:** answer -h/--help and fail fast on bad options in every tool ([6f71a2d](https://github.com/bamr87/godotgo/commit/6f71a2d4cbaa2f6803d820ea757f1530aeb75516))
* **tools:** export.sh writes and checks one output path, shows a failed import ([ae49e53](https://github.com/bamr87/godotgo/commit/ae49e53fe22d260fca6ea3073beacc92c17bff6d)), closes [#25](https://github.com/bamr87/godotgo/issues/25)
* **tools:** run.sh passes --help after the project to Godot ([5c10677](https://github.com/bamr87/godotgo/commit/5c10677dc752365a71a2d098a54353fb3fd6f177))


### Documentation

* **agents:** merge the two tests/ rows ([de8a3eb](https://github.com/bamr87/godotgo/commit/de8a3eb3460915ffc120d1a79dab7a8d08c499a7))
* **constitution:** state the missions in §1 (amendment 0002) ([1249b00](https://github.com/bamr87/godotgo/commit/1249b008f062b9dff9d15392bdf3f6026d07332a))
* **constitution:** state the missions in §1 (amendment 0002) ([50d511e](https://github.com/bamr87/godotgo/commit/50d511e310b3893b31044ef81b1cd879ed79d156))
* list markdown-oneline.yml in AGENTS.md and install pre-commit in a venv ([9c121b6](https://github.com/bamr87/godotgo/commit/9c121b60343410282b11fd0f70f22b563a519f43))
* **tools:** scope the command-line contract to the shell scripts ([8f647e2](https://github.com/bamr87/godotgo/commit/8f647e2add810777fbfbc7f75bf5ef41d53484fe)), closes [#24](https://github.com/bamr87/godotgo/issues/24)

## [0.2.0](https://github.com/bamr87/godotgo/compare/v0.1.0...v0.2.0) (2026-10-31)


### Added

* **docs:** generate the framework API reference from doc comments ([bea3d16](https://github.com/bamr87/godotgo/commit/bea3d16553bf76e2d8dd1bdf849e5d782ce92b92))


### Fixed

* **ci:** skip Claude Code Review when no credential is present ([0304329](https://github.com/bamr87/godotgo/commit/0304329d838e41cc7209c304bb2ae7df7c407ae5))
* **ci:** skip Claude Code Review when no credential is present ([4280693](https://github.com/bamr87/godotgo/commit/42806934aa68374758e2a66f64d6d995a7650570))
* **release:** skip release-please when it has no credential to open the PR ([21add02](https://github.com/bamr87/godotgo/commit/21add02e0783327296e74efa9edbc03bc89406fc))
* **release:** skip release-please when it has no credential to open the PR ([e89c199](https://github.com/bamr87/godotgo/commit/e89c1990a4418476909ca4aef838c81b5573990f))
* **tools:** re-vendor docs_index.py with multi-line comment stripping ([a36d0c3](https://github.com/bamr87/godotgo/commit/a36d0c3625c83a06b34ba09b6636c74738e32291))


### Documentation

* add feature catalog, constitution and amendments; link PRD ([#9](https://github.com/bamr87/godotgo/issues/9)) ([9e02a0d](https://github.com/bamr87/godotgo/commit/9e02a0d1867ac2da81de834b469e5b196d3cae39))
* add fleet SECURITY.md, issue forms and hub .editorconfig ([36107b0](https://github.com/bamr87/godotgo/commit/36107b0f75455f101db9140cc10581c67b0f6f0b))
* add fleet SECURITY.md, issue forms and hub .editorconfig ([8f75519](https://github.com/bamr87/godotgo/commit/8f755198287773b2a7c1a302b8e885c9322be174))
* add PRD.md ([#8](https://github.com/bamr87/godotgo/issues/8)) ([dc9ae9d](https://github.com/bamr87/godotgo/commit/dc9ae9dd5236776c22093517b8b74498d1175998))
* add summary lines and generate the docs index ([a4b5d75](https://github.com/bamr87/godotgo/commit/a4b5d758e5212a37247496d78bc4488bfe68297e))
* **agents:** fold AGENTS.md into the six fleet headings ([16de328](https://github.com/bamr87/godotgo/commit/16de32811d83373a255f6d0071d5ec22c8444100))
* **changelog:** add CHANGELOG.md in Keep a Changelog format ([#4](https://github.com/bamr87/godotgo/issues/4)) ([d734a2d](https://github.com/bamr87/godotgo/commit/d734a2dcab68384a3f2edff389f2cb14c4499377))
* harmonize documentation to the fleet docs framework ([fad200b](https://github.com/bamr87/godotgo/commit/fad200bc7972a9d73e7b5cc8feee23e38b0e726c))
* **readme:** align README with the portfolio standard ([#3](https://github.com/bamr87/godotgo/issues/3)) ([51d8191](https://github.com/bamr87/godotgo/commit/51d8191fb9282b21b29e80f597d3442069710660))
* **readme:** follow the portfolio skeleton ([6c6c795](https://github.com/bamr87/godotgo/commit/6c6c79585b1636f6824c0aa0248607266943b546))
* **roadmap:** plan PerfectPixel Studio sprite-sheet integration (GODOTGO-007, FR4) ([2b84e5f](https://github.com/bamr87/godotgo/commit/2b84e5fba3f89de8dd0f6dc6e8bef8455db58997))
* **roadmap:** plan PerfectPixel Studio sprite-sheet integration (GODOTGO-007, FR4) ([329e9ec](https://github.com/bamr87/godotgo/commit/329e9ec4f671d04ff3f759efded926cbb1792e19))

## Changelog

All notable changes to this project are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

### Added

- `CHANGELOG.md`, in Keep a Changelog format.

## History

No versions have been tagged yet. The project started on 2026-09-11 and has 5 commits on `main`. The most recent changes:

- 2026-10-17: docs(readme): align README with the portfolio standard ([#3](https://github.com/bamr87/godotgo/pull/3))
- 2026-10-14: ci: stagger AI cron schedule (bamr87/bamr87#348) ([#2](https://github.com/bamr87/godotgo/pull/2))
- 2026-10-07: Add Cascade, a collapse-puzzle sample game ([#1](https://github.com/bamr87/godotgo/pull/1))
- 2026-09-11: Initial commit: GodotGo workspace

The full record is in the [commit history](https://github.com/bamr87/godotgo/commits/main) and the [merged pull requests](https://github.com/bamr87/godotgo/pulls?q=is%3Apr+is%3Amerged).
