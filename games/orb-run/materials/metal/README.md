# Metal

> The Material Maker `metal_pattern` graph that textures orb-run's platforms, and how to re-export it.

`metal.ptex` is Material Maker's `metal_pattern` example. It textures the platforms in `scenes/main.tscn`.

Re-export (PNGs only; the `.tres` is kept):

```bash
tools/mm.sh games/orb-run/materials/metal/metal.ptex && tools/check.sh orb-run
```
