# FILL and PIXBLT array instructions

The 1988 TI *TMS34010 User's Guide* defines FILL on printed pp. 12-80–88,
PIXBLT on pp. 12-174–212, the implied B-register operands in §5.1.4, the
corner direction in §7.2.2, and array timing and clipping setup in §§13.3–13.5.
The opcode summary on p. A-4 gives these fixed 16-bit words:

| Instruction | Word | Source | Destination |
| --- | --- | --- | --- |
| FILL L | `0FC0` | B9 COLOR1 | linear |
| FILL XY | `0FE0` | B9 COLOR1 | XY |
| PIXBLT L,L | `0F00` | linear | linear |
| PIXBLT L,XY | `0F20` | linear | XY |
| PIXBLT XY,L | `0F40` | XY | linear |
| PIXBLT XY,XY | `0F60` | XY | XY |
| PIXBLT B,L | `0F80` | one-bit bitmap | linear |
| PIXBLT B,XY | `0FA0` | one-bit bitmap | XY |

B0 SADDR and B1 SPTCH describe the source; B2 DADDR and B3 DPTCH
describe the destination. B4 OFFSET is the XY origin, B5/B6 are the
inclusive window corners, B7 DYDX stores height in its high half and width
in its low half, and B8/B9 hold COLOR0/COLOR1. PSIZE controls the
destination pixel width. CONVSP and CONVDP convert XY source and destination
coordinates, respectively. CONTROL[14:10] selects PPOP, bits 9/8 select
vertical/horizontal traversal (PBV/PBH), bits 7:6 select window mode, and bit
5 selects transparency. PMASK applies per physical pixel lane, with the
processing order described in [pixel-isa.md](pixel-isa.md).

FILL always traverses increasing addresses; FILL L ignores window and
direction controls. A completed FILL writes B2 with the linear bit address
following its last pixel. PIXBLT writes B0 and B2 with the source and
destination starts of the *next row* after the last row, respectively; B7
remains the supplied dimensions in the ordinary completed transfer. For
PIXBLT L,L, software must preadjust B0/B2 to the selected starting corners
when PBH or PBV is set; XY forms make that corner adjustment in hardware
(guide pp. 12-187–189 and §7.2.2). Binary PIXBLT expands one source bit per
destination pixel and selects the corresponding lane of B8 or B9. It fetches
32-bit source chunks, followed by a final partial chunk when needed, through
the field adapter (TI p. 13-35). Cached bits shift from the shared scratch
register; no further source request occurs until those bits are consumed.
For L,XY with PBV=1, SPTCH must be a power of two and CONVSP must describe
it; for XY,L with PBV=1, the corresponding requirement applies to DPTCH and
CONVDP (guide pp. 12-195, 12-202). Mixed-format tests use both conversion
controls and assert the source and destination next-row pointers.
Overlapping L,L tests move pixels one column right under PBH and one row down
under PBV, checking that reverse traversal preserves source pixels that a
forward traversal would overwrite.

An array with DX=0 or DY=0 performs no pixel memory transfer and preserves
the implied pointers and status (guide §§13.3–13.5). XY-destination window
mode 1 queries intersection without drawing, mode 2 aborts on a violation,
and mode 3 preclips the rectangle before transfer. When no pixels intersect,
mode 1 or 3 performs no destination transfer; the scalar vectors check the
original array memory and V/WVP. TI calls DADDR and DYDX indeterminate on a
mode-1 miss (guide pp. 12-195, 12-208), so those cases do not assert them.
FILL L leaves all four
status flags unchanged, while windowed FILL XY defines V. PIXBLT L,L lists
N/C/Z/V as undefined (guide p. 12-190), so ordinary PIXBLT completion
vectors do not assert them. Window violation and WVP behavior follow the pixel window
controls described in [pixel-isa.md](pixel-isa.md). Interruptible mid-array
checkpoints and PBX/RETI resume have separate focused tests documented in
[interrupts.md](interrupts.md), including binary source-chunk continuation.
Completed instruction tests assert memory and the defined B0/B2/B7 and
status results at retirement.

Binary expansion selects COLOR0/1 before pixel processing. The expanded
pixel is source-masked at its destination lane; the bitmap bit itself is
unmasked. This qualification is inferred from TI pp. 7-12/13 (the explicit
register-source exemption lists FILL, DRAV, LINE and register-source PIXT,
excluding binary PIXBLT) and p. 12-175 (expansion precedes processing with
PMASK enabled), and agrees with the pinned implementation. The directed
MAX/PMASK/transparency case distinguishes this from exempting expanded COLOR:
COLOR0=A05B, destination=F6D4 and PMASK=A49E produce source=0041 and
destination=5240 before MAX, preserving final F6D4. It is not recorded as
an old-reference divergence.

`ver/array/programs.py` independently calculates bit-addressed memory and
pixel equations for all eight forms, five pixel sizes, pitches, rows,
source alignment, masks, processing and transparency. It does not import RTL.
Run a reproducible set with:

```sh
python3 modules/jttms10/ver/array/programs.py --seed 34010 --samples 4 --out /tmp/array.yaml
python3 modules/jttms10/ver/run.py --vectors /tmp/array.yaml
python3 modules/jttms10/ver/reference.py --vectors /tmp/array.yaml
```

These generated cases check architectural memory results, not timing. The
separate interrupt bench checks logical source requests: unaligned DX32/33/65
rows issue 32-bit fields plus a one-bit remainder where needed, then restart
at the supplied pitch. It compares the interrupted and uninterrupted source
and destination streams. At interrupt entry B0 denotes the next 32-pixel
source chunk (p. 12-176); B12 preserves the cached bitmap and B10/B11/B14
retain the restart counters. The physical field adapter supplies the one,
two or three word reads required by each logical segment (p. 13-35).
