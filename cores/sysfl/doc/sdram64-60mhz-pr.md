# Upstream PR plan: 60 MHz-safe jtframe_sdram64

This branch (nsr-inflection-point) bookmarks the last sdram64-based sysfl
before the cps3 cache-lanes migration. The upstream PR to jotego extracts
the controller work below; doc/REVIEW.MD (7746d5726) has the full analysis.

## Already implemented here

- F1 `3260debe3`: LF_WAIT bank parameter, 20ns tRP/tRCD command spacing
  derived from JTFRAME_MCLK, opt-in via JTFRAME_SDRAM_TRP20 (zero change
  to existing cores; 48 MHz computes to no extra cycles, 60 MHz to 2).
  Includes the rw_test spacing checker (-trp20).
- F2 (partial, same commit): FAST_OUTPUT_REGISTER / FAST_OUTPUT_ENABLE_
  REGISTER on dq_pad under the same macro.

## Still to do for the PR

- F2 (full): launch the DQ/DQM/OE bundle one cycle before WRITE. Blocked
  on an arbiter design issue: pre-driving DQ needs a bus reservation the
  one-hot arbiter lacks (a naive dqm_busy block self-deadlocks because
  do_read checks all_dqm including its own bank).
- F5: jtframe_sdram64_init.v derives the 100 us power-up count from the
  actual clock (5000 clocks = 83 us at 60 MHz).
- Decide the default: PLL6671-family cores run 53.37 MHz with the legacy
  single-cycle spacing in the field; a bare 20ns rule would silently
  change them, hence the opt-in macro. The PR should present it as such.
- rw_test/sim.sh has a pre-existing bug (undefined $RANDOM_ vars in
  SIMEXE) - fix in the PR so the tb runs out of the box.
