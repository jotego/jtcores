# 68000 boot trace (pspikes)

Capture (MAME is ground truth):

```bash
~/mame/mame -rompath ~/mameroms pspikes -debug \
  -debugscript cores/pspike/ver/pspikes/mame_scripts/trace_main_boot.mame \
  -nothrottle -video none -window -nokeepaspect -seconds_to_run 1
mv /tmp/pspike_main.tr cores/pspike/ver/pspikes/traces/main_boot.tr
```

Compare:

```bash
FRAMES=140 ROMS_HOST=~/mameroms ./sim-core.sh pspike pspikes
cores/pspike/ver/pspikes/verify_main_boot.sh
```

The FPGA side comes from the `SIMULATION` dumper at the bottom of
`hdl/jtpspike_main.v`, which logs every program-space read as `PC: opcode`.

## Boot landmarks

| PC | what |
|---|---|
| `000000` | reset vector: SP=`00110000` (top of work RAM), PC=`00000400` |
| `000404` | `move D0,SR` with `#$2700` - interrupts masked |
| `000406` | `lea $10ff00,A0` / `move A0,USP` |
| `00040E` | `lea $1202e,A0` - **GGA register table**, 12 pairs written as address to `fff403`, data to `fff401` |
| `00042A` | `lea $12000,A0` - memory test region table |
| `000430` | `jsr $674` - memory test |
| `000674` | test entry. Each table entry is 10 bytes: start(4), end(4), error mask(2) |
| `000686` | pass 1: write `$FFFF`, read back, compare |
| `000698` | pass 2: write `$0000`, read back, compare |
| `0006A4` | failure path: `or.w ($8,A0),D0` accumulates the region's error mask |
| `0006A8` | `lea ($a,A0),A0` - next region. Reached 4 times, once per region |
| `0006CC` | vblank IRQ handler (level 1 autovector at `$64`) |

Regions tested (table at ROM `0x12000`):

| start | end | error mask | what |
|---|---|---|---|
| `00100000` | `0010FFFF` | `0001` | work RAM, 64 kB |
| `00FF8000` | `00FF8FFF` | `0004` | tilemap VRAM |
| `00FFD000` | `00FFDFFF` | `0010` | raster RAM |
| `00FFE000` | `00FFEFFF` | `0020` | palette |

## Reading the FPGA trace - prefetch

The 68000 prefetches, so the FPGA stream is a **superset** of MAME's PC list. Two traps:

- **`0006A4` appears 4 times in the FPGA trace and 0 times in MAME's.** That is not a failed
  memory test: it is the word after `bra $6a8` at `0006A2` being fetched and discarded. Every
  `0006a4` line is immediately followed by `0006a8`. The memory test passes.
- A raw line-by-line diff, or a windowed subsequence match, **desynchronises** inside the RAM
  test: the FPGA emits ~6 fetches per loop iteration where MAME emits 5 instructions, which
  drifts by tens of thousands of lines over the 65k iterations of the 64 kB region.

`verify_main_boot.sh` therefore compares **code paths**: the ordered set of addresses each side
reaches for the first time. That is immune to both.

## Status

All 909 addresses MAME executes in its first second of boot are reached by the FPGA, and the
vblank handler at `0006CC` runs every frame.

## Byte order (settled here, do not re-litigate)

`maincpu` is `ROM_LOAD16_WORD_SWAP`, so MAME's memory image is the file byte-swapped. The jtframe
download path already assembles the 16-bit word from the blob in that swapped order, so the MRA
region is loaded **straight**. Adding `reverse=true` swaps twice and the CPU fetches `0x1100`
instead of `0x0011` at reset - the first symptom is a fetch stream that starts at `000000: 1100`.
