# S18 wrapper phase comparison

This test compares the immutable S18 wrapper/YM snapshot at
`3dc6b88e0204fd3abbb462b34f428757f8596e94` with the current fixed-48 MHz
wrapper. It runs the production 400x262 S16 timer, both actual wrapper trees,
the production S18 color mixer, no-crop short-blank stages and the
`JTFRAME_LIGHTGUN` RGB/blank tail. The S16 diagnostic source uses the actual
`jts16_prio` and `jtshanon_coldac` modules with a synchronous palette read.
Its layer inputs and the VDP tile pattern vary across the line; tile nibble 0
creates transparent pixels.

The S18 MiSTer and SiDi128 configuration resolves to a 48 MHz main clock,
`JTFRAME_PXLCLK=6`, and auxiliary 96 MHz for the legacy YM. It does not define
`JTFRAME_SDRAM96` or `JTFRAME_CLK48`. Therefore the framework pixel enables,
S16 pipeline, mixer and output tails run on clk48 with divider 4; the baseline
YM's internal path runs on clk96. The clocks share the MultiClock96 phase and
do not need synchronizers.

Each wrapper receives independent legal CPU writes and DTACK waits. The raster
register sequence is R1=45, R0=07, one full 104,800-pixel timer raster, R12=C1,
another full raster, then R0=06. The test fills a 64x32 name table, checks
representative physical VRAM bytes and CRAM/MMR state, then waits for passive
renderer readiness. It captures exactly six S16 rows, V=5..10, in each of two
frames: 3,840 tuples total. Assertions require nonblack colors, both YS
levels, varied S16 layer selection, full external blank coverage, and
VDP-disabled S16 output equality.

The candidate now exercises the production S18 tuple boundary in
`jts18_vdp`: two 25-bit registers carry `{YS,RGB}` together and advance on the
generated 6 MHz `pxl_48cen`. The raw YM tuple is retained as a separate
diagnostic branch, with no test-only delay in front of the production mixer.
The framework mixer and output tails continue to use their original
`pxl_cen/pxl2_cen` enables and raw S16 blanking; this preserves the measured
generator phase relationship. Reset clears both tuple registers on the first
clk48 edge regardless of enable. A sampled raw tuple appears at the wrapper
output on the next gated capture. After raw display, Mode5, or geometry
invalidation, zero reaches the wrapper output by the second subsequent gated
capture (at most 16 clk48 periods while the busy=0 enable continues). Zero,
transparent pixels, and ordinary blank tuples propagate normally.

The maintained fixture asserts the known V5 row nibble/palette tuples at
native X0..X3 (`1ce3100`, `1008e72`, transparent `0000000`, `100ce31`), checks
the S16-selected final x6 tuple is `002800`, and checks reset, invalidation,
and re-enable propagation at the real wrapper boundary. The historical run07
test adapter is superseded. Boundary07 used the approved two-register tuple
path, later validated at the production wrapper. An earlier synthetic colmix
experiment proposed three registers; that diagnostic is not the production
alignment recommendation. Historical sources and artifacts remain frozen for
provenance.

The optional `+RESET_BRIDGE` case keeps the original 3,840-tuple comparison,
then checks a cold release at +1 ns and four warm reset/release phases at +1,
+6, +11, and +16 ns from clk48 rising edges. Each warm case starts with both
wrapper tuple stages nonzero and generated pixel CEN low, holds reset for at
least 64 MCLK edges, verifies the registered YM reset and acquisition state,
then performs an ACKed display-off MMR write and two distinct CPU VRAM writes
with legal readbacks before geometry lock. It restores the literal fixture
MMRs, checks retained graphics/palette assets, and requires fresh H26/V0
readiness plus an ordered 320-pixel external V5 scan row. It captures and
freezes one pre-warm candidate raw-tuple row after checking literal X0..X3,
nonzero/varied colors, and both endpoints. Every warm row must match all 320
tuples exactly and pass the production two-register `{YS,RGB}` pipeline check
at each pixel. The physical row is external H192..511; native H is 26..345,
with native V5 through H329 and V6 from H330 through H345. This checks exact
row equivalence before and after reset against the frozen fixture row, not an independent
semantic oracle for every pixel. The CPU VRAM service probe restores physical
bytes 0..3 to the original zero tile through the same documented fixture
memory initializer and verifies those bytes before display is re-enabled. Run
it with:

```sh
cores/s18/ver/wrapper_phase/sim.sh +RESET_BRIDGE
```

Each reset bridge row has a fresh local count and must span one external V5
line without a frame crossing. Re-prime readiness and geometry-lock checks
occur after their existing bounded acquisition wait. The first post-reset MMR
write and VRAM readback both assert that geometry has not locked yet.

Run from the repository root:

```sh
cores/s18/ver/wrapper_phase/sim.sh
```

`WRAPPER_PHASE_JOBS` defaults to 2. The runner, capture, source hashes and
manifest are written under `/nobackup/tasks/jtcores-180/wrapper-phase/` (use
`WRAPPER_PHASE_OUT` for a unique immutable run directory). Earlier captures
using a 96 MHz framework CEN model or a test-only tuple adapter are superseded
and must not be used for production-boundary conclusions.
