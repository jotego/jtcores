# CPS1 fixed-duration palette DMA

This simunit locks the CPS1 palette-copy timing and visible palette data
against issue #226's same-image SF2EB diagnostic V14. The diagnostic CPU image
is SHA-256 `cd0b136ef4221badbac1eeac59aa769b01ab2645bc8889e5e431ce20d029ec84`,
build `0c28`, suite CRC-32 `9b2bf924`. The validated PCB result report is
`/nobackup/tasks/jtcores-226/artifacts/hot-reload/v14-pcb-results-first.json` (SHA-256
`92f622247c0ebd152dff5397cfb96749290d7baf484d70019f3a39016c96668d`);
the exact-glyph physical MiSTer audit is
`/nobackup/tasks/jtcores-226/v14/artifacts/mister-capture/jt226-v14-mister-20261115T1556Z/analysis/counts.json`
(SHA-256 `40a4063db5756829b6de4ae95498eacd68ec5301a170f9cfbbaddc740b205c76`).

On the PCB, all six palette-control masks `00/01/02/03/0A/3F` produce 7,393
steady loops after a palette-base write, versus 7,757 in their matched no-trigger
cases. On MiSTer before this fix, the trigger results vary from 7,842 for mask
`00` to 7,472 for mask `3F`, versus 7,842 without a trigger. The PCB's constant
364-loop loss is about 0.78 ms if the frame is about 16.7 ms; this duration
assumption is an inference, and agrees with the existing `jtcps1_dma.v`
comment's ~782 µs all-page palette interval. The MiSTer full-mask loss is 370
loops, also about 0.79 ms under the same assumption. The evidence supports a
fixed six-page DMA bus interval after every palette-base write, with the CPS-B
mask controlling which pages receive the data.

The fixture drives the production `jtcps1_dma` module with immediate VRAM
acknowledgement and BG grant. It checks all six masks above plus a control-mask
change during an active transfer. Two further transfers run back to back
without resetting the DMA state. Every run must consume 3,073 accepted palette
reads and 12,305 BR clocks in this test setup. The first palette task accepts
513 reads because its last read prefetches word zero for the next page; the
remaining five tasks accept 512 reads each. Exactly 512 words must be written
to each enabled destination page, and none to a disabled page or the seventh
page. Distinct source data per run is read back through the palette RAM to
check the first and last words of each visible page.

Source-page selection follows the MAME `cps1_build_palette` rule: leading
disabled pages do not advance the source pointer, while gaps after the first
enabled page do. MAME supplies visible-data semantics here; it has no palette
bus-timing model. The test's fixed BR/read budget comes from the PCB comparison.

The original RTL passes the full-mask visible-word checks and has the same
3,073 reads and 12,305 BR clocks, then fails this test at mask `00` because it
creates no palette task or BR interval. The original full-mask transfer has
3,073 writes: 512 to each of six pages plus one extra write into page 6 from
the final prefetch. The corrected RTL preserves the full-mask read and BR
cadence and suppresses that extra write. The existing object-DMA regression
checks the shared scheduler separately.

Run from the project root after sourcing `setprj.sh`:

```sh
simunit-all.sh --only pal_dma_fixed
```

Also run `simunit-all.sh --only obj_dma_safe`,
`simunit-all.sh --only pal_dma_interleave` and `lint-one.sh cps1` for the shared DMA
module. This is a focused timing/data regression; the same V14 image must be
rechecked on FPGA after integration before claiming the physical timing gap is
closed.
