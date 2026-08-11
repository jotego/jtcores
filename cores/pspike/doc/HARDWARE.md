# Power Spikes / Video System Co. hardware

Reference: MAME `src/mame/vsystem/pspikes.cpp` (mirrored here, together with the two device
files the driver instantiates: `vsystem_spr2.*` and `vsystem_gga.*`).

The board family is built around the **C7-01 GGA**, **VS8803** and the **VS8904 + VS8905** pair.
Only the sprite pair and the GGA have MAME devices; VS8803 is undocumented and unemulated.

## Chip inventory

| Block | Part | Notes |
|---|---|---|
| Main CPU | 68000 @ 10 MHz (XTAL 20 MHz / 2) | IRQ1 on vblank; all vectors point to the same handler |
| Sound CPU | Z80 @ 5 MHz (XTAL 20 MHz / 4) | INT from the YM2610 |
| Sound chip | YM2610 @ 8 MHz | ADPCM-A 1 MB, ADPCM-B 256 KB |
| Video timing | C7-01 GGA @ 14.318181 MHz / 2 | 4 write-only registers, address/data pair |
| Sprites | VS8904 + VS8905 | zooming, 16x16 tiles, indirect tile lookup |
| Unknown | VS8803 | no known function |
| Tilemap | discrete / inside the GGA | no MAME device — the driver implements it |

Screen: 61.31 Hz (measured on PCB), visible area `4..355 x 0..239` = **352x240**, ROT0.
Palette 2048 entries, xRGB-555, word writes.

## Crystals

| XTAL | Drives |
|---|---|
| 20 MHz | 68000 (/2 = 10 MHz) and Z80 (/4 = 5 MHz) — both verified on PCB by MAME |
| 14.318181 MHz | C7-01 GGA (/2 = 7.159 MHz pixel clock) — the divider is *not* verified by MAME |
| 8 MHz | YM2610 — assumed on pspikes, but verified on PCB on turbofrc (same family) |

The GGA divider checks out arithmetically: 7.159090 MHz over a 456x256 grid gives 61.33 Hz against
the 61.31 Hz measured on the PCB, and a 15.70 kHz horizontal rate. So the real timing grid is
456x256, not the 512x256 that `screen.set_size(64*8, 32*8)` nominally declares.

On FPGA everything comes off `jtframe_pll7159`: 57.272 MHz main clock, 7.159 MHz pixel clock
(`PXLCLK=8`). The 68000, Z80 and YM2610 clocks are derived with `jtframe_frac_cen`.

## C7-01 GGA registers

MAME's device is a skeleton, but the game writes a full init table at boot (ROM `0x1202e`, 12
pairs, address to `fff403` then data to `fff401`), and the values decode cleanly. H registers
count in units of 4 pixels, V registers in units of 2 lines, both biased by one unit:

| reg | value | = | meaning |
|---|---|---|---|
| 00 | 57 | 352 | H display end / HB start |
| 01 | 63 | 400 | HS start |
| 02 | 69 | 424 | HS end |
| 03 | 71 | 456 | H total |
| 04 | 1f | 128 | ? |
| 05 | 00 | 4 | ? |
| 08 | 77 | 240 | V display end / VB start |
| 09 | 79 | 244 | VS start |
| 0a | 7b | 248 | VS end |
| 0b | 7f | 256 | V total |
| 0c | 1f | 64 | ? |
| 0d | 00 | 2 | ? |

So the grid is **456x256 with 352x240 visible**, which is exactly what the 7.159 MHz pixel clock
and the 61.31 Hz measured refresh predict. Registers 04/05 and 0c/0d hold the same values across
every game in MAME's comparison table and are not understood yet.

Note the HS pulse is only 24 pixels (3.35 us), shorter than the 4.7 us TV standard, so
`jtframe_vtimer`'s length assertion fires in simulation. The values above are what the hardware
programs.

## Main CPU memory map (`pspikes_map`)

```
000000-03ffff  ROM, 256 KB           (ROM_LOAD16_WORD_SWAP)
100000-10ffff  work RAM, 64 KB
200000-203fff  sprite tile-lookup RAM, 8192 x 16
ff8000-ff8fff  tilemap VRAM, 2048 x 16 (64x32 of 8x8)
ffc000-ffc3ff  sprite RAM, 512 x 16   (write only)
ffd000-ffdfff  raster RAM             (only [0..255] used: per-line scroll X)
ffe000-ffefff  palette RAM, 2048 x 16

fff000.w  r  IN0
fff001.b  w  palette bank / char palette bank / flip screen
fff002.w  r  IN1
fff003.b  w  gfx bank
fff004.w  r  DSW          fff004.w  w  scroll Y
fff007.b  r  sound latch pending      fff007.b  w  sound latch
fff400-fff403  w  GGA (umask 00ff: even = data, odd = address)
```

`fff001` write: bits [1:0] = sprite palette bank, bits [4:2] = char palette bank, bit 7 = flip screen.
`fff003` write: bits [7:4] = gfx bank 0, bits [3:0] = gfx bank 1.

## Sound CPU

```
0000-77ff  ROM
7800-7fff  RAM
8000-ffff  banked ROM, 4 x 32 KB windows out of a single 128 KB ROM
```
I/O (`spinlbrk_sound_portmap`, global mask 0xff):
```
00  w  bank select (bits [1:0])
14  rw sound latch read / acknowledge
18-1b rw YM2610
```
The latch is two-way: writing it asserts the Z80 NMI, the Z80 acknowledges through port 14, and the
68000 polls the pending flag at `fff007`.

## Tilemap

64x32 map of 8x8 4bpp tiles, **opaque** (no transparent pen), single layer.

```
code = vram[i]
bank = code[12]
tile = code[11:0] | gfxbank[bank] << 12
pal  = code[15:13] + 8 * charpalettebank        -> palette entries 0..1023
```

Scroll: screen line `y` takes its X scroll from `rasterram[y]`; scroll Y is the single `fff004`
register. (MAME expresses this as `set_scrollx((i + scrolly) & 0xff, rasterram[i])` combined with
`set_scrolly(0, scrolly)`, which reduces to the same thing.)

## Sprites — VS8904 / VS8905

512 words of sprite RAM = 128 slots of 4 words. The **last slot's word 2** (`ram[0x1fe]`) is the
list start pointer: `first = (4 * ram[0x1fe]) & 0x1ff`, clamped to `0x200-4`. Slots are walked in
reverse, from `0x1f8` down to `first`, once per priority pass.

```
w0: [8:0]   oy          [15:12] zoomy
w1: [8:0]   ox          [15:12] zoomx
w2: [3:0]   color       [4] pri     [7] enable
    [10:8]  xsize       [11] flipx
    [14:12] ysize       [15] flipy
w3: [15:0]  map          index into the lookup RAM; the RAM holds the real tile code
```

* Zoom: `zoom = 32 - nibble`, so the scale is `zoom/32` — **shrink only**, from 1.0 down to 0.53.
  Tile pitch on screen is `zoom/2` pixels instead of 16.
* Block: `(xsize+1) x (ysize+1)` tiles of 16x16, up to 8x8 tiles.
* Map advance: the x loop increments `map` once per tile, then `handle_xsize_map_inc()` adds
  `0,0,1,0,3,2,1,0` for xsize `0..7`. Net effect: the **row stride is the next power of two of
  `xsize+1`** -> 1, 2, 4, 4, 8, 8, 8, 8. So `map = base + row*stride + col`.
* Both axes wrap at 0x200: the drawn coordinate is `((v + 16) & 0x1ff) - 16`, and MAME additionally
  redraws at -0x200 on each axis to cover the wrap.
* Palette: `1024 + 16*(color + 16*spritepalettebank)`, transparent pen 15.
* Priority: pass with `pri != 0` is drawn first (behind), then `pri == 0`. With a single tilemap
  the priority bitmap stays 0, so sprites always land above the tilemap and the `pri` bit only
  orders sprites against each other.

## gfx encoding

| Region | Size | Layout | Load |
|---|---|---|---|
| `gfx1` tiles | 512 KB | `gfx_8x8x4_packed_lsb`, 32 B/tile, 16384 tiles | one `ROM_LOAD` |
| `gfx2` sprites | 1 MB | `gfx_16x16x4_packed_lsb`, 128 B/tile, 8192 tiles | two 512 KB `ROM_LOAD32_WORD`, interleaved |

Both are already 32-bit-natural: one 32-bit read yields 8 pixels, i.e. a full 8x8 tile row or half
a sprite row. No plane de-interleave is required.

## Family differences (for later sets)

| Set | Tilemaps | Sprite chips | Notes |
|---|---|---|---|
| `pspikes` | 1 (64x32) | 1 | per-line scroll X, 2048-entry palette |
| `karatblz` | 2 (64x64) | 2 | 4 players (IN2/IN3), lookup RAM is 64 KB **per chip** |
| `spinlbrk` | 2 (64x64) | 2 | sprite lookup comes from **ROM**, not RAM |
| `turbofrc` | 2 (64x64) | 2 | ROT270, 8 gfx banks via `turbofrc_gfxbank_w` |
| `aerofgtb` / `sonicwi` | 2 (64x64) | 2 | ROT270, sprite offsets (3, -1), 320x224 |

All of them keep the 68000 + Z80 + YM2610 chain. The bootlegs in the same driver do not, and are
out of scope for this core.
