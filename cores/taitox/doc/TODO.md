# JTTAITOX — open items

## 1. Gigandes: 4-pixel purple dot on row 0

**Symptom.** Stray artefact on the first visible scanline: exactly 4 pixels at
columns 12–15, row 0 only, RGB (140,57,140). In simulation it appears on about
one frame in five and is gone on the very next frame. On real hardware it is
persistent rather than alternating.

**Reproduce.**

```bash
ROMS_HOST=~/mameroms FRAMES=200 ./sim-core.sh taitox gigandes
```

Then scan *every* written frame for lit pixels in row 0. Dot frames in a recent
run: 96, 97, 98, 100, 101, 122, 132, 138, 148, 150, 154, 171, 178, 192.
Compare frame 138 against 139 — the diff is 4 pixels, rows 0..0, cols 12..15.

Do **not** spot-check sparse frames. An earlier attempt sampled
1/214/249/487/610/645/940, hit no dot frames, and wrongly concluded the bug was
absent.

**Ruled out — the sprite Y wrap.** A wrapped 16-tall sprite would paint 8 rows,
not one. A/B on the actual dot frames:

| OBJ_YWRAP | dot frames | frames written |
|---|---|---|
| 0 | 96 97 98 100 101 122 · 138 · 150 154 171 178 192 | 73 |
| 1 | 96 97 98 100 101 122 132 138 148 150 154 171 178 192 | 77 |

Twelve are common to both, so the parameter neither creates nor removes it. The
runs are not bit-identical, so it does perturb something — just not this.

Also confirmed but not the cause: gigandes parks 474–480 of its 512 sprites at
Y=0xFA. With `yoff=+0x0e` that is row 248 plus a wrap copy at −8 covering rows
0..7, and ~40–45 carry non-zero codes — but they have transparent pixels in the
wrapped rows, so nothing is drawn.

**Leading theory — object line buffer at the frame boundary.** `jtkiwi_obj`
renders line N+1 while line N is displayed. At the top of a frame the
"previous" line is the last line of the *previous* frame, so leftover buffer
content can surface on row 0. Fits all three observations: one row tall, a few
pixels wide, varying frame to frame. Hardware showing it persistently while the
sim alternates suggests a race whose timing differs between SDRAM/BRAM and the
real board, not a deterministic logic error.

**Where to look.** `cores/kiwi/hdl/jtkiwi_obj.v` — how `jtframe_obj_buffer` is
cleared and swapped across vblank, and whether row 0 gets a full render slot
before being displayed. `VB_END=7` / `VCNT_END=271` in `hdl/jttaitox_video.v`
set where that boundary falls.

**Constraints.** Keep `OBJ_YWRAP(1)`: the X1-001 compares an 8-bit line counter
against an 8-bit sprite Y, MAME models the same via the `row−256` second
`transpen`, and cal50 and arbalest both set it. Any fix must keep superman
byte-identical to MAME on the title screen (frames 412/452/492) — that
comparison has already caught two real bugs.

## 2. `OBJ_YWRAP` conflates two behaviours

`cores/kiwi/hdl/jtkiwi_obj.v:106`

```verilog
if( hs || (!YWRAP && vdump>9'hf8) ) begin   // scanner reset
```

The parameter controls both the Y compare width *and* whether the scanner is
held reset through vblank. These are unrelated and should be separate
parameters. Shared module — needs cal50 and arbalest regression before landing.


## Video timings — MEASURED on an original P0-039A (closed)

Scope measurements on a real Superman board (Aug 2026):

| quantity | measured | derived |
|---|---|---|
| pixel clock | 124 ns/step | 8 MHz dot clock |
| 68000 clock | 125 ns period | 8 MHz (16/2) |
| H period | 64.00 us | 512 dots/line, 15.625 kHz |
| frame | 17.40 ms | 272 lines, 57.45 Hz |
| HS pulse | 6.6-6.7 us | ~53 dots |
| VS pulse | 516 us | 8 lines |
| IPL1 | one 420 us low pulse per frame | VBL IRQ held ~6.5 lines |

Every `jtframe_vtimer` parameter in `hdl/jttaitox_video.v` was already correct
(512 x 272, HS 52 dots, VS 8 lines, 57.4449 Hz) - nothing changed in the HDL.
The "HSync 15.22 kHz / Vsync 58 Hz" text in the MAME driver is the East Tech
P0-057A dump note, not this board.

Front/back porch split: not measured; we are happy centering the picture.

**MAME PR opportunity.** superman's config uses a guessed
`set_refresh_hz(57.43)` and 416x256 totals. The measured raster is:

```cpp
screen.set_raw(16_MHz_XTAL/2, 512, 0, 384, 272, 8, 248);
```

