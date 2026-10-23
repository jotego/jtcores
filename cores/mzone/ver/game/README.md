# Mega Zone simulation files

Run the commands below from this directory after loading the jtcores environment
with `source setprj.sh` from the repository root. Simulation requires the usual
JTFRAME/Verilator tools and an assembled ROM in `$ROM`.

## Launchers

- `sim.sh`: normal game simulation and loading existing scenes. `-g` selects
  a ROM set (default `megazone`); `-s` or `--scene` selects `scenes/<name>/`.

```sh
# Normal game: two frames, sound enabled, waveform output.
./sim.sh -video 2 -w

# Another existing ROM set in $ROM.
./sim.sh -g megazoneh -video 2 -w

# Existing scene: two frames, zoom and waveforms; main CPU and sound disabled.
./sim.sh -s 989
```

`sim.sh` does not assemble ROMs. Generate them when missing or after changing
ROM packing rules:

```sh
jtframe mra mzone --path ~/.mame/roms -v
```

## Scene files

Each scene directory contains the following captured data:

| File | Contents |
| --- | --- |
| `vram0.bin`, `cram0.bin` | SCROLL tile codes and attributes |
| `vram1.bin`, `cram1.bin` | FIX tile codes and attributes |
| `obj.bin` | Object RAM |
| `shared.bin` | Shared CPU RAM |
| `regs.hex` | Scene scroll and flip register values |

The launcher checks that all seven files exist and are nonempty before copying
them here. It also copies `shared.bin` to `main_shared.bin` for simulation.

`scenes/capture.sh` and `scenes/capture.lua` create captures using MAME. A scene's
`scene.lua` supplies its capture configuration. For example:

```sh
bash scenes/capture.sh scenes/989
./sim.sh -s 989
```

Capture requires MAME and its ROMs. The new launcher reports missing captures;
it does not start MAME automatically. `save.mame` contains debugger commands
for manually exporting RAM; it does not produce the complete seven-file scene
by itself.

## Other helpers

| File | Purpose |
| --- | --- |
| `frame_viewer.py` | GTK image viewer with automatic reload, zoom, pan, and pixel-coordinate display; requires Python PyGObject/GTK 3 |
| `vcd_cpu_summary.py` | Extracts selected CPU and memory activity from a VCD waveform |
| `make_intmain_test_rom.py` | Builds a diagnostic ROM with a replacement sound-CPU program |
| `make_picorom_6h_test.py` | Builds a main-CPU test image for socket 6H and a simulation ROM |
| `mame_scroll_regs.mame` | MAME debugger commands for scroll-register investigation |
| `dump2bin.sh` | Generic dump helper; currently copies the input to `rest.bin` and optionally calls `rest2bin.sh`. It is not used by `sim.sh` scene loading |
| `hdmi_border_sim.sh`, `hdmi_border_tb.sv`, `hdmi_border.md` | Separate HDMI-border regression and its notes |

For example, inspect a generated image with:

```sh
python3 frame_viewer.py frames/frame_00001.png
```

Use the actual generated filename if it differs.

## Generated output and development notes

- `frames/`: images and frame checksums. A new video simulation clears previous
  frames; copy images elsewhere if they need to be preserved. `sim.sh` does not
  automatically open an image viewer or save a reference image in the scene.
- `test.vcd` or `test.fst`: waveform output, depending on the available tools.
- `rom.bin`, `sdram_bank*.bin`, copied scene files, `obj_dir/`, generated HDL,
  logs, and audio files: simulation inputs and build/run artifacts.
- `results/`, `snapshots/`, `current.md`, and `RESUME_MZONE_OBJ.md`: development
  captures, archives, and historical working notes, rather than required inputs
  for a normal simulation.

See [../README.md](../README.md) for the broader PCB-test workflow.
