# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 21-10-2026

# Every V30 register commits in the ce/ce_half-gated banks of v30u_eu.sv and
# v30u_biu.sv; the remaining free-running always blocks hold only save-state
# readback (tied off) and simulation trace. jtroundu_main generates cenb three
# clocks after each 8 MHz cen pulse, so core registers load at least three
# clocks apart. jtroundu_v30bus samples the CPU outputs only on cenb, which
# trails every launch event by at least two clocks, so that boundary carries
# the same multicycle. Paths from v30bus back into the core stay single-cycle.
set_multicycle_path -from {*|v30_core:u_cpu|*} -to {*|v30_core:u_cpu|*} -setup -end 2
set_multicycle_path -from {*|v30_core:u_cpu|*} -to {*|v30_core:u_cpu|*} -hold -end 2
set_multicycle_path -from {*|v30_core:u_cpu|*} -to {*|jtroundu_v30bus:u_bus|*} -setup -end 2
set_multicycle_path -from {*|v30_core:u_cpu|*} -to {*|jtroundu_v30bus:u_bus|*} -hold -end 2
