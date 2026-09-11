# Starter PBR

`starter_pbr.ptex` is the Material Maker graph (a copy of Material Maker's `rock` example). Re-export it with:

```bash
tools/mm.sh games/orb-run/materials/starter/starter_pbr.ptex
tools/check.sh orb-run
```

Files after export (Material Maker 1.7, "Godot/Godot 4 Standard" target, 2048x2048):

- `starter_pbr.tres` (StandardMaterial3D referencing the PNGs)
- `starter_pbr_albedo.png`
- `starter_pbr_orm.png` (AO = R, roughness = G, metallic = B)
- `starter_pbr_normal.png`
- `starter_pbr_heightmap.png`, `starter_pbr_emission.png` when the graph connects them

Material Maker never overwrites an existing `.tres` (so hand edits survive); delete it before re-exporting if you want it regenerated. The `.tres` it writes is Godot 3 text format with relative texture paths; Godot 4.7 loads it as-is and the editor upgrades it on save.

See `docs/material-maker.md`.
