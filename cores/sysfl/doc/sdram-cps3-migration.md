# sysfl SDRAM migration to the cps3 cache-lanes model

Goal: replace the classic `jtframe_sdram64` bank model (and the in-core BL8
controller fork with its STOP truncation engine) with the cps3 burst /
cache-lanes subsystem, running on the user's 4-chip (2 CS group) module.

Two chips of independent {chip,bank} regions remove CPU-vs-GFX contention by
placement, give per-lane caches with full-page terminated bursts (arbitrary
line length), and let the ROZ mask hack be deleted later without a controller
change.

## Phase-1 outcome (2026-09-25, branch cps3-migration): STOPPED, measured

The full migration was implemented and runs (7 lanes, dual-chip XL, BALUT
header, woven windows at their banks' bases, single coherent rw wram lane,
romrq shims + direct-mapped front caches). It is a measured REGRESSION at
the 48 MHz single-rate the retreat imposed: burst_07200 obj/roz/scr cuts
38/31/131 vs the sdram64 baseline 26/61/0. Root cause is structural: the
lane subsystem costs ~22 clocks per miss at 48 single-rate (edge-triggered
requests, no pipelining, >=16-byte line fills) against romrq's ~11-clock
pipelined BL4, and the C123 walk makes ~100 compulsory misses per line.
Front caches recover hits (1 clock) but not the compulsory-miss latency;
splitting the mask stream onto the spare 8th lane made it worse (the masks
ride the pixel stream's front cache for free).

The subsystem pays only with the lanes in a 96 MHz domain. jtframe's
pattern for that (rungun, cps3): JTFRAME_SDRAM96 + JTFRAME_CLK48 keep the
CPU and sound on a phase-aligned 48 MHz clock (same-edge, not a true CDC),
but the VIDEO and pxl_cen live on the 96 MHz clock - i.e. the video chain
re-bases to 96 (double line budget in clocks, but every single-cycle video
path must close at 10.4 ns). That is the future task; check rungun/cps3
for the exact wiring. The work is preserved on this branch; nsr keeps the
sdram64 model.

## Phase 1 — controller transition (both mask folds are DONE on BL4)

DONE before the switch: the ROZ interleave (2342d77e8/d258763fe) and the
C123 scr+smask interleave (both masks ride their texel units, the rmask
and smask buses are gone). The core is at 8 SDRAM buses = 8 lanes, 1:1.

### mem.yaml: banks -> cache-lanes

Map every current bus to a lane on the 8 available {chip,bank} regions.
Suggested placement (CPU on chip 0, GFX on chip 1, so they never contend):

| chip | bank | lane      | dw  | notes                                  |
|------|------|-----------|-----|----------------------------------------|
| 0    | 0    | main+data | 32  | rw, flush; CPU program/data            |
| 0    | 1    | wram/wram32 | 16/32 | rw; nvram/comram in the upper window |
| 0    | 2    | pcm       | 8   | C352 streaming                         |
| 0    | 3    | mcurom    | 16  | C75 external data (latency-critical; on
|      |      |           |     | BL4 it sits in bank0, its own lane here)|
| 1    | 0    | objrom    | 32  | sprite tiles, large-block cache        |
| 1    | 1    | roz       | 64  | woven 8-byte units; drop to 6-byte lines
|      |      |           |     | (full-page terminate) to shed the pad  |
| 1    | 2    | scr       | 64  | woven 8-byte units, 5-byte lines later;
|      |      |           |     | keep >=4kB capacity (full line set)    |
| 1    | 3    | (free)    |     |                                        |

Line sizes: keep them small (texel-run sized), NOT tile sized. ROZ is
affine; big lines thrash under rotation. Bigger *capacity* (more sets) is
the ROZ lever, measured, not bigger lines.

objrom is the one that wants a genuinely larger block (sprite tiles are
read in horizontal runs) - this replaces the BL8 win the STOP engine gave.

### What gets deleted in phase 1

- `cores/sysfl/hdl/sdram64/` (the controller fork) and JTFRAME_CORE_SDRAM64
- the STOP truncation engine (lives only in that fork)
- BA1_LEN / BAx_LEN macros
- the core lcache + JTFRAME_CORE_LCACHE (cache-lanes bring their own)

### What is KEPT untouched in phase 1

- both woven download paths (the pre_addr remap and the doubled mask streams)
- every core bus handshake contract (especially: C75 mcurom latency, the
  wram32 shadow/first-write-wins, the vblank oram DMA snapshot)
- the c123 single-entry unit latch: pixels draw from it so the port is free
  for the mask prefetch; the cache behind it must keep a full line's set

### Validation gate (both must pass, both games)

1. burst_07200 fingerprint bit-exact vs the pre-migration CRC, no %Error
2. full scene sweep speedrcr (12) + finalapr (21): cut/over counts within
   noise of today; MAME diffs at their baselines
3. 1500-frame gameplay boot, 0 errors, 59.6x Hz, coins working (C75 canary)
4. CI build: fits, timing met, resource delta recorded

Only after all four: commit, then bench.

## Phase 2 — DONE EARLY on BL4 (both interleaves landed pre-migration)

- ROZ: 8-byte units [4 texels][mask c13=0][mask c13=1][2 pad] keyed
  {code[12:0], yp, xp[3:2]} - 2342d77e8 (RTL+sim), d258763fe (download).
- C123: 8-byte units [4 texels][row mask][3 pad] keyed {code, row, col[2]},
  mask byte duplicated across the col[2] pair; smask bus deleted; C75 data
  moved to bank0; pcm+wram to bank2; the 8MB woven scroll fills bank3.
  Pixels draw from a single-entry unit latch so the shared port serves the
  mask prefetch in the gaps; scr cache 4kB to hold a full line's units.
- Under cps3 full-page terminate the pads drop: roz lines 6 bytes (both
  mask bytes kept), scr lines 5 bytes.

## Rollback

Phase 1 is one commit set touching mem.yaml, macros, files.yaml and the
deleted fork. If single-rate cache-lanes misbehaves in a way that is not a
quick fix, revert to the tip before this task (BL8 fork intact) and keep
that as the shipping baseline while investigating.

## Phase 3 — reclaim exact timing if slack allows (STRATEGIC, LATER)

The cache-lanes model may buy back real Fmax slack: full-page bursts remove
the per-word STOP/turnaround pressure, and per-lane caches shorten the fetch
cones. If the phase-1 build lands with comfortable positive slack, the base
clock question reopens in the good direction:

- Option A: return to the true 48.384 MHz crystal base (exact PCB rates,
  6.048 pixel, 59.66 Hz native) and run the SDRAM FASTER than the base with
  a 2x-style path (96.768 MHz, well within the module budget - the 121 MHz
  wall only existed because 60.48 x2 overshot). This is the best of both:
  exact video timing AND high SDRAM bandwidth, which is what the whole
  60.48 detour was a workaround for.
- Prerequisite: cache-lanes at a base/2x split proven (cps3 already runs
  the burst subsystem at HF=1 double-rate, so this is its native mode - the
  UNtested one is phase 1's single-rate, not this).
- Only pursue if phase-1 slack is large; otherwise stay at 60.48 single-rate.

Order of preference for the end state, best first:
1. 48.384 base + 96.768 SDRAM (exact rates, high bandwidth) - phase 3
2. 60.48 single-rate (current target) - phases 1-2
3. 60.00 integer (proven fallback if fractional jitter bites)
