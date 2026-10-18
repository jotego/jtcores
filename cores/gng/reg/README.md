# GnG Core Regression Test ROM

Custom test ROM for the Ghosts'n Goblins FPGA core. Contains no
copyrighted material — all code and graphics are original.

## What it tests

1. **Tilemap display** — draws text via the FG char layer
2. **Input reading** — polls P1, P2, SYS, DSW1, DSW2 each frame
3. **IRQ / DMA** — VBLANK IRQ triggers sprite DMA and palette refresh
4. **Palette** — sets 6 palettes with distinct colors during VBLANK

## Build

Requires `lwasm` from [lwtools](https://www.lwtools.ca/) and Python 3.

```bash
cd cores/gng/reg
./build.sh            # assemble + generate ROMs + pack regtest.zip
./build.sh --run      # also launch in MAME (set MAME env var)
```

For jtsim, generate the `.rom` with `jtutil rom regtest.mra`.

## Deploy to MiSTer

Copy to the MiSTer SD card:
- `regtest.mra` → `/media/fat/_Arcade/`
- `build/regtest.zip` → `/media/fat/games/mame/`

The MRA uses `rbf=jtgng` (the standard GnG core).

## Hardware notes

### Palette offset

The FPGA core uses `pixel_mux = {2'b11, char_pxl}` for char pixels,
placing char palette entries at `$C0-$FF` in the 256-entry palette RAM.
MAME's GFXDECODE uses `$80-$BF`. Test ROMs must write to `$C0+`.

### VBLANK-only palette writes

The colmix address mux (`eff_AB`) points to `pixel_mux` during active
display. CPU palette writes during active display go to the wrong RAM
address. Palette must be written during VBLANK only (use SYNC or the
IRQ handler).

### Boot sequence

The test ROM replicates the real GnG boot: sprite RAM fill with $F8,
100 SYNC cycles, then hardware init. The direct page register (DP)
must be set to 0 explicitly — it is undefined after reset on real
hardware.

### Font encoding

The 2bpp char ROM uses `pen 0 = high nibble, pen 1 = low nibble`
per byte, with a 1px drop-shadow (pen 2). The MRA `map="12"` interleave
handles the byte ordering for the FPGA download.

## Files

| File | Purpose |
|------|---------|
| `reg_test.s` | MC6809 assembly source |
| `gen_roms.py` | Generates 2bpp font + stub graphics ROMs |
| `split_rom.py` | Splits assembled binary into gg3.bin + gg4.bin |
| `build.sh` | Build script |
| `regtest.mra` | MRA for MiSTer and jtsim |
| `reg_test.cab` | Cabinet input script for jtsim |
| `Dockerfile` | Docker image with lwtools + Python 3 |
