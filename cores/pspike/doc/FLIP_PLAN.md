# jtpspike - screen flip support

> **SUPERSEDED - kept for the reasoning, not the prescriptions.**
> Written before flip was implemented. Two of its recommendations turned out to be
> wrong when measured: it prescribes `XOR_VFLIP(1)` (must be 0 - the tile row is a
> direct index, so mirroring `veff` already picks it) and a `2*lead` scroll term (the
> pipeline lead cancels; the correction is `2*visx`). For what actually works, and the
> rules behind it, see `cores/f1grpr/doc/FLIP_TODO.md`.

Plan only. Nothing implemented yet.

## Premise: MAME is not a reference here

Every machine in `pspikes.cpp` carries `MACHINE_NO_COCKTAIL` - all four spinlbrk
sets, all four pspikes sets, all five karatblz sets, turbofrc and aerofgtb. So MAME
declares cocktail/flip unsupported for the whole driver.

There *is* code: `turbofrc_flip_screen_w` and `spinlbrk_flip_screen_w` call
`set_flip(TILEMAP_FLIPX|TILEMAP_FLIPY)`, `vsystem_spr2` takes a `flip_screen`
argument, and `screen_update_turbofrc` carries flip-only offsets. But look at them:

```c
m_tilemap[0]->set_scrollx(..., m_rasterram[7] - 11 - (m_flip_screen ? 188 : 0));
m_tilemap[0]->set_scrolly(0,   scrolly        -       (m_flip_screen ?   2 : 0));
m_tilemap[1]->set_scrollx(0,   m_scrollx[1]   -       (m_flip_screen ? 185 : 7));
m_tilemap[1]->set_scrolly(0,   m_scrolly[1]   +       (m_flip_screen ?   0 : 2));
```

and in `vsystem_spr2.cpp:164`:

```c
if (flip_screen) { m_curr_sprite.ox = 308 - m_curr_sprite.ox;
                   m_curr_sprite.oy = 208 - m_curr_sprite.oy; }
```

188, 185, 308, 208 are hand-tuned constants, `308` and `208` are shared across every
game the device serves regardless of screen width, and the driver is flagged
NO_COCKTAIL anyway. **Treat these as a hint about which quantities need correcting,
never as values to copy.** We derive our own below.

Every game exposes the feature, so all five families need it:

| game | DIP |
|---|---|
| pspikes | SW1:8 |
| karatblz | SW2:8 |
| spinlbrk | SW2:4 |
| turbofrc | SW2:1 |
| aerofgtb | SW2:1 |

The DIP is read by the game code, which then writes the flip register bit. Nothing
special is needed on the input side - `flip` already arrives in `_main.v` from
`fff001` bit 7 (pspikes), `0ff001` bit 7 (turbofrc/aerofgt), `0ff000` bit 15
(karatblz).

## Where the core is now

`flip` is routed everywhere and does **almost nothing**.

| consumer | state |
|---|---|
| `jtpspike_video.v` -> `u_scr` / `u_scr1` `.flip(flip)` | reaches `jtframe_scroll`, but with the flip parameters at their defaults it mirrors the wrong window and never mirrors the tiles |
| `jtpspike_video.v` -> `u_obj` / `u_obj1` `.flip(flip)` | reaches `jtframe_objdraw` (line buffer mirror, `FLIP_OFFSET` unset) and `jtpspike_objscan` |
| `jtpspike_objscan.v:62` `input flip` | **declared and used nowhere.** A dangling port |
| `jtpspike_game.v:38` `assign dip_flip = flip;` | already driven, polarity unverified |

So today, turning flip on produces a partly-mirrored, misaligned picture rather than
no change at all - which is worse than nothing and is why it was deferred.

## The machinery jtframe already provides

Three separate mechanisms, all driven by the same `flip` input:

**1. Raster mirroring for tilemaps** - `jtframe_scroll_offset.v:52`

```verilog
hdf = {blank,hdfix} ^ { {HDW-FLIP_HW{1'b0}}, {FLIP_HW{flip}} };
vdf = vdump         ^ { {VDW-FLIP_VW{1'b0}}, {FLIP_VW{flip}} };
```

Inverts the low `FLIP_HW`/`FLIP_VW` bits of the scan position. Defaults are 8/8.

**2. Tile mirroring** - `jtframe_tilemap.v:98`

```verilog
assign xhflip  = (flip & XOR_HFLIP[0])^hflip;
assign vflip_g = (flip & XOR_VFLIP[0])^vflip;
```

Only active if `XOR_HFLIP`/`XOR_VFLIP` are set to 1. **Both default to 0**, and
`jtpspike_scr.v` leaves them at the default while passing `hflip(1'b0)`,
`vflip(1'b0)`. So the individual 8x8 tiles are never mirrored - the map is
rearranged but each tile still draws left-to-right. That alone makes flip wrong.

**3. Sprite line-buffer mirroring** - `jtframe_obj_buffer.v:93` and
`jtframe_objdraw_gate.v:145`

```verilog
wr_af = flip ? ~wr_addr + FLIP_OFFSET[AW-1:0] : wr_addr;   // write side
hdf   = flip ? ~hdfix   + FLIP_OFFSET[8:0]    : hdfix;     // read side
```

`FLIP_OFFSET` defaults to 0 and `jtpspike_obj.v` does not set it.

There is **no vertical mechanism for sprites** in jtframe - a line buffer holds one
line, so vertical flip has to come from the line index fed to the scanner.

## The width problem, and why the defaults are wrong

This is the part that matters, and it is why MAME needed magic numbers.

Our raster is **352x240 visible on a 456x256 grid**, and the tilemap is 64x64 of
8x8 = **512x512** (`MAP_HW = MAP_VW = 9`).

With `FLIP_HW = 8` the XOR inverts within a **256**-wide window: `hdump ^ 0xFF`
gives `255 - hdump`. Our visible line is 352 wide. Wrong window, and the top bit is
left un-inverted, so the picture folds rather than mirrors.

Set `FLIP_HW = 9` and the XOR gives `511 - hdump`, a clean mirror in the map's own
space. Then work out the constant. Non-flip, a pixel at screen `x` reads

```
heff = (x + lead) + scrx
```

where `lead` is `hoff_scr` (`visx + P_SCR`). Under flip, screen `x` must show what
screen `W-1-x` shows unflipped:

```
heff_flip = 511 - (x + lead) + scrx'   ==   (W-1-x + lead) + scrx
      ->   scrx' = scrx + (W-1) + 2*lead - 511
```

With `W = 352`: **`scrx' = scrx + 2*lead - 160`**.

Vertically there is no lead, `FLIP_VW = 9` on a 256-line grid with 240 visible:

```
veff_flip = 255 - v + scry'   ==   (239 - v) + scry
      ->   scry' = scry - 16
```

Note that MAME drops the `+2` scrolly bias exactly when flip is on
(`scrolly + (flip ? 0 : 2)`) - the same kind of constant, arrived at by hand.

Both corrections are **derivable from the raster**, not tunable. Every one of them
changes with the game, because `visx` and `W` do: pspikes 4, turbofrc 0, karatblz 8,
aerofgtb 12, and aerofgtb's window is 320 wide, not 352. Put the flip corrections in
the same per-game table as `visx`/`xb0`/`xb1` in `_video.v` - do not scatter them.

## What carries over from cal50

cal50 solved the same problem with the **"mirror the raster"** strategy: leave the
object coordinates alone and flip the scan position going into the engines
(`jtcal50_video.v:162`):

```verilog
wire [8:0] vdump_adj   = vdump   + (flip ? OBJ_VOFF : OBJ_VOFF_F),
           vrender_adj = vrender + (flip ? OBJ_VOFF : OBJ_VOFF_F),
           hdump_adj   = hdump   + (flip ? OBJ_HOFF : OBJ_HOFF_F);
```

with a pair of constants per axis, one for each flip state
(`OBJ_VOFF = 18 / OBJ_VOFF_F = -4`, `OBJ_HOFF = -4 / OBJ_HOFF_F = -7`), and `flip`
passed down into the gfx engine so the per-tile attributes get XORed.

That transfers directly. The alternative - MAME's **"mirror the coordinates"**
(`ox = 308 - ox`) - does not fit jtframe, whose primitives are built for the raster
strategy. **Pick one and do not mix them**, or the sprites end up flipped twice.

Recommendation: raster strategy throughout, matching cal50 and jtframe.

## Work items

### 1. Tile layers - `jtpspike_scr.v`

- `XOR_HFLIP(1)`, `XOR_VFLIP(1)` on the `jtframe_scroll` instance, so screen flip
  mirrors each tile. The `hflip`/`vflip` inputs stay tied low - this family has no
  per-tile flip bits.
- `FLIP_HW(9)`, `FLIP_VW(9)` - mirror in the map's own 512-wide space.
- Add the flip corrections to `scrx_eff` / `scry_eff` using the formulas above,
  fed from the per-game table.
- Careful with `LATCH_SCRX(1)` and the `hdump_scr` wrap at `H >= 400`: that
  subtraction was added to keep the fetch tick alive across the 456->512 jump, and
  it is applied *before* the XOR. Verify the fetch tick still fires in flip -
  the left-edge band bug will come straight back if it does not.
- pspikes' per-line raster (`ras_addr = vdump[7:0]`) must be indexed by the
  **flipped** line, otherwise the per-line scroll follows the screen instead of the
  picture. This is the one place where the raster strategy needs an explicit change.

### 2. Sprites - `jtpspike_objscan.v`

- Use the dangling `flip` input:

  ```verilog
  hflip <= d_fx ^ flip;
  vflip <= d_fy ^ flip;
  ```

  and use the XORed values in `maprow`/`mapcol` (line 227-229), not the raw
  `d_fx`/`d_fy`. That reverses the multi-cell walk direction under flip, which is
  what MAME expresses as `(flip_screen ? -cy : cy)`.
- Feed `u_scan` a flipped `vrender` from `_video.v`, cal50 style, so the sprite's
  Y comparison lands on the mirrored line.

### 3. Sprites - `jtpspike_obj.v`

- Set `FLIP_OFFSET` on `jtframe_objdraw`. Same derivation as the tilemap: with a
  9-bit buffer, `~a + OFF` must equal `W-1-a`, so `OFF = W - 512`, i.e. **352 mod
  512** for the 352-wide games and **320** for aerofgtb. Per-game, from the table.
- Do **not** also mirror `xpos` in the scanner. The buffer mirror already does it.

### 4. Top level - `jtpspike_video.v` / `_game.v`

- Extend the per-game constant table with the flip corrections (item 1) and
  `FLIP_OFFSET` (item 3).
- `assign dip_flip = flip;` already exists in `_game.v:38`. cal50 uses `~flip`.
  `jtframe_dip.v:123` does `rotate <= { dip_flip ^ dipflip_xor, ... }`, so the
  polarity decides whether the OSD rotation cancels or doubles the game's flip.
  Determine it empirically once the picture is right, and note that this core is
  `JTFRAME_VERTICAL` with rotation as a per-MRA coremod flag - check both
  orientations.
- The GGA is untouched. Flip is a rendering transform here, not a raster one; the
  counters keep running the same way.

## Verifying without a reference

MAME cannot arbitrate this. But flip has an exact specification that needs no
reference at all:

> For a static scene, the flipped render must be the **unflipped render rotated
> 180 degrees**, pixel for pixel.

That is the whole definition of screen flip, and it is mechanically checkable with
the scene-replay rig that already exists:

1. Take a committed scene (`cores/pspike/ver/turbofrc/scenes/mXXXXX`).
2. `regs.bin` carries `flip` in bit 7 of byte 0 - render it twice, once with the bit
   clear and once set. No new MAME capture is needed.
3. Rotate the flipped PNG 180 degrees and diff against the unflipped one.
4. **Pixel-exact or it is wrong.**

The failure mode is diagnostic rather than mysterious: a uniform offset in the diff
gives you the missing constant directly, and its size tells you which item above is
at fault (a whole-picture shift is the `scrx'`/`scry'` correction; sprites shifted
relative to tiles is `FLIP_OFFSET`; tiles individually reversed inside a correct
layout is `XOR_HFLIP`/`XOR_VFLIP`).

Run it for pspikes and turbofrc, which have committed scenes, and for both layers
separately using the existing `SIM_ONLY_SCR0`/`SIM_ONLY_SCR1`/`SIM_ONLY_OBJ` defines
in `_video.v` - isolating a layer turns a compound offset into a single number.

Caveats on the invariant, all real but none fatal:

- **Zoomed sprites** may differ by a pixel from rounding in the zoom accumulator.
  Pick scenes without active zoom for the pixel-exact pass.
- **Wrapping sprites** at the screen edges: MAME's `& 0x1ff` wrap means a sprite
  straddling the edge appears on the opposite side, and the invariant still holds,
  but only if the wrap width matches.
- Coverage gap already recorded in `STATUS.md`: **`flip` is 0 in every committed
  scene** and pspikes' `scrolly` is 0 in all 20. Flip against a zero scroll will not
  catch the `scry'` correction. Capture two or three new scenes with a non-zero
  scroll first - `dump_key.lua` in the f1grpr tree is the model for a keypress
  capture and can be ported in an afternoon.

## Order of work

1. Capture 2-3 turbofrc scenes with non-zero scroll on both axes.
2. Build the 180-degree comparison script into `tools/scenesim/` next to
   `build_diffs.py`.
3. Tile layers (item 1), verified per layer with `SIM_ONLY_SCR0` / `SIM_ONLY_SCR1`.
4. Sprites (items 2 and 3), verified with `SIM_ONLY_OBJ`.
5. Full mix, all scenes, both games.
6. `dip_flip` polarity and the rotated-cabinet check on hardware.

Items 3 and 4 are independent and can be done in either order. Do **not** start
before step 2 exists - the whole point is that this feature has an exact test, and
tuning constants by eye is how MAME ended up with 188 and 185.
