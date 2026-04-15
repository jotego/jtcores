# SDRAM Burst/Cache Next Session Plan

## Goal

Finish the SDRAM burst/cache follow-up without regressing the CPS3 `sfiiin`
scene back to the horizontally shuffled state.

## State At Hand-off

### Verified good

- The CPS3 scene is still in the current "tilemaps visible, sprites partly
  right, not yet matching MAME" state when `jtframe_burst_ctrl.v` is left in
  its current scene-safe timing.
- Reference baseline artifacts were saved at:
  - `cores/cps3/ver/sfiiin/baseline-2026-04-15-sdram-burst-cache/frame_00003.jpg`
  - `cores/cps3/ver/sfiiin/baseline-2026-04-15-sdram-burst-cache/test.fst`
  - `cores/cps3/ver/sfiiin/baseline-2026-04-15-sdram-burst-cache/test.fst.hier`
- `modules/jtframe/hdl/sdram/jtframe_cache.sv` now gates cache refill writes as:
  - `wr_en = wait_data && ext_dok && (fill_active || ext_dst);`
  This prevents trailing `ext_dok` beats from overwriting the captured refill
  response after the line is already logically complete.
- `modules/jtframe/ver/sdram/cache_mux/test.v` was fixed to wire `dok` through
  to `jtframe_cache_mux`. Before that, the testbench was stale and could not
  describe the actual cache refill contract.

### Verified conflict

- If `jtframe_burst_ctrl.v` is modified so the generic `burst_sdram`,
  `cache_burst_sdram`, and `cache_mux` simunits pass, the CPS3 `sfiiin` scene
  regresses to the shuffled output.
- If `jtframe_burst_ctrl.v` stays in the current scene-safe state, the generic
  burst/cache benches still observe a one-beat alignment mismatch.
- The direct burst trace in the current scene-safe state shows:
  - `ack` on the read command acceptance cycle
  - first visible `dok/dst` one cycle later
  - first sampled `dout` corresponding to the next 16-bit word, not the
    requested word
- With the current scene-safe RTL, the cache benches therefore see refill data
  shifted by one beat unless they compensate somewhere else in the path.

## Files Already Touched

- `modules/jtframe/hdl/sdram/jtframe_cache.sv`
- `modules/jtframe/ver/sdram/cache_burst_sdram/test.v`
- `modules/jtframe/ver/sdram/cache_mux/test.v`

## Recommended Next Work Order

1. Re-run the scene-good baseline first.
   Command:
   ```bash
   source setprj.sh >/dev/null && cd cores/cps3/ver/sfiiin && ./sim.sh -d VERILATOR_KEEP_SDRAM
   ```
2. Reconfirm the current failing unit-test behavior under the scene-safe RTL.
   Commands:
   ```bash
   source setprj.sh >/dev/null && simunit.sh --run modules/jtframe/ver/sdram/burst_sdram --macros DEBUG
   source setprj.sh >/dev/null && simunit.sh --run modules/jtframe/ver/sdram/cache_burst_sdram --macros DEBUG
   source setprj.sh >/dev/null && simunit.sh --run modules/jtframe/ver/sdram/cache_mux
   ```
3. Do not change `jtframe_burst_ctrl.v` first.
   The prior attempt to shift the first qualified read beat earlier fixed the
   generic benches but visibly broke CPS3.
4. Build or adapt a CPS3-shaped cache-mux regression bench before touching the
   burst timing again.
   Use the real cache-line parameters from `cores/cps3/cfg/mem.yaml`:
   - tiles: 32-bit, 1 kB, 128 blocks, big-endian, bank 3
   - scndma: 32-bit, 1 kB, 1 block, bank 0
   - scrmap: 32-bit, 1 kB, 8 blocks, bank 0
5. Prove where the beat shift must be corrected:
   - inside `jtframe_burst_sdram` / `jtframe_burst_io`
   - at `jtframe_cache` refill capture
   - at `jtframe_cache_mux`
   - or in CPS3 request addressing assumptions
6. Only update the README files once one contract satisfies both:
   - generic simunits
   - scene-good CPS3 output

## Concrete Investigation Targets

- Trace one known tile fetch in CPS3 and compare:
  - requested cache address
  - SDRAM burst address
  - first `dok/dst` beat
  - word captured into cache
  - final `tiles_data` consumed when `tiles_ok` is high
- Inspect these CPS3 consumers with that trace in hand:
  - `cores/cps3/hdl/jtcps3_obj.v`
  - `cores/cps3/hdl/jtcps3_scr.v`
  - `cores/cps3/hdl/jtcps3_scene.v`
- Keep in mind that `jtcps3_obj.v` explicitly increments `tiles_addr` for the
  later words in a row fetch, so an off-by-one compensation in the wrong layer
  can fix the generic benches while breaking the real scene.

## Acceptance Criteria For Next Session

Treat the work as done only when all of these are true:

1. `simunit.sh --run modules/jtframe/ver/sdram/burst_sdram` passes.
2. `simunit.sh --run modules/jtframe/ver/sdram/cache_burst_sdram` passes.
3. `simunit.sh --run modules/jtframe/ver/sdram/cache_mux` passes.
4. The CPS3 `sfiiin` scene still shows visible tilemaps and does not return to
   the shuffled regression.
5. At least one traced CPS3 tile fetch is matched end-to-end against
   `tilechar.bin`.
6. The relevant READMEs are updated to the final verified contract.

## Current Warning

Do not trust a fix that only makes the generic benches pass. That exact class
of change was already shown to regress the real CPS3 scene.
