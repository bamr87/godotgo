# Material Maker workflow

Material Maker is a Godot-based procedural texture and material authoring tool. This project expects Godot 4 exports dropped into `games/<slug>/materials/<name>/`.

## Install

- itch.io or Steam: Material Maker
- macOS Homebrew: `brew install material-maker`

## Export from the command line (Docker, no install)

```bash
tools/mm.sh games/orb-run/materials/starter/starter_pbr.ptex
tools/check.sh orb-run          # let Godot import the PNGs
```

`tools/mm.sh` runs Material Maker 1.7 inside a container under Xvfb with Mesa's lavapipe Vulkan driver, because texture generation needs a rendering device. `docker/Dockerfile.material-maker-src` (the default) builds Material Maker from source for the host CPU with the workspace's pinned Godot editor, so it is native on Apple Silicon as well as x86_64; the first build downloads the Godot export templates (about 1.3 GB). It is deliberately a Godot debug export: the optimized release build segfaults while loading node definitions in this software-rendered environment (on both architectures), the debug build does not. `docker/Dockerfile.material-maker` is an alternative that installs the upstream x86_64 release (amd64 hosts only; select it with `MM_DOCKERFILE=docker/Dockerfile.material-maker`).

The image is built the first time `tools/mm.sh` needs it. Because it embeds the engine rather than resolving it at run time, bumping `GODOTGO_GODOT_VERSION` in `tools/lib.sh` only reaches Material Maker once the image is rebuilt: `tools/docker.sh mm-build`.

Output textures are 2048x2048 (the CLI ignores `--size`). An existing `.tres` is never overwritten, only the PNGs are refreshed. Commit the `.ptex` next to its export so the graph and the baked maps travel together; a full export is roughly 5 MB of PNGs, so consider Git LFS if materials multiply.

## Export from the GUI into GodotGo

1. Author a material graph in Material Maker.
2. Use **Export** and pick the **Godot** target.
3. Set the output directory to this repo, for example `materials/starter/`.
4. Material Maker writes PNG maps (correct normal-map format) plus a `.tres` Spatial/StandardMaterial3D.
5. Open GodotGo in Godot so the importer generates `.import` files.
6. Assign the `.tres` on a `MeshInstance3D`, or call `MaterialMakerLoader.load_material("res://materials/starter", "starter_pbr")`.

## Map names

Keep one folder per material. Prefer:

| Map | Typical file |
| --- | --- |
| Albedo | `name_albedo.png` |
| Normal | `name_normal.png` |
| Roughness | `name_roughness.png` |
| Metallic | `name_metallic.png` |
| Ambient occlusion | `name_ao.png` |
| Emission | `name_emission.png` |
| Height | `name_heightmap.png` (or `name_height.png`) |
| Packed ORM | `name_orm.png` (AO = R, roughness = G, metallic = B) |

If the `.tres` is missing, the framework's `MaterialMakerLoader` builds a `StandardMaterial3D` from those maps, splitting a packed ORM across the AO, roughness and metallic channels.

## Notes

- Do not vendor Material Maker itself in this repo.
- Commit exported PNG + `.tres` files you actually use in scenes.
- Leave `.godot/` untracked; Godot regenerates the import cache.
