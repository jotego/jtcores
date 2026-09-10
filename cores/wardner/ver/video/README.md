# Wardner video — frame bench

`cores/wardner/hdl/jtwardner_video.v`: the raster (446×286, 320×240 visible),
three tilemap engines, the sprite line buffer and the priority mixer.

## The reference

`render_ref.py` is a transcription of MAME 0.289's `twincobr_v.cpp`
`screen_update`, `toaplan_scu.cpp` `draw_sprites_common` and the parts of
`tilemap.cpp` / `drawgfxt.ipp` they rely on, applied to a snapshot of the video
RAMs. Everything that is not obvious from the hardware is a checked MAME
behaviour, listed at the top of the script with the source file it came from.
Nothing in it is recalled from memory.

The RTL is diffed against it pixel for pixel. This is the same method as the
DSP work: an independent model transcribed from MAME, then a mechanical
comparison, then deliberate mutations to prove the comparison bites.

## Running it

```
python3 mkgfx.py <rom dir>                    # gfx_*.hex, MAME region layout (not committed)
MAXIO=20000000 ../main/run.sh <rom dir> 31000 \
    +snap=2000,4000,6000,9000,12000,16000,20000,25000,30000
./run.sh ../main/snap25000                    # RTL frame vs reference, writes rtl/ref/diff.ppm
./fuzz.sh 30 1                                # random snapshots; seeds >= 1000 are dense
python3 ppm2png.py ../main/snap25000/ref.ppm ref.png 2    # to look at one
```

One boot leaves every snapshot in the list behind, in `snap<ms>/`. Those
milliseconds are the boot bench's own, which run 2.381 times faster than the
board; divide by 0.42 for board time. Reaching 30 s of them takes about 65
minutes. `MAXIO` has to be raised because the default port-write cap stops the
run after about four seconds of attract mode.

`+lat=N` adds N clocks of ROM latency; the ROM models drop `rom_ok` as soon as
the address changes, the way the SDRAM controller will.

## What is verified

- **Nine snapshots taken across 30 s of one attract run, all pixel-exact**,
  including two frames of the attract demo actually playing:

  | snapshot | board time | what is on screen | sprites drawn |
  |---|---|---|---|
  | `snap2000`  |  4.8 s | text-layer glyph grid, one sprite at the left edge |  48 |
  | `snap4000`  |  9.5 s | tile test, background over text          | 114 |
  | `snap6000`  | 14.3 s | tile test                                | 114 |
  | `snap9000`  | 21.4 s | tile test, foreground bank filled        | 114 |
  | `snap12000` | 28.6 s | GFX ROM test checkerboard                | 114 |
  | `snap16000` | 38.1 s | high-score table                         | 114 |
  | `snap20000` | 47.6 s | **gameplay**, forest, enemies, GAME OVER overlay | 111 |
  | `snap25000` | 59.5 s | **gameplay**, player, two enemies, chest, HUD | 104 |
  | `snap30000` | 71.4 s | title screen                             | 102 |

  `snap20000` and `snap25000` are the first frames ever rendered here that
  carry sprites over a populated foreground layer: 111 and 104 sprites with a
  non-zero priority, 2040 and 1811 non-blank foreground words, three scroll
  positions all different (text 457,226; background 663,498; foreground
  870,498 on `snap25000`). Both match the reference exactly at ROM latency 0,
  1, 2, 3 and 4. `snap12000` is the same GFX ROM test checkerboard that MAME
  0.289 shows at 28 s, which is an independent check that the bench's timeline
  and MAME's agree.

  The five earlier snapshots this bench was first verified against are still
  valid but were mislabelled: a 32-bit overflow in the freeze delay meant
  `+snap=14000` actually froze the game at 1115 ms, so the "14 s title screen"
  was taken 1.1 s in. That is why none of them held a sprite. See the boot
  bench's README.
- Random snapshots covering scroll wrap in both axes, both bank bits, both
  screen-flip states, all four sprite priorities, both sprite flips, edge
  positions (y = 0x100, x < 0, partial clip) and 512 overlapping sprites: all
  match exactly, with ROM latency 0-4. The 72 random snapshots run so far
  split 33 unflipped / 39 flipped.
- The sprite/tilemap rule is MAME's pmask one: priority 1 hidden by fg or text,
  2 by text, 3 never, 0 skipped; and every pixel a sprite touches becomes
  priority 31 whether it drew or not, so a later (lower-numbered, on-top)
  sprite there is never hidden. The RTL carries that as a "multi" bit in the
  line buffer. Rendering the reference with `--no-pri31` differs from the RTL
  on 5366 pixels of the dense seed 1000 and on 4 pixels of `snap25000`, so the
  quirk is exercised by the real game as well as by the fuzz.
- Deliberate RTL mutations each differ on thousands of pixels: sprite flipx
  offset dropped (20689), priority-2 rule ignoring text (5081), multi bit stuck
  at 0 (5368), scroll offset 55→54 (34188). Five more against the flip path, on
  a flipped snapshot: horizontal offset off by one (44202), vertical offset off
  by one (42757), scan direction not reversed (55040), tile phase not swapped
  (54203), flip ignored in x (68623).

## Screen flip

`flipscreen_w` sets `TILEMAP_FLIPX|TILEMAP_FLIPY` on all three tilemaps and
does nothing else. In `tilemap.cpp` that mirrors the pixmap end to end
(`mappings_update` swaps tile positions, `tile_update` XORs each tile's own
flip bits) and switches `effective_rowscroll` / `effective_colscroll` to the
second offsets from `set_scrolldx(-55, -134)` / `set_scrolldy(-30, -243)`.

Sampling the unflipped pixmap at `(W-1-px, H-1-py)` folds the mirror and the
offset together, and the map size cancels out of the result:

```
unflipped   px = (55  + scrollx + screen_x) mod W
            py = (30  + scrolly + screen_y) mod H
flipped     px = (453 + scrollx - screen_x) mod W
            py = (482 + scrolly - screen_y) mod H
```

so the RTL only reverses the direction it walks the map: `col_nxt` counts down,
and the first and last pixel of a tile swap. Pixel sampling is untouched.

### Two flip behaviours matched to MAME but unverified on hardware

1. **Sprites do not flip.** The sprite generator never reads the screen flip;
   `flipscreen_w` touches the tilemaps alone. So in MAME a flipped Wardner
   shows mirrored tilemaps over unmirrored sprites. That is reproduced here so
   the diff stays meaningful, but it is unlikely to be what the board does.
2. **The flipped view is not a 180 degree mirror of the unflipped one.** It is
   displaced by a constant 79 pixels horizontally and 213 vertically, which is
   what the `-134` / `-243` offsets give against `-55` / `-30`. Wardner and the
   Twin Cobra family share the same 446x286 raster, so this is not a geometry
   artefact. The flipped title screen visibly runs off the right edge.

Both should be checked against a real board, or with jotego, before cocktail
mode is offered to players. Changing either means changing `render_ref.py` and
the RTL together, and the harness will confirm they still agree.

## Not yet

- A **flipped** frame of real gameplay. Every snapshot from the running game so
  far has `flip=0`; the flip path is covered only by the 39 flipped random
  snapshots. Nothing in the game turns flip on by itself - it is the cabinet
  DIP - so this needs the boot bench run with that switch set.
- Sprite time per line is 512 clocks of scan plus ~30 a sprite, out of 2676;
  more than ~70 sprites on one line sets `obj_ovf` and drops the rest. MAME
  has no such limit; the real board's is unknown.
- Synthesis mapping: the line buffer has two write ports as written and the
  touched-pixel vector is 512 flip-flops; both to be moved on to jtframe
  memories when the core is assembled.

## Note for the core build

`cfg/mame2mra.toml` interleaves the tile and sprite planes into 32-bit words
so one SDRAM read is one 8-pixel row. **That interleave is now verified**
(2026-09-08): with `doc/mame.xml` regenerated so it carries the Wardner
machines, `jtframe mra wardner` produces a `.rom` whose char, bg, fg and obj
regions match `ver/game/mkrom.py`'s image byte for byte, and that image is the
one the video engine is pixel-exact against.

The files in this directory are the ground truth for it. `gfx_*.hex` is built
by `mkgfx.py` straight from the MAME regions, and the video RTL is pixel-exact
against MAME while reading them, so the byte order they use is correct by
construction. To check the MRA on a machine that has MAME:

1. refresh `doc/mame.xml` so it contains the Wardner sets,
2. `jtframe mra wardner` and build the `.rom`,
3. compare the `.rom` at `JTFRAME_BA2_START` and `JTFRAME_BA3_START` against
   `gfx_chars.bin`, `gfx_bg.bin`, `gfx_fg.bin` and `gfx_obj.bin` interleaved
   four bytes at a time, plane 0 in the low byte.

They agreed. The one region that did not was the DSP's, which was byte
reversed because MAME holds it in a `ROM_REGION16_BE` while jtframe's download
fills 16-bit words low byte first; `width=16, reverse=true` on that region
fixed it. As predicted, the fix was in the TOML and not the RTL.
