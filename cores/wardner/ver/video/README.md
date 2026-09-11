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

The three layers are `jtframe_scroll`, which adds the scroll to the screen
position and mirrors by inverting that position rather than subtracting it from
a constant, so both formulas above fold into the value handed to `scrx`/`scry`:
`+64`/`+30` unflipped and `-67`/`-29` flipped. The horizontal constants carry a
further 9 over MAME's 55 because the module holds each tile eight pixels and
registers its output once more, and that correction lands the other way round
under mirroring. `XOR_HFLIP` mirrors each tile within itself when the screen is
flipped, which jtframe otherwise leaves to the tile's own attribute bit and
Toaplan has no bit for; `XOR_VFLIP` stays off because the vertical position
already counts backwards.

### Two flip behaviours that were doubted, and are now settled

Both of these used to be listed here as "matched to MAME but unlikely to be what
the board does". Both turned out to be right, and MAME with them.

1. **Sprites do not flip.** The sprite generator never reads the screen flip;
   `flipscreen_w` touches the tilemaps alone, so a flipped cabinet shows
   mirrored tilemaps over unmirrored sprites. Confirmed against the Kyuukyouku
   Tiger schematics jotego keeps in `cores/ktiger/sch`: the top sheet routes
   `FLIP` to `gfxa`, `memorias` and `misc` only. `object` has nineteen sheet
   pins and `FLIP` is not among them.
2. **The flipped view *is* a clean 180 degree mirror.** It looked displaced by 79
   pixels horizontally and 213 vertically, but that was an artefact of how it was
   measured - forcing `flip=1` on a frame captured unflipped, which leaves scroll
   values the software would never write in that state.

   Run the boot bench with the Flip Screen DIP on (`+dswa=2`; it is DSWA bit 1,
   and `flipscreen` is mainlatch bit 3, so the software reads the DIP and acts)
   and the game writes **scroll 79 lower horizontally and 213 lower vertically**,
   cancelling MAME's second offsets exactly:

   ```
   clean mirror = 55 + scrollx + (319 - screen_x)  = 374 + scrollx - screen_x
   MAME flipped = 453 + (scrollx - 79) - screen_x  = 374 + scrollx - screen_x
   ```

   At 16000 ms both runs have byte-identical text, background, foreground,
   palette and sprite RAM - only the scroll registers and the flip bit differ -
   so the two frames are the same screen. Rendering both without sprites and
   comparing the flipped one against the control rotated 180 degrees gives
   **0 of 76800 pixels different**.

So `set_scrolldx(-55, -134)` and `set_scrolldy(-30, -243)` are correct, and so is
this core. Note that `snapflip` below is displaced by construction for the same
reason: it is a valid test of the flip *path*, since the RTL and the reference
agree on it pixel for pixel, but it is not a picture of the flipped game.

### A fixed flipped snapshot

`fuzz.sh` covers both flip states at random, which is the stronger test, but a
named flipped frame of real gameplay is useful when bisecting. Make one from
any boot snapshot:

```
cp -r ../main/snap20000 ../main/snapflip
sed -i 's/^flip=0/flip=1/' ../main/snapflip/snap_regs.txt
rm -f ../main/snapflip/snap_regs.hex          # run.sh rebuilds it
./run.sh ../main/snapflip
```

Both the RTL and `render_ref.py` read `flip` from `snap_regs.txt`, so the
comparison stays honest. This is what caught `XOR_HFLIP` being missing when the
tile layers moved to `jtframe_scroll`: the fault was invisible in the composed
frame at 97 pixels, and isolating the layer with `+gfxen=2` showed it was really
1951, confined to rows 189-239 with the rest hidden behind other layers. Compare
layers in isolation before reading anything into a composed frame diff.

## Not yet

- Nothing outstanding on screen flip. A frame the game itself drew while flipped
  is obtained with `MAXIO=2000000 ./run.sh <rom dir> 20100 +dswa=2 +snap=16000`
  in `../main`, which takes about fifty minutes.
- Sprite time per line is 512 clocks of scan plus ~30 a sprite, out of 2676;
  more than ~70 sprites on one line sets `obj_ovf` and drops the rest. MAME
  has no such limit; the real board's is unknown.
- The touched-pixel vector is still 512 flip-flops, of which Quartus optimises
  away the 192 above x=319. The line buffer that used to sit beside it is now
  `jtframe_obj_buffer`; written by hand it needed two write ports on one array,
  which Quartus built out of logic to the tune of 11103 ALMs.
- Whether the touched-pixel rule belongs here at all. The Kyuukyouku Tiger
  schematics jotego keeps in `cores/ktiger/sch` show layer priority resolved by
  a 32x8 PROM whose five address lines are the three layer-opaque flags and the
  sprite's two priority bits, with no input for it, and a sprite line buffer
  twelve bits wide with no room to store it. See the note in the core's PR.

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
