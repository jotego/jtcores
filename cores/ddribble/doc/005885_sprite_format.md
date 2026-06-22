# 005885 sprite (OBJ) format — ddribble — verification notes

Status: **diagnostic, not yet implemented.** No HDL changed for this doc.
This captures the authoritative ddribble sprite byte layout and exactly
where our current sprite engine (`jtddribble_5885_7121_obj.v`, a 007121
engine) diverges, so the next session can fix the obj engine from data.

## Why the OBJ COLOR row is still wrong

Two fixes already landed and are correct but **not sufficient**:
1. Sprite-half ROM routing (OBJSTART/OBJMASK) — sends sprite fetches to
   the sprite ROM bank. Schematic-grounded, verified the fetched data
   changed (blue→green+blue streaks). ✓ keep.
2. byte[4] bit positions gated to MODE_5885 (size `[4:2]`, hflip `[5]`,
   vflip `[6]`). Correct per MAME + Iron Horse ref, but produced **no
   visible change** on the COLOR TEST page — because those test sprites
   have byte[4]≈0, so the size bits read the same either way.

The remaining, dominant divergence is the **sprite tile-code construction
and multi-tile expansion**, which is structurally different between the
007121 (our engine) and the 005885 (ddribble).

## Authoritative ddribble sprite format

Source: MAME `konami/ddribble.cpp` `draw_sprites()` (the same game, so this
is more directly authoritative than the Iron Horse 005885 reference).
5 bytes per sprite. `source[0..4]`:

```
byte[0] = code[7:0]
byte[1] = [7:4] color   [2:0] code[10:8]          (code is 11 bits total)
byte[2] = Y[7:0]
byte[3] = X[7:0]
byte[4] = bit0 X[8]   [4:2] size   bit5 flipx(0x20)   bit6 flipy(0x40)
```

Size field (`attr & 0x1c`) and the base-code mask MAME applies:
```
0x10 -> 32x32   number &= ~3
0x08 -> 16x32   number &= ~2
0x04 -> 32x16   number &= ~1
else -> 16x16   (no mask)
```

Multi-tile expansion: sprites are decoded from **16x16** gfx tiles
(`spritelayout`). For a w×h sprite (in 16x16 units):
```
tile = number + x_offset[ex] + y_offset[ey]
  x_offset[2] = {0x00, 0x01}     y_offset[2] = {0x00, 0x02}
  ex = flipx ? (width-1-x)  : x
  ey = flipy ? (height-1-y) : y
draw at  (sx + x*16, sy + y*16)
```
So the sub-tile index is `number + x + 2*y` (with flip mirroring), and the
final on-ROM address indexes **16x16 sprite tiles**, not 8x8.

Compositing (screen_update):
```
bg_tilemap (chip2)              <- back
draw_sprites(spriteram[0], 0x07d, gfxset 2 = gfx1@0x20000)   chip 1 OBJ
draw_sprites(spriteram[1], 0x140, gfxset 3 = gfx2@0x40000)   chip 2 OBJ
fg_tilemap (chip1)             <- front
```

## How our engine differs (jtddribble_5885_7121_obj.v)

Our 007121 engine builds `code` and walks sub-tiles at **8x8** granularity:
```
code[9:2] <= byte[0]          (st3)         <- WRONG base mapping for 005885
code[11:10] <= byte[1][1:0]   (st4)         <- 005885 uses byte[1][2:0]=code[10:8]
code[1:0] <= size-derived sub-tile bits     <- 005885 has no code[1:0] from RAM
code[13:12] <= byte[4][7:6]   (now 0 in 5885)
rom_addr = { code, vsub[2:0], h4 }          <- 8x8-row addressing + st8 walk
```

Key mismatches vs ddribble's actual format:
- **Base code**: ddribble = `{byte1[2:0], byte0}` (11-bit, indexing 16x16
  tiles). Ours = `code[9:2]=byte0` + `code[11:10]=byte1[1:0]` (8x8 scheme,
  low bits repurposed for sub-tile position). Completely different.
- **Sub-tile expansion**: ddribble = `number + x + 2*y` over 16x16 tiles.
  Ours = `code[3:0]` size bits + `st8` increment over 8x8 tiles.
- **Color/size byte split** otherwise matches once byte[4] is gated (done).

## HDL status (MODE_5885-gated)

gfx layout (ddribble.cpp charlayout/spritelayout) pins the addressing:
- 8x8 tile = 32 bytes; 16x16 sprite tile = 128 bytes = 4 quadrants
  (TL=0, TR=1, BL=2, BR=3), each a 32-byte 8x8.
- So the 8x8-tile index = `number*4 + quadrant`, i.e. for the engine's
  8x8-granular `code`: `code[1:0]=quadrant`, `code[12:2]=number[10:0]`.

For **16x16 sprites** (the common case) the 007121 and 005885 engines have
the *same* structure — 16x16-indexed with a quadrant walk in `code[1:0]` —
and differ ONLY in how the base number's high bits are built:
- 007121: `code[11:10]=byte1[1:0]`, `code[13:12]=byte4[7:6]`
- 005885: `code[12:10]=byte1[2:0]`, `code[13]=0`

**DONE (2026-06-15):** `st4` now sets `code[12:10]=byte1[2:0]` under
MODE_5885 (st1 already forces code[13:12]=0). This makes the 16x16 base
number correct = `{byte1[2:0], byte0}`. Verifying with a 5000-frame plain
attract sim.

**STILL PENDING (larger sprites):** the size field semantics differ and
need a MODE_5885 size table:
- 005885 byte4[4:2]: `100`=32x32, `010`=16x32 (16 wide × 32 tall),
  `001`=32x16, `000`=16x16, with `number &= ~mask`.
- the 007121 `size_cnt`/`height_comb`/`code[3:0]` walk does NOT match these
  (e.g. it makes 16x32 only 16 tall). Multi-16x16 expansion is
  `number + x_offset + y_offset` (x∈{0,1}, y∈{0,2}).
If 16x16 sprites render right but big sprites (ball, special) are wrong,
that's this pending piece.

Keep the 007121 path untouched for contra et al. (all changes gated).

## Ground-truth capture (this session's deliverable)

`mame_scripts/dump_sprites.lua` + `dump_sprites.sh` dump the REAL 005885's
sprite RAM (both chips), tile RAM, a screenshot, and a human-readable
decode (per the format above) at a spread of attract frames. Run:

```
cores/ddribble/ver/ddribble/mame_scripts/dump_sprites.sh
# -> cores/ddribble/ver/ddribble/scenes/mame_<frame>/{spr0,spr1,...}.bin
#    + screen.png + sprites.txt
```

Pick a frame whose `screen.png` shows a clear player sprite, read its
`sprites.txt` decode, and confirm the rewritten HDL produces the same
tile/position. This gives byte→render pairs to validate against instead of
guessing.

### Finding from the first dump run (2026-06-15)

Ran the dumper over plain attract (no coin), frames 300–3600. Result:
**FG tile RAM populated (~129 nonzero rows), but BG tile RAM and BOTH
sprite RAMs are completely empty at every sampled frame.** Verified the
tool is correct, not broken: a probe read the maincpu reset vector
(`$FFFE/FFFF = E4 AD`, ROM, nonzero) and FG VRAM (`$2401 = 10`), so the
Lua mem handle and reads work — the zeros are real game state.

Conclusion: **ddribble's pure attract (first ~60 s, no credit) is a
FG-tilemap-only title/text screen — no sprites, no BG.** The sprites we
need as ground truth come from either:
  - the **service-mode COLOR TEST** page (deterministic 7 OBJ sprites), or
  - an **actual played/demo game** (player sprites + BG court).

So to capture sprite ground truth, the dump must run with **service mode
enabled** (then navigate to OBJ COLOR), or after coining-up and starting a
game. Service mode on ddribble = DSW3 bit 2 (PORT_SERVICE_DIPLOC SW3:3).
Headless DIP-set from Lua wasn't nailed down this session (ioport field
enumeration needs the right MAME 0.276 API); easiest path for now is to
run MAME interactively, press **F2** for service mode, reach the OBJ COLOR
test, then run the dump — or add a MAME `.cfg` with the service DIP set.

`screen.png` is **black** under `-video none` (no rendered bitmap); rerun
without `-video none` if a visual reference is needed (opens a window).

## Address instrumentation result (2026-06-15) — addressing is CORRECT

Instrumented the obj engine's computed `rom_addr` (MODE_5885). Across 800
logged fetches, the address is exactly:

    rom_addr = number*64 + quad*16 + vsub*2 + h4    (0 mismatches / 800)

i.e. `{number[10:0], quad[1:0], vsub[2:0], h4}`, which matches the gfx2
spritelayout precisely (16x16 = 128 B = 64 words; quadrant TL/TR/BL/BR =
32 B = 16 words; row = 4 B = 2 words; h4 = 1 word). Since the gfx blob is
byte-perfect (= byteswap16(MAME region)), the sprite engine therefore
fetches the CORRECT ROM bytes. **Sprite addressing is not the bug.**

Caveat: the only numbers captured were 0x7fc/0x7fd = boot-garbage sprites
(drawn before sprite RAM init); the 400-fetch cap filled before gameplay.
So the FORMULA is verified, but a real gameplay sprite hasn't been graded
yet. Remaining suspect = PIXEL DECODE (RDU/RDL -> 4bpp nibble extraction in
obj.v), to be settled by scene-replay of a real MAME sprite frame.
