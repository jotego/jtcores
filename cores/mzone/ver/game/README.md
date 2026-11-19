# Mega Zone simulation

Load the repository environment with `source setprj.sh`. ROMs must already exist
as `$ROM/<setname>.rom`; the default set is `megazone`.

```sh
./sim.sh -video 2 -w
./sim.sh -g megazoneh -video 2 -w
./sim.sh -s 989
```

The launcher runs in `ver/<setname>` and passes scene options to standard
`jtsim`. It generates `dump2bin.sh` from `cfg/mem.yaml` before starting, including
on the first scene run. `--scene` is an alias for `-s`.

For direct invocation, generate the memory configuration once, then run:

```sh
jtframe mem mzone --target mist
cd ../megazone
jtsim -mist -skipROM -load -s 989
```

`jtsim -s` requires `JOTEGO` to point to the support-files directory. Put captures
in `$JOTEGO/scenes/mzone/<setname>/<scene>/dump.bin`. JTFRAME links that set's
scene directory into the simulation folder, splits the dump into RAM images and
`rest.bin`, and selects `NOMAIN`, `NOSOUND`, `SIMSCENE`, and video capture options.
A normal run clears the split scene inputs through generated `dump2bin.sh`.

## Scene format

All CPU-visible video RAM and shared RAM are declared in `cfg/mem.yaml`.
The dump follows its `ioctl.order`; video registers follow in the compact
`cfg/mmr.yaml` format. All fields are bytes, with no endian conversion.

| Offset | Size | Contents | Generated input |
| --- | --- | --- | --- |
| `0x0000` | `0x400` | SCROLL tile codes | `vram0.bin` |
| `0x0400` | `0x400` | FIX tile codes | `vram1.bin` |
| `0x0800` | `0x400` | SCROLL attributes | `cram0.bin` |
| `0x0c00` | `0x400` | FIX attributes | `cram1.bin` |
| `0x1000` | `0x400` | Object RAM | `objram.bin` |
| `0x1400` | `0x800` | Main/Z80 shared RAM | `shared.bin` |
| `0x1c00` | `4` | scrolly, scrollx, flip bit 0, reserved | `rest.bin` |

Total size is 7172 bytes (`0x1c04`), matching `JTFRAME_IOCTL_RD`. The generated
MMR restores registers from `rest.bin` on reset, including with `NOMAIN`, and
handles normal CPU writes. Live dumps expose the same RAM and register layout.
Renderer DMA buffers and pixel pipelines remain internal and refill normally.

Scene captures are local support files, stored outside the repository at
`$JOTEGO/scenes/mzone/megazone/<scene>/dump.bin`. No `.bin` or `.hex` scene
fixture is committed. Once a capture is available there, run `./sim.sh -s 989`.

## Capture with MAME

The capture helpers write standard `dump.bin` directly. Write-only scroll and
flip latches are recorded through MAME write taps. MAME 0.220 uses the scroll
shares and saved LS259 latch state instead. For a new capture, place a
`scene.lua` returning a table with `frame` (and optional `initialize`/`update`
callbacks) in the destination directory:

```sh
mkdir -p "$JOTEGO/scenes/mzone/megazone/989"
cp scenes/989/scene.lua "$JOTEGO/scenes/mzone/megazone/989/"
bash scenes/capture.sh "$JOTEGO/scenes/mzone/megazone/989"
```

Capture requires MAME and its ROMs. Override the executable with `MZONE_MAME`
and ROM directory with `MZONE_MAME_ROMS`. `sim.sh` does not start MAME or assemble
ROMs. To assemble missing ROMs, run `jtframe mra mzone --path ~/.mame/roms -v`.
Legacy `save.mame` files capture separate regions and are only investigation
helpers; use `capture.sh` for complete standard scenes.

Generated frames, waveforms, split RAM files, and build output live in
`ver/<setname>`. A video run clears previous frames. `frame_viewer.py` can display
saved frames and requires Python PyGObject/GTK 3. The first captured frame can
be black during ROM loading/reset; inspect the last generated PNG for the
restored scene. A scene replay is static because the main CPU is disabled.

Run the automated checks with `simunit.sh` from the repository root:

```sh
simunit.sh --run cores/mzone/ver/scene_restore
simunit.sh --run cores/mzone/ver/video_width
```

These checks generate their own fixtures and never invoke MAME. To use an
external capture, set `MZONE_SCENE_DUMP` to its absolute path. See [the unit simulation guide](../README.md) for coverage.
