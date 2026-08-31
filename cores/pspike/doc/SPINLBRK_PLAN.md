# Spinal Breakers - bring-up plan

MAME `vsystem/pspikes.cpp`, machine `spinlbrk`. Four sets, all the same hardware:
`spinlbrk` (World), `spinlbrku` (US), `spinlbrkj` (Japan), `spinlbrkup` (US proto).
V-System, 1990, ROT0.

Read `SPLIT_PLAN.md` first - spinlbrk should land as new per-game modules, not as a
fifth arm on the existing ternary chains.

## Verdict up front

Same board family as turbofrc: same CPUs, same YM2610, same GGA, same VS8904/VS8905
pair, same tile geometry, same palette bases, same sound port map. Two tile layers and
two sprite chips, so it is a **turbofrc-class** game, not a pspikes-class one.

Three things are genuinely new, and only one of them is hard:

1. **Sprite chip 1 takes its tile lookup from ROM, not RAM** - and the index is a
   modulo by a non-power-of-two.
2. **Sprite chip 0 has no lookup at all** - the map index *is* the tile number.
3. Its ROM regions are the biggest in the family and **break the current SDRAM bank
   map** in two places.

Everything else is a decode and a constant table.

## Chips and timing

| Block | Part | Notes |
|---|---|---|
| Main CPU | 68000 @ 10 MHz (XTAL 20/2) | verified on PCB. IRQ1 on vblank; vectors 3 and 4 exist, MAME guesses analog |
| Sound CPU | Z80 @ 5 MHz (XTAL 20/4) | banked, IRQ from the YM2610 |
| Sound chip | YM2610 @ 8 MHz | **ADPCM-A only, no ADPCM-B** |
| Video timing | C7-01 GGA @ 14.318181/2 | |
| Sprites | VS8904 + VS8905 x2 | `set_pritype(1)` on both |
| Screen | `set_visarea(1*8, 45*8-1, 0*8, 30*8-1)` = 8..359 x 0..239 -> **352x240**, ROT0 | |
| Palette | 1024 x xRGB-555, init BLACK | `ffe000-ffe7ff`, same as turbofrc |

### GGA - the only game in the family with a different H total

From the driver's own comparison table (`pspikes.cpp:35`), and decoded with the
`(reg+1)*4` / `(reg+1)*2` rule in `GGA.md`:

| reg | 00 | 01 | 02 | 03 | 04 | 05 | 08 | 09 | 0a | 0b | 0c | 0d |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| value | 57 | 68 | 6f | 75 | ff | 01 | 77 | 78 | 7b | 7f | ff | 00 |
| decoded | 352 | 420 | 448 | **472** | - | - | 240 | 242 | 248 | 256 | - | - |

pspikes / turbofrc / karatblz all run `57 63 69 71` = 352/400/424/**456**. spinlbrk
stretches H total to 472 and widens HS to 28 pixels. At 7.159090 MHz that is
472 x 256 = **59.24 Hz**, against 61.33 Hz for the rest of the family.

It is also the only game in the whole table with `04 = ff` and `0c = ff` (everyone
else is `1f`). Those two registers are still not understood; note the outlier and
move on - it does not block anything.

`reg 08 = 0x77` decodes to 240 directly, so the `246 -> 240` special case in
`vheight()` does not fire here.

`JTFRAME_WIDTH/HEIGHT` stay 352x240; the GGA register file already carries the rest.
`JTFRAME_RATE` is a family compromise already, and `JTFRAME_SKIP_RATE_TEST` is set.

## Main CPU map

```
000000-03ffff  ROM
080000-080fff  vram 0    <-- see the size warning below
082000-082fff  vram 1    <-- see the size warning below
ff8000-ffbfff  work RAM (16 kB)
ffc000-ffc7ff  sprite RAM (2 kB, both chips)
ffd000-ffd1ff  raster RAM (512 B = 256 words, one scroll X per line)
ffe000-ffe7ff  palette (1 kB... 2 kB region, 1024 entries)
fff000 r IN0     fff000.b w flip screen (bit 7)
fff001.b w gfxbank
fff002 r IN1     fff002.w w layer 1 scroll X
fff004 r DSW
fff007.b w sound latch
fff008/fff00a    read when analog inputs are enabled (not mapped)
fff400-fff403 w  GGA (umask 00ff)
```

Notes against the rest of the family:

- The map is **24-bit like pspikes**, not `global_mask(0xfffff)` like turbofrc /
  aerofgt / karatblz. Do not copy the turbofrc decoder.
- There is **no sprite lookup RAM** in the map at all (turbofrc has `0e0000`/`0e4000`,
  karatblz `0a0000`/`0b0000`). This is the ROM-lookup difference.
- There is **no work RAM 2** (`0f8000-0fbfff` on the others). Work RAM is a single
  16 kB block, the smallest in the family.
- There is **no scroll Y** for either layer - MAME's `screen_update_spinlbrk` has both
  `set_scrolly` calls commented out.
- `fff000` is read as a word and written as a byte (even address, UDS,
  `main_dout[15:8]`), `fff001` is the odd byte (LDS). The sound latch at `fff007` is
  an odd byte, LDS, `main_dout[7:0]` - same convention as pspikes and karatblz, the
  opposite of turbofrc/aerofgt.

### VRAM size - measure this before writing the decoder

MAME maps **4 kB per layer** (`080000-080fff`, `082000-082fff`) but `video_start`
builds both tilemaps as **64x64 of 8x8** = 4096 entries = **8 kB**. karatblz, which
shares the layer-1 tile format, maps the full `080000-081fff` / `082000-083fff`.

So either spinlbrk's layer 0 is really 64x32, or MAME's map is short. `081000-081fff`
is genuinely unmapped in the driver, so this is not a mirror.

Resolve it by measurement, not by argument - the write-tap in
`.claude/skills/mame-decoder` step 5 over `080000-083fff`, bucketed by A[12:11],
answers it in one 60-second run. Do this **before** sizing the `vram`/`vram1` BRAMs
and the decoder.

## Video

### Tile formats - a fourth variant

```
layer 0 (spinlbrk_tile_info):  code = (v & 0x0fff) | (gfxbank[0] << 12)   colour = v[15:12]
layer 1 (karatblz_tile_info):  code = (v & 0x1fff) | (gfxbank[1] << 13)   colour = v[15:13]
```

Layer 0 is a format no other game in the core uses: a 12-bit code with a 3-bit bank,
and a **4-bit** colour field (16 palettes x 16 pens = the full 256-entry base). Layer 1
is exactly karatblz's.

Sizes check out: layer 0 reaches 2^15 tiles x 32 B = 1 MB = `gfx1`; layer 1 reaches
2^16 x 32 B = 2 MB = `gfx2`.

Palette bases are turbofrc's, unchanged: layer 0 at 0, layer 1 at 256, sprite chip 0
at 512, chip 1 at 768. `_colmix.v` needs nothing.

This is `tilefmt` case 4 in SPLIT_PLAN.md B4, not another `two`/`kb` boolean.

### gfxbank and flip

```
fff001.b  gfxbank:  bank0 = d[2:0]   bank1 = d[5:3]
fff000.b  flip:     bit 7
```

Three bits per layer, against karatblz's one bit per layer and turbofrc's eight
4-bit banks. `spinlbrk_flip_screen_w` flips **both** tilemaps; `turbofrc_flip_screen_w`
flips only layer 0. Since flip is not implemented anywhere in the core yet, just
record it.

### Scroll

```
layer 0:  per-line, rasterram[i] - 8      (a real per-line table, one word per line)
layer 1:  scrollx[1] - 4   from fff002
neither layer scrolls in Y
```

Layer 0 is the **pspikes** raster model (index the table by line), not the turbofrc
one (`rasterram[7]` for every row). `_scr.v` already has both paths - the selector
just has to pick the pspikes one for a two-layer game, which today's `two` boolean
makes impossible. Another reason for the explicit `tilefmt`/`rastermode` codes.

The raster RAM is only 512 B here, so `rascr` can shrink for this game (it will not,
in a shared bitstream - noted for the Option A split).

### Sprites - the real work

Both chips are `VSYSTEM_SPR2` with `set_pritype(1)`, no `set_offsets`.

**Chip 0 has no `set_tile_indirect_cb`.** It falls back to
`vsystem_spr2_device::tile_callback_noindirect`, i.e. the map index passes straight
through as the tile number. Our `_objscan.v` always goes through the lookup RAM; it
needs a **bypass mode**.

**Chip 1 reads its lookup from ROM:**

```c
uint32_t spinbrk_tile_callback(uint32_t code)
{
    return m_sprlookuprom[code % m_sprlookuprom.length()];
}
```

`sprlookuprom` is `ROM_REGION16_BE(0x24000)`, filled `0x00000-0x1ffff` from
`ic19`/`ic13` as an interleaved byte pair, with `0x20000-0x23fff` left as zeros.
Read as `uint16_t`, `length()` = **0x12000 words = 73728**, which is **not a power of
two**, so `%` is a genuine modulo and not a mask.

Three things to settle, in this order:

1. **Measure the range of `code`.** Tap `m_curr_sprite.map` in MAME and log its
   maximum over an attract loop plus a level. If it never reaches 0x12000 the modulo
   is a no-op and the address is a plain truncation.
2. If it can exceed 0x12000 but stays under 0x24000, one conditional subtract does it:
   `a = code >= 18'h12000 ? code - 18'h12000 : code`.
3. Only if it exceeds 0x24000 does this need a real divider - and at that point check
   whether the hardware really wraps this way or whether MAME's `%` is defensive
   coding around an out-of-range index. The PCB has no divider; it has address lines.

The lookup itself becomes a new SDRAM client (`sprlut`, 16-bit, big-endian), replacing
the `lut1` BRAM read for this game. `_objscan.v` already has the `wide_lut` seam where
the LUT width is chosen; this adds a source selector next to it.

The tile-index masks in `_objscan.v` need a spinlbrk row:

```
chip 0  spritegfx 0x100000 / 128 =  8192 -> 13 bits
chip 1  gfx4      0x200000 / 128 = 16384 -> 14 bits
```

### Priority - inverted relative to turbofrc

`vsystem_spr2.cpp`:

```
pritype 0 (turbofrc):  usepri = pri ? 0 : 2
pritype 1 (spinlbrk):  usepri = pri ? 2 : 0
```

and `screen_update_spinlbrk` draws in a different order from turbofrc:

```
layer 0 (opaque, pri 0)
layer 1 (pri 1)                      <- same as turbofrc: layer 1 masks pri-0 sprites
chip 0 pri 0, chip 0 pri 1
chip 1 pri 0, chip 1 pri 1           <- turbofrc runs chip 1 first, and pri 1 before pri 0
```

The mixer currently hardcodes turbofrc's scheme. This is the same class of difference
that is still open on karatblz (`STATUS.md`), so do the two together and make the
priority scheme an explicit input rather than a third hardcoding.

## Sound - free

Identical to the rest of the family:

- `sound_map`: `0000-77ff` ROM, `7800-7fff` RAM, `8000-ffff` banked.
- `sh_bankswitch_w`: `data & 3`, four 32 kB banks over a 128 kB region.
- `spinlbrk_sound_portmap` - the same map pspikes, turbofrc and karatblz use
  (bank `00`, latch/ack `14`, YM `18-1b`). Only aerofgtb uses `pspikes_sound_portmap`.
- YM2610 @ 8 MHz, routes 0 -> both at 0.75, 1 -> L and 2 -> R at 1.0.

The one difference: **no `ymsnd:adpcmb` region**. The `pcmb` SDRAM bus must tolerate an
absent region (no download, `cs` never asserted). Confirm `jtframe mra` emits a
consistent header/offset table when a listed region is missing for a set.

## Inputs and DIPs

```
IN0  fff000   P1 up/down/left/right, B1..B3 (bits 0-6), COIN1/2 (8,9),
              START1/2 (10,11), SERVICE1 (14)
IN1  fff002   P2 up/down/left/right, B1..B3, low byte only
DSW  fff004   one 16-bit word
```

Two players, three buttons - `JTFRAME_BUTTONS=4` already covers it.

The DIP names are long and will not fit the OSD:
`"1 Credit 1 Health Pack"`, `"2-1-1C  1-1-1 HPs"`, `"Credits For Extra Hitpoints"`.
Plan on a `rename` block like f1grpr's. `SW2:5 Lever Type` selects Analog, which MAME
notes "causes lever error" - default it to Digital and consider deleting the option.

## ROMs and the SDRAM bank map

Region sizes, with the family maximum in brackets:

| region | spinlbrk | family max |
|---|---|---|
| maincpu | 0x60000 | turbofrc 0xc0000 |
| soundbank | 0x20000 | 0x20000 |
| audiocpu | 0x08000 | 0x08000 |
| gfx1 (scr0) | **0x100000** | spinlbrk |
| gfx2 (scr1) | **0x200000** | spinlbrk |
| spritegfx (obj0) | 0x100000 | karatblz 0x400000 |
| gfx4 (obj1) | **0x200000** | spinlbrk |
| sprlookuprom | **0x24000** | spinlbrk only |
| ymsnd:adpcma | 0x100000 | 0x100000 |
| ymsnd:adpcmb | none | karatblz 0x80000 |

**Two collisions in the current layout:**

```
bank1  obj1 @0x200000, snd @0x300000   -> a 2 MB gfx4 runs to 0x3fffff, over snd
bank3  scr1 @0x800000, pcmb @0x900000  -> a 2 MB gfx2 runs to 0x9fffff, over pcmb
```

The `addr_width`s in `mem.yaml` are already wide enough (`obj1` 21, `scr1` 21) - only
the start offsets are wrong. Proposed layout, keeping the "one heavy gfx client per
bank" rule from `macros.def` and putting the sprite LUT next to the chip that uses it
(chip 1 = `obj1` + `sprlut`, in a bank whose only other client is the light `snd`):

```
bank0   main   0x000000  1 MB       scr0   0x100000  1 MB
BA1   = 0x200000
bank1   obj1   0x200000  2 MB       snd    0x400000  128 kB   sprlut 0x420000  256 kB
BA2   = 0x460000
bank2   obj0   0x460000  4 MB       pcma   0x860000  1 MB
BA3   = 0x960000
bank3   scr1   0x960000  2 MB       pcmb   0xB60000  512 kB
```

Open question for sim: bank 1 now serves three clients, and chip 1's lookup fetch can
overlap its own tile fetch. `jtframe_rom_2slots` becomes a 3-slot instance - watch for
sprite-scan stalls in the first scene run, and if it bites, move `sprlut` to bank 2.

`STATUS.md` claims `SPRLUT_START is already reserved in the bank map`. It is not -
there is no such symbol in `cfg/macros.def`. Fix that line while you are in there.

## mame2mra

- `mustbe.machines` += `"spinlbrk"`; the four sets come with it.
- Header **bit 4** (0-3 are taken; karatblz has bit 3).
- `maincpu` is `ROM_LOAD16_BYTE` pairs -> `width=16, reverse=true`, like aerofgtb, not
  like pspikes/turbofrc. Verify with the reset-vector check in `STATUS.md` before
  simming anything: read the blob byte-swapped and confirm SP/PC look sane. This exact
  mistake cost the aerofgtb bring-up.
- `soundbank` uses `ROM_RELOAD` - confirm `jtframe mra` emits the 64 kB image twice.
- `sprlookuprom` -> rename `sprlut`, `width=16`, interleaved `ic19`/`ic13`, and the
  region is 0x24000 while only 0x20000 is loaded: **the 16 kB zero tail must be
  padded**, because the modulo above reaches into it. Check what `jtframe mra` does
  with a region larger than its loads.
- `order` is sorted by post-rename region name and must be ascending by start **for
  every set** - re-derive it after the bank re-layout, this is where the existing
  comment in `mame2mra.toml` earned its length.

## Work order

1. MAME taps: the VRAM size question, and the maximum sprite-map index for the modulo.
   Both are one short headless run each, and both change what gets written.
2. `jtpspike_dec_sb.v` + the I/O variant, per SPLIT_PLAN.md. Lint.
3. Bank re-layout + `mem.yaml` `sprlut` bus + `mame2mra.toml`. Re-run the reset-vector
   check on the generated blob **before** the first sim.
4. Boot sim. Compare against a MAME boot trace with `verify_main_boot.sh` if it stalls
   - two guesses have already lost to that script on this core.
5. Sprite LUT bypass (chip 0) and ROM path (chip 1) in `_objscan.v`.
6. `tilefmt` case 4 in `_scr.v`, per-line raster on a two-layer game.
7. Priority scheme as an input; do it together with the open karatblz item.
8. Scene fixtures, then hand over renders.

Steps 1-4 are independent of the karatblz work. Step 7 is not - do not fix the mixer
twice.
