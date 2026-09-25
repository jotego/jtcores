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

## Phase 1 — transition only, hack UNCHANGED (this task)

Port the bus layout verbatim in behavior; no interleave, no hack removal.
The RMASK post-download relocation and the separate c169 mask path stay
exactly as today. Only the controller and cache layer change.

### mem.yaml: banks -> cache-lanes

Map every current bus to a lane on the 8 available {chip,bank} regions.
Suggested placement (CPU on chip 0, GFX on chip 1, so they never contend):

| chip | bank | lane      | dw  | notes                                  |
|------|------|-----------|-----|----------------------------------------|
| 0    | 0    | main+data | 32  | rw, flush; CPU program/data            |
| 0    | 1    | wram/wram32 | 16/32 | rw; nvram/comram in the upper window |
| 0    | 2    | pcm       | 8   | C352 streaming                         |
| 0    | 3    | mcurom    | 16  | C75 external data (latency-critical)   |
| 1    | 0    | objrom    | 32  | sprite tiles, large-block cache        |
| 1    | 1    | roz       | 32  | texels; keep small line for capacity   |
| 1    | 2    | rmask     | 8   | STAYS SEPARATE in phase 1 (hack intact)|
| 1    | 3    | scr+smask | 8   | scroll tiles + shape mask (classic)    |

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

- RMASK_START + the make_sdram RMASK splice + mame2mra RMASK region
- c169 mask path: rmask_addr/rmask_cs/rmask_ok, the 2-station miss queue,
  c_maddr/c_mbyte, opq interplay
- every core bus handshake contract (especially: C75 mcurom latency, the
  wram32 shadow/first-write-wins, the vblank oram DMA snapshot)

### Validation gate (both must pass, both games)

1. burst_07200 fingerprint bit-exact vs the pre-migration CRC, no %Error
2. full scene sweep speedrcr (12) + finalapr (21): cut/over counts within
   noise of today; MAME diffs at their baselines
3. 1500-frame gameplay boot, 0 errors, 59.6x Hz, coins working (C75 canary)
4. CI build: fits, timing met, resource delta recorded

Only after all four: commit, then bench.

## Phase 2 — ROZ mask interleave, hack removal (LATER, separate task)

Once phase 1 is proven on hardware:

- One combined roz lane, line = 8 texel bytes + 1 mask byte = 9 bytes.
  The 8-texel run and its mask share the address key
  `{code, yp[3:0], xp[3]}`, so one tag/one slot/one terminated burst
  returns both. Mask overhead is the exact covering byte, zero rotation
  waste.
- Download interleaver writes 8 texels then 1 mask byte, repeating.
  Note the code-width difference: texel uses code[12:0], mask code[13:0];
  key the combined region on the full 14-bit code.
- Delete: RMASK region + splice, the separate c169 mask path and its miss
  queue. Frees the mask BRAM and the queue logic.
- Same 4-gate validation. scr+smask can follow with the identical pattern.

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
