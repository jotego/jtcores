# cninja family — MAME reference scenes and scene replay

Everything here serves ONE purpose: rendering a captured MAME video state in the
Verilator sim with the CPU removed, so video work can be graded against MAME's
own output without playing the game.

The harness covers all four boards (`cninja`, `darkseal`, `cbuster`,
`vaportra`). It lives under `ver/cninja/` because that is the family's home
game; the scenes themselves go under `ver/<setname>/`.

## Why scene replay

`jtsim -s <scene>` builds with `NOMAIN NOSOUND MAXFRAME=3 SIMSCENE`: no CPU, no
sound, three frames. Nothing writes video state, so all of it has to be restored
from the capture — palette, playfield RAM, sprite RAM, the scroll tables, and
the registers. Miss one and the picture is wrong in a way that looks like an HDL
bug. The register half is what `cfg/mmr.yaml` exists for.

## Capture

```bash
ver/cninja/mame_scripts/capture_scenes.sh <setname> [first:last:step]
```

Default cadence `300:6000:300` = 20 scenes, ~100 s of emulation. Writes
`ver/<setname>/scenes/<NNNN>/{dump.bin,screen.png}`, both taken inside the same
frame notifier so the picture always belongs to the state next to it.

`mame_scripts/dump_scene.lua` does the work and knows all four memory maps. Two
things about it are load-bearing:

- **The write-tap handles are kept in `_G.__taps`.** deco16ic control registers
  are write-only, so they are captured by tapping `pf_control_w`. A
  passthrough handler that loses its last reference is collected and silently
  removed, and then every register dumps as zero.
- **The layout is identical for every board**, with short regions zero-padded up
  to a fixed slot. That is what lets `ver/game/rest2bin.sh` be a plain list of
  offsets and the MMR `SEEK` values be constants in `jtcninja_video.v`.

```
off      size    content                          restored by
0x0000   0x0010  tilegen0 deco16ic control (LE)   jtdeco16ic_mmr SEEK=0
0x0010   0x0010  tilegen1 deco16ic control (LE)   jtdeco16ic_mmr SEEK=16
0x0020   0x0005  vprio0, vprio1 (LE), cbuster m_pri
                                                  jtframe_simdumper SEEK=32
0x0040   0x2000  palette              -> pal.bin
0x2040   0x2000  tilegen0 pf1         -> t0p1.bin
0x4040   0x2000  tilegen0 pf2         -> t0p2.bin
0x6040   0x2000  tilegen1 pf1         -> t1p1.bin
0x8040   0x2000  tilegen1 pf2         -> t1p2.bin
0xA040   0x1000  tilegen0 row/colscroll -> rs0.bin
0xB040   0x1000  tilegen1 row/colscroll -> rs1.bin
0xC040   0x0800  sprite RAM           -> oram.bin
                                                  total 0xC840 = 51264 bytes
```

RAM images keep m68k byte order (`ENDIAN(1)` on the BRAMs). The two register
blocks are little endian, because `mmr[]` and `jtframe_simdumper` are both
byte-indexed low-first. `rest2bin.sh` refuses a dump that is not 51264 bytes
rather than splitting an old layout into plausible garbage.

Scenes are **not committed** — 5 MB of binaries that this script rebuilds in
100 s per game.

## Replay and grade

```bash
export ROMS_HOST=~/mameroms
tools/scenesim/sim_scenes.sh cninja <setname>          # -> sim_results/<scene>.png
tools/scenesim/build_diffs.py  cninja <setname>        # -> sim_results/diffs/
```

No `--rot` for any of the four: MAME's snapshot is already in the screen's
orientation, vaportra included.

The board booleans come from the MRA header inside `rom.bin`, so each set
renders as itself — the old `JTFRAME_SIM_GAMEID` override is gone.

## Other scripts here

| script | purpose |
|---|---|
| `dump_checkpoints.lua` | MAME snapshots only, no state dump |
| `dump_perframe_inputs.lua`, `inp2siminputs.py` | turn a MAME `.inp` recording into sim inputs |
| `render_bg_only.lua`, `render_char_only.lua`, `render_sprites_only.lua` | blank every layer but one in MAME, to identify which plane a defect belongs to |
| `trace_main_boot.mame`, `trace_sound.lua` | CPU boot traces |

`install_write_tap` needs a unique name per tap, and the deco16ic uses MAME's
dirty-tile cache, so a render_*_only tap only blanks tiles rewritten after it is
installed.
