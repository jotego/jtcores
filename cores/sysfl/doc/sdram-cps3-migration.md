# sysfl SDRAM migration to the cps3 cache-lanes model

Goal: replace the classic `jtframe_sdram64` bank model (and the in-core BL8
controller fork with its STOP truncation engine) with the cps3 burst /
cache-lanes subsystem, running on the user's 4-chip (2 CS group) module.

Two chips of independent {chip,bank} regions remove CPU-vs-GFX contention by
placement, give per-lane caches with full-page terminated bursts (arbitrary
line length), and let the ROZ mask hack be deleted later without a controller
change.

## Hard constraints

- **No SDRAM96.** The 2x clock would be 121 MHz, beyond the module budget.
  Run the SDRAM single-rate at the 60.48 base. This forces `HF=0`, which is
  the correct capture mode below 64 MHz (see jtframe_board_sdram.v:218).
  Risk: cps3 only ever runs cache-lanes with SDRAM96, so single-rate
  cache-lanes is unexercised. Watch data capture on the first boot.
- **DDIO SDRAM clock** stays (JTFRAME_180SHIFT), the proven pad-clock path.
- Integer vs exact-crystal PLL is orthogonal to this work; keep whatever the
  bench blessed (pllc6000 integer 60, or plld6048 if it holds).

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
