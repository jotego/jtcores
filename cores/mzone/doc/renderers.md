# Mega Zone renderer reuse review

FIX now instantiates `jtframe_tilemap` directly. SCROLL instantiates
`jtframe_scroll` directly, including its native coordinate/scroll logic and
underlying tilemap engine. They supply real PCB-derived coordinates and let
the helpers drive tile RAM addresses and graphics ROM requests. There is no
synthetic phase counter, delayed request adapter, or custom tile shifter.
JTFRAME source and its existing interfaces remain unchanged.

Object scanning and the existing `jtframe_draw` now run at master-clock speed.
The byte-wide DMA fills a packed 32-bit render table; the eight-pixel staging
buffer and `cen2` interface are removed. The circular `jtframe_obj_buffer`
readout and palette-before-buffer transparency remain.

The counter mappings are recorded in [timing.md](timing.md). Hardware references
are [tiles.kicad_sch](../sch/tiles.kicad_sch),
[objects.kicad_sch](../sch/objects.kicad_sch), and
[objects2.kicad_sch](../sch/objects2.kicad_sch). The
[core README](../README.md#video-options-and-pcb-findings) records PCB comparisons,
including object priority over FIX at horizontal position 47.

## Reused helpers

| Component | Helper | Board-specific logic retained |
| --- | --- | --- |
| FIX | [`jtframe_tilemap`](../../../modules/jtframe/hdl/video/tilemap/jtframe_tilemap.v) | Piecewise H/V mapping, blanking-column mapping, separate source/priority windows |
| SCROLL | [`jtframe_scroll`](../../../modules/jtframe/hdl/video/tilemap/jtframe_scroll.v), [`jtframe_scroll_offset`](../../../modules/jtframe/hdl/video/tilemap/jtframe_scroll_offset.v) | Counter fold and origin adaptation before native flip/scroll calculation |
| Character ROM and palette | Plane wiring and `jtframe_prom` inside FIX/SCROLL | Combinational paired-nibble-to-plane wiring and PCB palette lookup |
| FIX controls | `jtframe_sh` | Independent delayed source and forced-priority enables |
| Objects | [`jtframe_draw`](../../../modules/jtframe/hdl/video/jtframe_draw.v), [`jtframe_obj_buffer`](../../../modules/jtframe/hdl/ram/jtframe_obj_buffer.v) | Packed scanner/DMA, paired-plane wiring, X reversal, palette and circular readout |
| Final RGB | `jtframe_blank` | Existing color mixer and width masking |

CPU-visible RAM remains generated from `cfg/mem.yaml`. The object DMA table
remains internal to its renderer.

## FIX coordinates and windows

`jtmzone_fix` passes mapped eight-bit coordinates to `jtframe_tilemap` with
its internal coordinate flips disabled. The code is `{cram[7],vram}`, the
palette is `cram[3:0]`, horizontal flip is `cram[6] ^ flip`, and vertical flip
is `cram[5]`. The helper owns synchronous map addressing, ROM address/CS,
metadata staging, and pixel shifting.

`HDUMP_OFFSET(-4)` supplies the native pipeline lead. This value is tested
with the surrounding PCB coordinate mapping; it is not interchangeable with
the former controller's eight-pixel lead or its two-pixel request advance.
The previous `jtmzone_tilemap` phase adapter has been removed.

The visible FIX origin is 0 normally and 240 when flipped. The 48-pixel fixed
window and horizontal blank-fetch interval 288–375 require piecewise mapping,
not a constant offset alone. The blanking coordinate is adjusted by orientation
to avoid an extra helper tile-boundary event at entry/exit. Non-flipped blanking
map reads subtract one tile column. At the flipped last visible fetch,
raw H=284–287 primes column 3: the original counter's fold at H=287 maps to
coordinate 25, i.e. tile column 3. This preserves the last pixels consumed by
the delayed FIX window rather than introducing a late edge artifact.

The source and priority windows remain separate:

- Non-flipped, FIX supplies the character source at raw positions 0–47 but
  forces priority only at 0–46. An opaque object can win at position 47.
- Flipped, both undelayed windows occupy raw positions 240–287.
- Both controls retain `FIX_EN_DLY=6` before the mixer. The original-width
  option masks the last non-flipped output pixel without moving HS/VS.

Raw vertical lines 256–263 map back to PCB lines 248–255 before global flip.
These coordinates and windows remain outside the generic tilemap.

## SCROLL coordinates

`jtmzone_scroll` passes real coordinates to `jtframe_scroll`, as Slap Fight
does, rather than using only its shifter behind a private scheduler:

```verilog
hbase = hdump < 288 ? hdump : hdump - 384;
tile_h = hbase + 4 - (flip ? 0 : 32);
```

The helper uses eight-bit map dimensions and `FLIP_HW=8`, `FLIP_VW=8`.
It applies global coordinate flip and the scroll additions itself. The
register names follow the portrait PCB axes: `scrx` receives `scrolly`, and
`scry` receives `scrollx`. The vertical input folds raw lines 256–263 as above.
The actual HS output from `jtmzone_video` drives the helper's line latch.

There is no explicit RAM-read advance or generated load/fetch phase. Tile RAM
addresses and graphics ROM requests are directly connected to the helper.
Its normal line-latched vertical scroll behavior is retained. Mid-line scroll
register changes and CPU writes near a tile fetch need additional PCB tests;
the frozen-controller tests hold map contents and registers stable per case.

## ROM format and deadline policy

FIX and SCROLL each convert the existing paired-nibble ROM layout into four
plane bytes using wires only. No ROM repacking, register stage, or timing state
is added. Each renderer then applies the same synchronous palette PROM as
before.

`rom_data` and `rom_ok` are connected directly to the native helpers. Requests
follow their native eight-pixel boundary timing; they are not retimed to the
old controller. When `rom_ok` is low at a load boundary, the helper loads zero
graphics bits. This differs intentionally from the old retained-word fallback.
The SCROLL diagnostic reports misses at the new native load boundary.
Zero graphics bits are checked before palette lookup; this is not a promise
that every palette maps them to black.

## Validation and limits

The [renderer simunit](../ver/tilemap_equiv/README.md) retains frozen copies of
the original custom renderers. Both old and new pixels feed the real color
mixer with identical palette data, object boundary pixels, and blanking inputs.
With timely ROM responses it compares final RGB and blanking at every checked
master clock, without a pixel shift or color tolerance. Unselected FIX output
and horizontal-blank pipeline internals are not observable RGB and need not
match. Late responses are checked against native zero-fill rather than falsely
claiming equivalence with the old fallback.

The 512-case matrix covers both flips/widths, four scroll pairs, two pixel
clock ratios, vertical boundaries and four response delays. It passes
3,538,944 control/blanking checks, 1,769,472 timely RGB comparisons, and 589,824
zero-fill checks. A temporary palette-address mutation fails the RGB checker.
Scene 989's settled frame 4 is pixel-identical to the previous implementation;
initial partial frames can differ with the changed request schedule.

These checks do not establish equivalence for arbitrary live CPU writes,
mid-line register changes, or every startup transient. Object DMA/overlap and
physical PCB comparisons remain separate validation concerns.

## Objects: scan order, DMA, and circular readout

### Scan and DMA

The PCB behavior recorded in `timing.md` requires 36 four-byte entries per
line, with the scan starting at HCNT 40. The core arms at raw `hdump == 39`
and processes entries 35 down to 0. This reverse traversal and overwrite order
implement the PCB's forward-scan/selective-overwrite priority. It must not be
replaced by an ascending scan without also preserving the winner for
intersecting objects.

The object list is a separate render table. DMA arms on vertical blank, waits
for the leading HS edge and then a pixel enable, and copies 240 bytes over
`240*4+1` horizontal counts. Scanning live CPU RAM instead of the table would
change which CPU updates become visible within a frame.

`jtframe_objscan` starts on a supplied HS rising edge, counts object entries
upward from zero to its counter overflow, and concatenates `{objcnt,step}` as
the address. It has no first/last-entry or reverse-direction parameters and
no object DMA. One could remap its address, synthesize a scan-start pulse, and
use `skip` to terminate useful entries, but that still requires a board-specific
controller/adapter and validation of its busy/step timing. The existing
controller directly expresses the 36-entry sequence and retains the separate
DMA schedule.

### Drawer and line buffer

Global flip does not simply mirror the object write coordinate in this core.
The raw eight-bit object X is retained; readout selects the board-oriented
origin. `jtmzone_objdraw` uses:

| Setting | Non-flipped | Flipped |
| --- | --- | --- |
| `hread = hdump - HOFFSET` | `HOFFSET = 54` | `HOFFSET = 6` |
| Circular read origin | 9 | 16 |
| Read/erase enables | `hread == -2, -1, 0..239` | Same local range |

Read addresses wrap modulo 256 and include a one-address synchronous RAM
latency correction. The two early reads prime the output pipeline. The line
banks switch on the leading HS edge, using `~HS` at the existing
`jtframe_obj_buffer` instance. The numerical phase/origin corrections are the
current FPGA alignment to the PCB comparison; they should not be confused
with independent physical PCB counters.

`jtframe_objdraw_gate` provides `~hs` bank switching, `KEEP_OLD`, `BUFDLY`,
`PACKED`, and horizontal offset/flip options. Its `pxl_cen` normally reads and
erases the hidden line buffer continuously, but with `HFIX=0` it can instead
be qualified by Mega Zone's finite read interval; an external coordinate adapter
can supply the circular address. This was verified in the helper experiment.
A separate read-enable port is therefore not inherently required.

`jtframe_objdraw` hides the pre-buffer data ports. Moving the object palette
lookup after its buffer changes overlap transparency: a nonzero raw pen that
maps to zero would overwrite an opaque old pixel before becoming transparent.
The generated overlap test detects that case; the actual object PROM also has
three nonzero pens mapping to zero. The lower-level `jtframe_objdraw_gate`
exposes `buf_pred`/`buf_din` and `BUFDLY`, so it can keep the synchronous palette
before buffer writes, eliminating this difference without changing JTFRAME.

`jtmzone_objdraw` uses the unmodified `jtframe_draw` at master-clock speed for
plane decoding, pixel shifting, and draw completion. Its `busy` signal controls
the master-clock scanner, like the Slap Fight implementation. `cen2`, the paced
emission counter, and the eight-pixel staging buffer have been removed.

The internal DMA table is `jtframe_dual_ram32`. Its byte-write enables preserve
the existing 240-byte copy, while its read port returns a complete four-byte
entry. The scanner allows one synchronous RAM read cycle before checking the
entry, keeps entries ordered 35 down to 0, and holds attributes until the draw
request has been accepted and `busy` falls. It starts from the same scan-arm
coordinate and retains the existing vertical-position and per-object flip
mapping.

Generic draw emits pixels in ascending X. A flipped object maps its write
address to `2*start_x + 15 - helper_x` modulo 256, preserving descending X and
wrapping without reversing the fetch order. Its native prefetch is used;
external addresses are rewired to `{code, ysub[3], half, ysub[2:0]}` and
paired-plane responses become plane-per-byte data. The synchronous palette
PROM remains before buffer writes, with one-master-clock write address/enable
compensation. JTFRAME and its interfaces are unchanged.

## Validation and overrun limits

The [object rendering simunit](../ver/obj_equiv/README.md) checks 128 generated
sprite cases against an independent logical compositor and frozen originals.
It covers overlaps, transparency after palette lookup, X wrapping, both flips,
delayed responses, and line boundaries. Eight pipeline cases retain exact DMA
checks and compare final pixels until an HS overrun occurs. Busy and ROM-request
phases intentionally follow the native helper rather than the old cadence.

The full-speed renderer matches all 15 saved images from five local captures,
including the flipped two-player scene and startup images. No binary or hex
fixtures are committed. At generated ROM delays of 0, 1, and 9 clocks, pipeline
pixels match the original. At 63 clocks, HS overruns produce 687 normal and
981 flipped differing pixel samples. These are diagnostics, not evidence of
universal equivalence or a claim that the PCB permits late writes. The existing
buffer swaps banks on HS even while drawing; the intended physical overrun/drop
policy still needs independent PCB validation.
