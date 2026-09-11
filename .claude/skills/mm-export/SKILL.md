---
name: mm-export
description: Export a Material Maker .ptex graph into a game's materials/ folder as a Godot StandardMaterial3D plus PNG maps, using Docker. Use when asked to export, bake or regenerate a material, or when a .ptex changed.
allowed-tools: Bash(tools/mm.sh*) Bash(tools/check.sh*) Bash(tools/docker.sh*)
arguments: [ptex, output-dir]
---

```bash
tools/mm.sh games/orb-run/materials/metal/metal.ptex
tools/check.sh orb-run          # let Godot import the new PNGs
```

The first run builds `godotgo-material-maker:local` from source for the host CPU, which downloads the Godot export templates (about 1.3 GB) and takes several minutes. A 2048 px export then takes roughly two minutes.

The image bakes the engine in, so an engine bump in `tools/lib.sh` reaches it only after `tools/docker.sh mm-build`.

Facts about Material Maker 1.7's CLI that matter:

- `--export-material` must be the first argument and the output directory must already exist. The wrapper handles both.
- Textures are always 2048x2048; the CLI parses `--size` but ignores it.
- Only `.ptex` files export from the command line. Targets: `Godot/Godot 4 Standard` (the default, writing `<name>_albedo/_orm/_normal/_emission/_heightmap.png`), `Godot/Godot 4 ORM`, `Blender`, `Unity/*`, `Unreal/*`. Set `MM_TARGET` to change.
- The ORM PNG packs ambient occlusion in red, roughness in green and metallic in blue. The framework's `MaterialMakerLoader` understands it, and the exported `.tres` references it directly.
- An existing `<name>.tres` is never overwritten, so re-exports refresh only the PNGs. Delete the `.tres` first when the graph's outputs changed.
- Material Maker may crash or hang while quitting after a successful export. The wrapper bounds the run with `MM_TIMEOUT` (default 900 s) and judges success by whether fresh files appeared, not by the exit code.
- The image deliberately runs a Godot *debug* export of Material Maker: the optimized release build segfaults while loading node definitions under Xvfb with software Vulkan.
