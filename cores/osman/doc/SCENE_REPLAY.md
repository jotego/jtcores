# Video scene replay

Scene replay restores video state and renders it with the CPU and sound disabled.
It is separate from a full boot simulation, which exercises CPU execution,
ROM loading and EEPROM initialization.

`cfg/mem.yaml` declares the palette, sprite and rowscroll RAM preload files.
`cfg/mmr.yaml` declares the 16-byte DECO16IC control block; its generated
`jtdeco16ic_mmr` loads the first 16 bytes of `rest.bin` with `SEEK=0`.
`jtosman_video` selects `pf1.bin` and `pf2.bin` under `SIMSCENE`.
The core-specific `ver/game/rest2bin.sh` splits a captured video dump into those
files. The shared `jtsim` and generated `dump2bin.sh` need no changes.

All dump fields are little-endian. These are video formats, **not** the BRAM
upload format or an EEPROM image:

| Offset | Legacy 16-bit palette (0x5810 bytes) | Heavy Smash (0x6010 bytes) |
| --- | --- | --- |
| 0x0000 | Controls, 0x10 bytes | Controls, 0x10 bytes |
| 0x0010 | Palette, 0x800 bytes, LE16 | Palette, 0x1000 bytes, LE32 xBGR888 |
| 0x0810 / 0x1010 | PF1, 0x1000 bytes | PF1, 0x1000 bytes |
| 0x1810 / 0x2010 | PF2, 0x1000 bytes | PF2, 0x1000 bytes |
| 0x2810 / 0x3010 | Rowscroll 1, 0x1000 bytes | Rowscroll 1, 0x1000 bytes |
| 0x3810 / 0x4010 | Rowscroll 2, 0x1000 bytes | Rowscroll 2, 0x1000 bytes |
| 0x4810 / 0x5010 | Live sprite RAM, 0x1000 bytes | Live sprite RAM, 0x1000 bytes |

For Heavy Smash each four-byte palette entry `[R,G,B,unused]` becomes `[R,G]`
in `pal.bin` and `[B,unused]` in `palh.bin`. Both files contain 1024 LE16
words (2048 bytes). Loading a legacy scene explicitly zeroes `palh.bin` so a
previous Heavy Smash scene cannot leak its high palette half.
Heavy Smash has 0x800-byte rowscroll shares; pad each to 0x1000 with zeroes.
Read its low-half devices at four-byte CPU address strides before serializing
dense LE16 words. Read the palette as full dwords.

A 128-byte `rest.bin` still restores the direct EEPROM image into `nvram.bin`.
`--delete` clears all video preload files including `palh.bin`, and restores
`nvram.seed` when present. See [NVRAM.md](NVRAM.md) for full boot behavior.

To check the splitter on macOS or Linux (Bash, Ruby, standard Unix tools):

```sh
cores/osman/ver/scene-loader/run.sh
```

For a replay, use a fresh verification work folder named for the ROM set,
copy the core's `rest2bin.sh` into its sibling `game` folder, and supply the
normal generated `dump2bin.sh`. It passes the entire video dump through as
`rest.bin` because these video memories are not ioctl upload sections.
Set `JOTEGO` to a private support directory containing
`scenes/osman/<setname>/<scene>/dump.bin` (export it again after `setprj.sh`).
Run `jtsim -s <scene> -load -u DUMP` once to populate ROM banks, then omit
`-load` for later scenes using those same banks. Preserve fresh settings,
source/dump hashes and logs; verify both palette files and the MMR readback.
Do not change or replace the user's real scenes directory.

A successful render is not an accuracy claim. Compare against a MAME reference
held at the same captured state; Heavy Smash's visible area is x=0..319,
y=8..247. Preserve fixed sprite inversion and check sprite flashing parity.
No image shifts, layer masking or palette substitutions belong in the diff.

Chain Reaction uses the 0x5810-byte format, with video device addresses in the
0x41..0x46 ranges and two mapped aliases of PF1 (0x450000 and 0x452000). Hold
writes to both aliases when capturing. Each rowscroll table has 2048 halfwords,
so no padding is needed. The MMR definition and restore offset are the same.
Its sprite-ROM byte interleave is described in [ROM_LOADING.md](ROM_LOADING.md).

Heavy Smash has a different mixing order from the simpl156 games: opaque PF2,
sprites, then transparent PF1. MAME leaves the tile priority bitmap at zero,
so the sprite priority bits do not move sprites behind PF2 or in front of PF1.
The mixer uses the Heavy Smash header selection (`pal888`, derived from `hv`)
for this order and preserves simpl156's priority masks for the other games.
`ver/colmix/run.sh` verifies both board rules, both tile sizes and transparent
pixels against those MAME draw orders.
