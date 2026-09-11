# Orb Run

3D first-person: collect the five orbs scattered across the arena and its platforms, then reach the exit portal before the 90-second timer runs out.

```bash
tools/run.sh orb-run        # play
tools/verify.sh orb-run     # check, test and smoke
```

Controls: **WASD** move, mouse look, **Space** jump, **Shift** sprint, **R** restart, **Esc** release the cursor.

## What it demonstrates

- **A gated exit.** Unlike Leap, the objective controls the exit: the portal is
inert until every orb is collected, which is the framework's `objective_reached` signal driving a scene.
- **The 3D character controller** in `scripts/player.gd`: coyote time, jump
buffering, sprint, and a landing speed sampled before `move_and_slide()` because the slide zeroes it.
- **The Material Maker pipeline.** `materials/starter` and `materials/metal` are
real headless exports driven by their `.ptex` graphs, loaded through the framework's `MaterialMakerLoader`, including a packed ORM map split across the ambient-occlusion, roughness and metallic channels. See [docs/material-maker.md](../../docs/material-maker.md).
- **Generated 3D assets**: the orb mesh is an OBJ written by
  `tools/gen_assets.py`, with a custom pulsing shader.
