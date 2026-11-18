<!-- kit: governance v0.1.0 -->
# 0002 — Missions

- **Status:** proposed
- **Date:** 2026-11-16
- **Proposed by:** Grok Bot (agent), at the maintainer's request
- **Ratified by:**
- **Affects:** constitution §1; PRD.md §1.1; GODOTGO-008
- **Supersedes:** none
- **Related:** [PRD.md](../../PRD.md) §1.1

## Context

Constitution §1 was a single mission sentence or short paragraph, not one direction statement with exactly three numbered missions. The fleet rule is that every repo's constitution §1 uses that form, adopted through a numbered amendment the maintainer ratifies by merging. Mission 1 is the maintainer's own wording, adapted to this repo: provide data, tools, resources and transparency for all stakeholders, practitioners in the domain, and the general public. The ambition is the direction, not a claim that the work is already finished.

The earlier §1 text was:

> A Godot 4 game workspace: one reusable framework addon (`addons/godotgo`) symlinked into every game, five sample games that exercise it, project-aware tooling that verifies/tests/runs/exports every game identically, and a Claude Code integration that can build, test and improve them.

## Amendment

Retitle constitution §1 **Missions**. Replace the body of §1 with the following. Any invariants or other normative rules that already lived outside §1 are unchanged.

GodotGo's direction is to become the ultimate open home for all things Godot game-making — data, tools, resources and transparency, gathered in one place that anyone can inspect and reuse.

1. **Provide data, tools, resources and transparency for all stakeholders, game developers, Godot practitioners and the general public.** Developers building Godot 4 games, AI agents working in a verifiable loop, and the general public are first-class audiences. The aim is a shared, open commons: the same framework, the same tools, and the same trail of evidence for everyone.
2. **Make every Godot 4 project share one reusable framework and the same verifiable path to build, test, run and export.** The `addons/godotgo` framework, pin-able tooling, and sample games that exercise it are the starting point; verification stays deterministic across host, Docker and CI.
3. **Put that workspace in every developer's and agent's hands, and make improving a game a loop anyone can run.** Serve it through project-aware tooling and a Claude Code integration that can build, test and improve every game the same way — an open toolkit for working with all things Godot game-making.

These missions set the course; they do not claim the work is finished. They serve the PRD goals in §3: one shared framework and deterministic verification. The earlier mission paragraph is absorbed into these three. Every feature must trace to them.

_Source: [../PRD.md](../PRD.md) §1.1._

## Consequences

Agents and reviewers judge fit against these three missions before inventing scope, treating them as the direction of the repo rather than a description of what already ships. The same text is added as PRD.md §1.1 so the constitution's `_Source:` line stays accurate. The PRD purpose, goals, feature catalog and invariants outside this addition are unchanged except for a new catalog entry (GODOTGO-008) and a regenerated feature-catalog block where the repo already has one. This PR also aligns the README and AGENTS.md one-liners with the missions and links them to constitution §1.
