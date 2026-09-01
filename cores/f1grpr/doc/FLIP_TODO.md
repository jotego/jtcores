# Screen flip - status and open items

Flip is implemented across the GGA family. turbofrc and aerofgtb are pixel exact.
f1grpr renders correctly enough to play but has a ~5% residual that is deliberately
left open - see "Open" below.

## Where it stands

| core / game | scene | result |
|---|---|---|
| pspike / turbofrc | m03600 | **0 px differ** |
| pspike / aerofgtb | m05100 | **0 px differ** (on its real 320x224 geometry) |
| f1grpr / f1gp | m03900f | 3930 of 76800 px (5%), best shift 0 / -1 line |
| f1grpr / f1gp | m01500 | sprites visibly off |
| pspike / pspikes | - | not tested (`visx=4`, never exercised) |

The **unflipped** renders match MAME 100%, so every pixel of the f1grpr residual below
is a flip defect - there is no baseline error to subtract.

## How it is built

Every correction is **twice the engine's own horizontal origin** - mirroring turns a
`+origin` into a `-origin`. Nothing is tuned by eye.

| axis | mechanism |
|---|---|
| tiles, along the line | `FLIP_HW(9)` + `scrx + hsize + 2*visx` |
| tiles, tile pixels | `XOR_HFLIP(1)` - the only XOR, the 8 pixel shift-out is serial and must reverse |
| tiles, across lines | `FLIP_VW(9)` + `scry + vsize`, `XOR_VFLIP(0)` |
| sprites | `~hdump + hsize + 2*xorg`, `~vrender + vsize`, no XOR |
| f1grpr fg | `~(hdump+HOFFSET) + hsize`, `~vdump + vsize`, no XOR |
| geometry | `hsize`/`vsize` straight off the GGA, so it follows the game |

Two rules earned the hard way:

- **An XOR is only needed where the pixel select is serial.** `jtframe_tilemap` shifts
  its 8 pixels out one at a time, so horizontal flip must reverse the shift. Its
  vertical row index, `jtf1grpr_fg`'s `case(heff[1:0])` and the sprite line buffer are
  all *direct indexes* - mirroring the raster already picks the right pixel, and
  XORing again cancels it and leaves the layer unmirrored.
- **An origin added before the mirror gets doubled; after the mirror it does not.**
  `visx` and `HOFFSET` sit in the raster, so they double. `xb0`/`xb1` and the sprite
  `yoffs` are applied to the object position afterwards and do not.

## The ROZ needs nothing - do not wire flip to it

Verified from the game, not from MAME (`mame_scripts/roz_flip_diff.lua`):

```
             gfxctrl   xcnt0 ycnt0 xvstep yvstep xhstep yhstep
flip OFF       00      fe40  ffb0   0000   0800   0800   0000
flip ON        20      0bd8  07d0   0000   f800   f800   0000
```

The game negates both step registers and moves the start to the opposite corner - it
writes the mirrored matrix itself. `jt053936.v` stays untouched (rungun, riders and
prmr share it), and **`flip` must not reach `u_roz`** or the road double flips.

The same run confirmed `gfxctrl` bit 5 is the flip bit, which MAME's "gfxctrl register
not understood" comment left in doubt.

## Testing

The DIP is sampled at boot, before an autoboot script runs, so it has to be set through
MAME's cfg file:

```xml
<port tag=":DSW2" type="DIPSWITCH" mask="512" defvalue="512" value="0" />
```

```bash
F1GP_SCENES=/tmp/f1gp_flipon F1GP_FIRST=3900 F1GP_COUNT=1 \
  mame f1gp -autoboot_script cores/f1grpr/ver/f1gp/mame_scripts/dump_burst.lua \
            -cfg_directory <dir with the cfg above>
```

`scenes/m03900f` is that capture, paired with the **flip-off** `screen.png` as its
reference - that is the upright picture a correct flipped render must reproduce. The
two captures are byte identical over all 313344 RAM bytes, so flip does not perturb
attract timing and the pairing is sound.

**A flip-off scene cannot validate f1grpr.** Our ROZ correctly ignores flip, so with an
unflipped matrix the road renders unflipped while `test.cpp` rotates the whole frame the
other way (`verilator/test.cpp:940`, `-rotate -90` when `dip_flip` is set) - the road
comes out 180 degrees wrong and swamps the diff. Chasing that cost three runs.

Run a check with:

```bash
MAMESET=f1gp ROMS_HOST=~/.mame/roms SIMARGS="-u JTFRAME_180SHIFT" \
  tools/scenesim/flip_check.sh f1grpr f1gp m03900f
```

## Open

1. **f1grpr residual, ~5% with a 1 line vertical offset.** Prime suspects are
   `VOFFSET = 8` in `jtf1grpr_fg.v` and `yoffs = 9'h1f8` on the sprite chips - the
   vertical twins of the 1 px horizontal origins that *did* need doubling
   (`HOFFSET = 1`, `xoffs = -1` -> `xorg = 1`). They were left alone because the
   horizontal-only run measured 0 across, but that run had the road wrong, so the
   measurement was not trustworthy. Re-measure on `m03900f` before changing anything.
   Since unflipped is pixel exact against MAME, all 3930 px are attributable to flip.
2. **f1grpr sprites are off in m01500** and fine elsewhere. Different scene, different
   sprite mix - worth checking whether it is zoomed sprites specifically, since the
   zoom accumulator rounds and would not survive an exact-match test.
3. **pspikes is untested.** It is the only game with a non-zero `visx` (4) that has not
   been checked, and it is the one-layer/one-sprite-chip layout, so it exercises a
   different path.
4. **Only aerofgtb scenes carry GGA registers.** turbofrc and pspikes scenes replay on
   the 352x240 reset defaults, which happens to be right for them. The capture and the
   `rest2bin.sh` plumbing now exist for all of them - it is one `dump_burst.lua` rerun
   per game.
5. Some `cores/f1grpr/ver/f1gp/sim_results/*.png` predate the GGA `246 -> 240` crop and
   are 6 lines taller than anything rendered today - `m01500.png` is one. Regenerate
   before comparing against them.

`flip_check.sh` writes `sim_results/<scene>_flip.png` and
`sim_results/diffs/<scene>_flip_compare.png`, deliberately separate from the unflipped
`<scene>.png` baselines that are graded against MAME.

## Accepted: sprite pixels at screen x=0 (NOT a flip bug)

The first pixel of every scanline shows the layer *below* the sprites. Visible on
f1grpr and on aerofgtb, in the **unflipped** path, so it predates all the flip work.
Left in deliberately - the cost of chasing it is out of proportion to one column.

Measured on `f1gp` m02159: 151 of 76800 px differ from MAME, **all on image row 0**,
every other pixel bit exact.

What it is not, each established by measurement rather than argument:

- **Not a fetch or a clip.** The scene's sprite list has four live SPR-1 sprites
  starting at exactly x=0, 128 px wide (slots 0x50/0x5c/0x68/0x74). They are in the
  list, enabled, and on screen. SPR-2 has no live sprites in that scene at all.
- **Not a shift.** Everything except that one column matches MAME exactly, so the
  layer is correctly positioned. Anything that moves the readout is therefore wrong
  by construction - which both attempted fixes proved:

  | | m01500 | m02159 |
  |---|---|---|
  | as committed | 0 | 151 |
  | sprite hdump +1 (a `P_OBJ` style lead) | 10583 | 18054 |
  | `HFIX(1)` on `jtpspike_obj` | 1192 | 11224 |

**Best lead: the sprite wrap.** In gameplay the symptom is that as cars move off the
grid, the top line of pixels re-enters from the opposite edge - that is a wrap, not a
missing pixel. `vsystem_spr2` draws every sprite four times, at `sx-0x000`/`sx-0x200`
and `sy-0x000`/`sy-0x200`, so sprites wrap at 512 on both axes; a one line residue at
the far edge is what a mismatched wrap looks like. Capture a gameplay scene with
`mame_scripts/dump_key.lua` (press `/`) at the moment it shows, and compare the sprite
list against what we draw.

A weaker second suspicion is how the first `rd` of a line is primed:
`jtframe_obj_buffer` returns `rd_data` two clocks after `rd` (`BLANK_DLY=2`), and x=0
is the only pixel with no preceding `rd` in the visible line. That lives in jtframe,
shared with every core, so it is not something to poke casually.

**Testing note.** `m01500` cannot validate this - it has 15 live sprites and none
covering x=0. It is still the right regression guard, because it catches a layer
shift instantly (0 -> 10583 above). `m02159` is the only scene that exercises x=0.
Both are needed; neither is sufficient alone.
