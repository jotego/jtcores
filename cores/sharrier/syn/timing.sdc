# JTSHARRIER timing constraints
#
# ---------------------------------------------------------------------------
# THE i8751 MCU IS CLOCK-ENABLED, NOT CLOCKED. TIME IT ACCORDINGLY.
# ---------------------------------------------------------------------------
# Without this constraint the core reports -9.291 ns setup slack and -3137 ns
# TNS on the main PLL clock. Every one of the 4000 worst paths is inside
# jtsharrier_8751mcu; nothing else in the core fails at all.
#
# The paths run from the MCU program ROM to the 8051's instruction decode:
#
#   from  jtsharrier_8751mcu:u_mcu|jtframe_dual_ram_cen:u_prom|...ram_block*
#   to    jtsharrier_8751mcu:u_mcu|mc8051_core:u_mcu|...|control_mem|ip[*]
#   data delay 27.3 ns   vs   required 19.86 ns
#
# That requirement is wrong. Both endpoints run on `cen_eff`, not on `clk`:
#
#   jtframe_dual_ram_cen #(...) u_prom( .cen( cen_eff ) );
#   mc8051_core              u_mcu ( .cen( cen_eff ) );
#
# `mcu_cen` is jtframe_frac_cen with n=39, m=245 off ~50.35 MHz = 8.01 MHz
# (jtsharrier_game.v). 39/245 = 0.1592 < 1/6, so consecutive enables are 6 or
# 7 clocks apart and NEVER closer than 6. The real budget is ~125 ns, not
# 19.86 ns. `cen_eff` is sparser still (`cen & step_due`), so 6 is a floor.
#
# A multicycle of 4 is used rather than the provable 6: 4 x 19.86 = 79.4 ns
# still clears the 27.3 ns path with a wide margin, and it does not stake the
# build on the tightest possible bound. If the MCU clock ratio is ever changed,
# RECHECK THIS NUMBER -- it must stay below the minimum enable spacing.
#
# This is a false-path correction, NOT a workaround for slow logic. The
# hardware was always fine; only the analyser's assumption was wrong.
set_multicycle_path -from {*|jtsharrier_8751mcu:u_mcu|*} \
                    -to   {*|jtsharrier_8751mcu:u_mcu|*} -setup -end 4
set_multicycle_path -from {*|jtsharrier_8751mcu:u_mcu|*} \
                    -to   {*|jtsharrier_8751mcu:u_mcu|*} -hold  -end 3
