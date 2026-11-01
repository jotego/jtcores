# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 01-11-2026

# Both CPUs separate CE and CE_HALF commits by at least three clk cycles.
set_multicycle_path -from {*|v30_core:u_cpu|*} -to {*|v30_core:u_cpu|*} -setup -end 3
set_multicycle_path -from {*|v30_core:u_cpu|*} -to {*|v30_core:u_cpu|*} -hold -end 2
