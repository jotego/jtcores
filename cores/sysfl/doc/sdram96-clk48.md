# SDRAM96 + CLK48: 96.768 MHz SDRAM, whole core stays at 48.384

Branch sdram96, base = nsr-inflection-point (sdram64 + F1-F4 + interleaves).
Goal: halve every romrq miss wall-clock without re-timing one line of core
RTL. The 48.384 base also restores the exact PCB rates lost in the retreat:
pixel 6.048, CPU 20.16 (5/12), C75 XIN 16.128 (1/3), C352 24.192 (1/2),
59.66 Hz.

## The recipe (rungun/simson donors, adapted)

- Macros: JTFRAME_PLL=jtframe_pll6048 (our own bring-up PLL: 48.384 pair +
  96.768 pair at the pll6144 donor phases, fractional like the whole
  SDRAM96 fleet), JTFRAME_SDRAM96, JTFRAME_CLK48, JTFRAME_RATE=59.66.
  JTFRAME_PXLCLK=6 stays.
- Under SDRAM96 the game's `clk` becomes 96.768 and jtframe hands us the
  phase-aligned `clk48`. Unlike the donors (video at 96), ALL sysfl logic
  moves to clk48: the video cones close at 20.67 ns exactly as today.
- Boundary rules, from the clock alignment (48 edges are a subset of 96):
  - our levels are stable >=2 fast cycles: framework sampling at 96 is safe
  - romrq ok/data are level-held while cs+addr match: 48-domain clients
    sample them safely (rungun's main does the same)
  - jtframe's pxl_cen/pxl2_cen are one-96-cycle pulses: cross them into
    the 48 domain with jtframe_crossclk_cen before our vtimer/video
  - ioctl/download pulses (prog_we) live at 96: jtsysfl_header keeps clk;
    everything else of ours is addressed by the wrapper (already 96)
- mem.yaml: `clocks:` moves under `clk48:` (same 5/12, 1/3, 1/2 ratios).
- SDC: core constraints are register-glob based and now budget against
  clk48 (20.67 ns); jtframe's own SDRAM96 SDC covers the controller.

## Why the fractional PLL is acceptable here

The 60.48 failure stacked fractional + single-rate HF=0 + a nonstandard
capture path. SDRAM96/HF=1 with donor phases is the daily configuration of
every pll6144 core in the field; this changes one variable, not three.

## Gates

burst_07200 CRC ec193361 (content untouched), speedrcr scenes 03900/05400/
06000/07200 cut counters vs the 48-sdram64 baselines (expect obj/roz/scr
to improve ~2x on miss-bound scenes), 500-frame speed1_fast boot (0 errors,
3 coins), CI build for M10K occupancy (sdram64 lcache config ~536/553
expected) and timing at both clocks. Bench deploy only after user go.
