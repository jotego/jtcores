# Object renderer simunit

```sh
source setprj.sh
simunit.sh --run cores/mzone/ver/obj_equiv
```

No ROMs, MAME, external captures, binary/hex fixtures, or fixture generator are
required. Verilog functions generate logical graphics pixels and a nonidentity
palette; synchronous RAM models generate the object table. CI discovers the
standard `.simunit`, `test.v`, and `gather.f` layout.

The production scanner and `jtframe_draw` run at master-clock speed. The DMA
still copies 240 bytes at its original pixel-clock-qualified rate. Four byte
lanes form each 32-bit internal render-table entry, so the scanner reads all
attributes together. Entries remain ordered 35 down to 0. The drawer keeps the
palette PROM before `jtframe_obj_buffer` writes and preserves circular readout,
without `cen2`, an eight-pixel staging buffer, or any JTFRAME modifications.

## Generated sprite checks

`reference/` freezes the original custom scanner/DMA and drawer, with source
SHA256 hashes. Do not update these files to make a candidate pass. Independent
RAM/ROM responders serve each implementation; request timing is not coupled.

The direct drawer matrix has 128 cases:

- Global flip and per-object horizontal flip, independently varied.
- Pixel-enable periods of four and eight master clocks.
- Object rows 0, 5, 10, and 15.
- ROM response delays of 0, 1, 9, and 63 master clocks.
- X=0, 64, 68, 248, 256, and 511, including eight-bit wrapping.
- Overlapping sprites, transparent holes, and fully transparent sprites.
- Palette entries mapping some nonzero raw pens to transparent color zero.

The independent logical sprite compositor checks both implementations after
requests complete, including all readout coordinates, both line banks,
read/erase behavior, and retention outside the finite circular interval.
The current run checks 147,456 pixels, 4,813 opaque overlaps, 4,448 transparent
holes, 2,944 wrapping pixel positions, and 92,928 read/erase events.

Requests remain asserted until response acceptance, and addresses may not
change while waiting. Unknown request controls, active ROM addresses, and
warmed-up pixel output fail. Busy duration and ROM fetch phases intentionally
do not have to match the old engine. Direct requests wait for both drawers to
finish so an early native completion cannot silently drop the next reference
sprite.

## Scanner/DMA and HS boundaries

Eight full-pipeline cases cover both flips and the four ROM delays over 24
lines each. They verify all 240 sequential DMA byte advances per case, unchanged
DMA addresses, no restart outside vblank, and live CPU-RAM changes after DMA.
Per-object horizontal and vertical flips are varied.

Final pixel-enable samples after warmup must match until a draw in either
implementation spans an HS boundary. Such an overrun changes which line bank
receives later pixels, so the old slower renderer is not an equivalence oracle
for the remainder of that case. Those differences are counted and printed,
not hidden or converted into an assertion of equivalent rendering. The current
run has 45,312 exact pipeline pixel comparisons and 1,668 differing overrun
samples (687 normal, 981 flipped) at the 63-clock delay. Delays 0, 1, and 9
produce no pipeline pixel differences.

Two explicit transactions put HS during a 400-clock delayed fetch and during
pixel writes. Unknown output still fails; differing output cycles are recorded
as an overrun diagnostic (currently 96). These diagnostics do not prove that
the physical PCB permits late writes. Establishing its overrun/drop policy
requires separate PCB evidence.

## Full scene validation

The full-speed implementation matches all 15 saved PNGs from local captures
989, 1141, grid, 972_flipped_2p, and legacy989, including frames 1, 3, and 4.
The captured dumps remain external support files; none are committed.

This validates the tested captures, not universal frame equivalence at every
possible ROM latency. In particular, the generated stress cases above remain
a documented behavioral difference from the original implementation.
