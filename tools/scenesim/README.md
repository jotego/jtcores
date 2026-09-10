# scenesim — scene-replay regression tooling

A small triplet of cross-core scripts to:

1. **Sim** every captured "scene" of a core through the Docker verilator sim.
2. **Diff** the output against MAME ground-truth screen captures.
3. **Zoom** a slice for pixel-level inspection with a grid overlay.

Designed to be reused on any jtcores core that follows the per-core
scene-capture layout the Superman bring-up established.

## Per-core layout it expects

```
cores/<core>/ver/<setname>/scenes/<scene>/screen.png   ← MAME reference PNG
cores/<core>/ver/<setname>/scenes/<scene>/dump.bin     ← scene state for sim
cores/<core>/ver/<setname>/sim_results/<scene>.jpg     ← FPGA sim output  (created)
cores/<core>/ver/<setname>/sim_results/diffs/...       ← diff stacks        (created)
```

`<setname>` defaults to `<core>` if you don't pass it.

## Typical workflow

```bash
# (Once) capture scenes from MAME. This step is core-specific (the lua
# script knows where the core's palette/VRAM/OBJ-RAM live). See
# cores/superman/ver/superman/mame_scripts/dump_burst.lua for a template.

# 1. Sim every scene under cores/<core>/ver/<setname>/scenes/
tools/scenesim/sim_scenes.sh superman
#   (writes sim_results/<scene>.jpg + .log per scene)

# 2. Build MAME / diff / FPGA stacked PNGs (one per scene)
tools/scenesim/build_diffs.py superman
#   (writes sim_results/diffs/<scene>_compare.png)

# 3. Zoom in on a slice of one scene (pixel grid in magenta so you can
#    count pixel-perfect offsets).
tools/scenesim/zoom_slice.py superman burst_00150 \
    --x 168 --w 48 --y 0 --h 120 --zoom 9
#   (writes sim_results/<scene>_zoom_168_0_48x120_9x.png)
```

## sim_scenes.sh

Loops `sim-core.sh` (the project-root Docker driver) over every
sub-directory of `scenes/`, or over the names you pass on the command
line. Each scene gets one JPG and one LOG in `sim_results/`.

```
sim_scenes.sh <core> [setname] [scene1 scene2 ...]
```

## build_diffs.py

For every `screen.png` + matching `<scene>.jpg` pair it generates a
384×720 PNG with three frames stacked, no gap:

```
MAME      ← top
diff      ← middle: edge-XOR mask painted red over a dimmed MAME copy;
            color/tone changes don't show, only SPATIAL mismatches do.
FPGA      ← bottom
```

```
build_diffs.py <core> [setname]
```

Edge threshold and logical frame size are hardcoded near the top of
the file — adjust them for cores with a non-384×240 visible area.

## zoom_slice.py

Crops a rectangular slice from both MAME and FPGA, integer-zooms it
(default 9×), draws a 1-pixel magenta grid every original pixel so
sprite shifts can be counted, and stacks MAME-on-top / FPGA-on-bottom.

```
zoom_slice.py <core> <scene> [--x X] [--y Y] [--w W] [--h H]
                            [--zoom Z] [--setname S] [--output P]
```

Defaults: `--w 48 --h 120 --zoom 9 --y 0 --x <centered>`.

## Requirements

- Docker (the sim runs inside `jotego/simulator`)
- A working `JTROOT/sim-core.sh` driver
- Python 3 with Pillow (no numpy needed)
