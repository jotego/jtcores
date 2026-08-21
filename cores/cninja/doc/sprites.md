# cninja sprites — MAME (decospr) handling, debugged + implementation plan

Source: `doc/decospr.cpp` (`draw_sprites_common`) + `doc/cninja.cpp` machine
config. **Verified** by decoding the real spriteram of scene 1500 (the cavemen
sprites land at the correct on-screen positions/colours — see below).

## The hardware

- Chip: **DECO_SPRITE / decospr** (MXC-06 family), one sprite generator.
- Sprite RAM: `buffered_spriteram16` at **0x1a4000** (0x800 bytes = 0x400 words
  = **256 sprite slots × 4 words**). It is **double-buffered**: a write to the
  DMA-flag register **0x1b4000** copies spriteram → the buffer the chip draws
  from. (Our scene dumps capture 0x1a4000; for a static frame the buffer = it.)
- gfx: `GFXDECODE_ENTRY("sprites1", 0, tilelayout, 768, 32)` → 16×16 4bpp tiles,
  palette base **768 = 0x300**, 32 colours. Pen = **0x300 + colour·16 + pixel**.
- ROM region `sprites1` (2MB) = mag-05/06/03/04 (mame2mra `sprites1` width=32
  sort_even). Same 4bpp planar format as the tiles.

## Sprite entry format (non-`alt_format`, 4 words/slot; words 0,1,2 used)

```
word0 (y) : [8:0] ypos
            [10:9] height  -> multi = (1 << bitswap2(y,10,9)) - 1  => 1/2/4/8 tiles tall
            [11]  wide     -> draws a 2nd 16px column at x-16, tile-(multi+1) ("wing")
            [12]  flash    -> blink: skip drawing on odd frames
            [13]  fx (hflip)
            [14]  fy (vflip)
            [15]  extra priority bit (passed to col/pri callbacks)
word1     : tile code (16b). For multi-height: tile &= ~multi, then +multi if !fy
            (i.e. top tile is the highest code; rows count down when not flipped)
word2 (x) : [8:0]  xpos
            [13:9] colour = (x >> 9) & 0x1f
            [15:14] priority (cninja pri_callback: 0/4000/8000/c000 -> mask 0/f0/f0|cc)
word3     : unused
```

Placement (256-wide path, `m_x/y_offset = 0`, no flip):
`sx = 240 - (xpos & 0x1ff)`, `sy = 240 - (ypos & 0x1ff)`; a multi-tile sprite
stacks **upward** (`mult = -16`, rows at sy, sy-16, …). Drawn **back-to-front**
(`offs = sizewords-4` downto 0 when a pri_cb is set).

### Priority (cninja_state::pri_callback, arg = x word)

```
x[15:14]==0 -> 0           (sprite behind everything mixed normally)
        ==1 -> 0xf0
        >=2 -> 0xf0|0xcc
```
Used with `prio_transpen` against the tilemap priority buffer. For a first cut we
can draw all sprites over the playfields and add priority mixing later.

## Decode verification (scene 1500 spriteram)

| slots | colour | sx | sy | what |
|-------|--------|----|----|------|
| 19-23 | 1 | 45-61   | 116-148 | caveman (center-left), 2-tile-tall pieces |
| 24-27 | 2 | 93-125  | 112-144 | other caveman (one piece H=4) |
| 28-30 | 0 | 133     | 115-163 | enemy |
| 4-11  | 7 | …       | …       | HUD / UI sprites |

Positions match MAME's rendered frame → the format reading is correct.

## STATUS (implemented + verified vs MAME scenes 900/1500)

`jtcninja_obj.v` is implemented (adapted from cop) and wired into
`jtcninja_video.v`. Scenes 0900 and 1500 render **pixel-correct** sprites
(both title cavemen, the gameplay cavemen/enemies, thrown wheels/clubs, score
popups), validated against `scenes/<n>/screen.png`.

**The decode fix that mattered.** The sprite ROM is RGN_FRAC(1,2) 4bpp with the
*same tilelayout as the tiles*, so it must be packed the same way: `mame2mra`
**raw** region (`mag-05|06|03|04` in order, no `width`/`sort_even`) + the game.v
`post_addr` rotate that moves the plane-half word bit (BA3 word bit19) to the
LSB, so one 32-bit read packs `{plane0,plane1,plane2,plane3}` exactly like the
tiles. The old `width=32 sort_even` interleaved low/high **tile ranges**, not
planes, so a single dword never held all 4 planes of 8 px → brick garble.
`jtcninja_obj` then reuses the verified tile plane order
`{d[31],d[23],d[15],d[7]}` (`>>`/LSB-first taps for hflip), `rom_addr =
{tile,~hflip(half),veff^{vflip}}`, and the cop `fresh` rom_ok handshake guard.

**Done:** position (`sx=240-x`, bottom=`256-ypos`), vertical multi-tile
(1/2/4/8 via `id_eff`), colour (`0x300+colour*16+pixel`), hflip/vflip, flash,
back-to-front via slot order, line buffer (`jtframe_obj_buffer DW=9`).

**TODO (next):** the `wide`/wing 2nd column (y[11], currently skipped); real
priority mixing (x[15:14] mask vs playfields — currently fg>obj>mg>bg); the
buffered_spriteram DMA double-buffer on `obj_copy` (scene replay reads the RAM
directly, so this only matters for live play). NB the garbled "CAVEMAN NINJA"
stone logo in scene 900 is the **char/fg layer** (separate, known-deferred
big-title bug), not sprites — confirmed by rendering with the fg layer off.

## Implementation plan (`jtcninja_obj.v`)

Base: **`cores/cop/hdl/jtcop_obj{,_draw,_buffer}.v`** (same DECO family). Deltas
to apply for cninja's decospr:

1. **Word layout / placement**: cop uses `ypos = 256 - tbl[8:0]`; cninja decospr
   uses `sy = 240 - ypos`, `sx = 240 - xpos`. Pull colour/priority from the
   **x word** (`(x>>9)&0x1f`, `x[15:14]`), not from a separate attr word.
2. **Multi-height**: `multi = (1<<bitswap2(y,10,9))-1` (1/2/4/8), `tile &= ~multi`,
   walk `multi+1` rows upward; the **wide/wing** bit (y[11]) adds the second column.
3. **ROM decode**: identical 4bpp planar tile decode to the tiles (reuse the
   verified `{d[31],d[23],d[15],d[7]}` plane order + the post_addr remap; sprites
   are their own SDRAM bank BA3, mind the same word-unit SLOT offset rule).
4. **Palette**: `pal_idx = 0x300 + colour*16 + pixel` (gfx base 768). In colmix,
   pen-0 transparent; sprites composite per the priority mask above.
5. **Double-buffer**: copy spriteram on the DMA-flag write (0x1b4000); the video
   reads the buffer. (`jtcninja_main` already exposes `obj_copy`.)

Validate with **scene replay** (`jtsim -s ../cninja/scenes/1500`) against
`sim_results/m01500.png` — and isolate sprites by comparing the sprite layer in
the scene to MAME's actual frame. Iterate position → tile → colour → multi-size →
priority.
