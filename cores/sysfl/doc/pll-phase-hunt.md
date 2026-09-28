# SDRAM_CLK phase hunt over JTAG — plan

Goal: replace the DDIO/180SHIFT experiment with a plain PLL output driving
SDRAM_CLK, and find its correct phase empirically on the bench, live, using
the DE10-Nano's built-in USB Blaster II. One build, one sweep, then bake the
winning phase as a static PLL setting.

## Why

Both DDIO capture slots failed on hardware at 60 MHz: `SHIFTED=0` boots with
corrupt reads (WORK RAM NG, fast hangs), `SHIFTED=1` black-screens. The
review (doc/REVIEW.MD finding 1/3) shows the capture slot depends on real pad
and route delays that neither the sim nor the current SDC models. Sweeping
the pad-clock phase on silicon measures the actual valid window instead of
guessing it.

## Numbers

- pllc6000: 50 MHz ref, direct mode, VCO = 600 MHz.
- Cyclone V dynamic phase step = VCO/8 = 208.3 ps.
- One 60 MHz period = 16.667 ns = exactly 80 steps. Sweep all 80.
- SDRAM_CLK in the non-DDIO path is `clk48sh` = pllc6000 outclk_1, currently
  0 ps. outclk_1 feeds nothing else, so shifting it moves only the pad.

## RTL prep (single build)

1. Revert the DDIO experiment on the core side: drop `JTFRAME_180SHIFT`,
   drop `JTFRAME_SHIFT=0`, drop the `[mist|sidi|sidi128] -JTFRAME_180SHIFT`
   negation (nothing left to negate). Keep `7cdee4f82` in the tree; the
   `180SHIFT==0` mux arm simply stops selecting the DDIO cell.
   Standard MiSTer resolution is then SHIFT=1, 180SHIFT=0 -> SHIFTED=1 with
   the outclk_1 pad, the same structure every 48 MHz core uses.
2. Regenerate pllc6000 with the reconfig interface (`altera_pll_reconfig` +
   the `reconfig_to_pll/reconfig_from_pll` conduit). Dynamic phase on
   Cyclone V goes through the reconfig block's Avalon-MM: write the counter
   number of outclk_1 with the up/down bit to register 6 (dynamic phase),
   poll register 1 (status) for done. MiSTer's `sys_top` HDMI PLL already
   contains this Avalon write pattern to copy from.
3. Add a hunt block under a `SYSFL_PHASEHUNT` macro:
   - SDRAM stress tester in the game clock domain: marching-pattern plus
     LFSR write/readback bursts across banks 0/2/3 (the write-enabled ones),
     16-bit compare, saturating `err_cnt`, free-running `pass_cnt`.
     Reuse the rw_test module from the CMDW validation as the starting point.
   - A tiny FSM that on command executes N phase steps (Avalon writes) and
     resets the tester.
   - One In-System Sources & Probes instance (`altsource_probe`):
     sources: `step_pulse`, `step_dir`, `test_rst` (3 bits).
     probes: `step_cnt[6:0]`, `err_cnt[15:0]`, `pass_cnt[15:0]`, `locked`.
   - ISSP needs no core changes elsewhere and no SignalTap license.
4. Keep the game running normally besides the tester (the hunt block only
   owns a spare SDRAM slot or runs the tester during vblank); simplest
   first version: a dedicated test build where the tester owns bank 3.

## Bench procedure

1. Plug the DE10-Nano's USB Blaster II (mini-USB next to HDMI) into the Mac
   or a PC with Quartus programmer tools; MiSTer keeps running, JTAG attaches
   to the live fabric — no reprogramming.
2. Load the hunt build from the MiSTer menu as usual.
3. Open Quartus -> Tools -> In-System Sources and Probes, select the device.
4. Sweep: for step = 0..79: pulse `test_rst`, wait ~2 s, record `err_cnt`
   and `pass_cnt`, pulse `step_pulse`. A shell/tcl loop in the ISSP tcl
   console automates this (quartus_stp scripting).
5. Result is an 80-entry pass/fail map = the real DQ valid window in 208 ps
   resolution. Choose the center of the widest passing run; note the window
   width (want >= 8 steps ~ 1.7 ns for temperature margin).

## Bake and verify

1. Convert winning step count to picoseconds (steps x 208.33) and set it as
   `phase_shift1` in pllc6000 (regenerate the plain PLL, no reconfig block),
   remove the hunt block from the build.
2. Update `sdram_clk48.sdc` so the pad-clock `create_generated_clock` uses
   the real phase, add `set_input_delay/set_output_delay` for the SDRAM DQ,
   DQM, address and command pins from the datasheet (tAC/tOH, tDS/tDH) so
   TimeQuest guards the window from now on (REVIEW.MD finding 3), and put
   `SDRAM_CLK` in the correct clock group.
3. Rebuild clean, deploy, run the full POST plus long gameplay on both games.

## Fallback without JTAG

Drive `step_pulse/step_dir/test_rst` from `debug_bus` (OSD debug keys) and
show `err_cnt` on `st_dout`: same sweep, no cable, coarser workflow. Useful
if the Blaster driver misbehaves on macOS (jtag over a Linux laptop or the
MiSTer's own `jtagconfig` are alternatives).

## Effort

RTL prep ~1 day (reconfig plumbing is the unknown), bench sweep <1 hour,
bake+constraints ~half a day. All changes except the final PLL phase and the
SDC live under `SYSFL_PHASEHUNT` and are removed after the hunt.
