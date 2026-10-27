# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 21-10-2026

# CE and CE_HALF commits are separated by at least three clk cycles.
set_multicycle_path -from {*|v30_core:u_cpu|*} -to {*|v30_core:u_cpu|*} -setup -end 3
set_multicycle_path -from {*|v30_core:u_cpu|*} -to {*|v30_core:u_cpu|*} -hold -end 2
# The external bus keeps its two-cycle cenb sampling allowance.
set_multicycle_path -from {*|v30_core:u_cpu|*} -to {*|jtroundu_v30bus:u_bus|*} -setup -end 2
set_multicycle_path -from {*|v30_core:u_cpu|*} -to {*|jtroundu_v30bus:u_bus|*} -hold -end 2
