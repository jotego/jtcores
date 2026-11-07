# SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
# SPDX-License-Identifier: GPL-3.0-or-later
#
# JT8051 only advances on cen. Integrations must leave an idle clk cycle
# between active cen pulses; jt8051.v checks this invariant in simulation.
#
# The jtframe_8751mcu ROM/RAM ports and JT8051 sample one another on cen.
# Their paths therefore receive the same multicycle constraint as paths fully
# contained in jt8051. Other wrapper registers run at clk and stay single-cycle.
set_multicycle_path -from {*|jt8051:u_mcu|*} -to {*|jt8051:u_mcu|*} -setup -end 2
set_multicycle_path -from {*|jt8051:u_mcu|*} -to {*|jt8051:u_mcu|*} -hold  -end 2
set_multicycle_path -from {*|jt8051:u_mcu|*} -to {*|jtframe_ram_rst:u_ramu|*} -setup -end 2
set_multicycle_path -from {*|jt8051:u_mcu|*} -to {*|jtframe_ram_rst:u_ramu|*} -hold  -end 2
set_multicycle_path -from {*|jt8051:u_mcu|*} -to {*|jtframe_dual_ram_cen:u_prom|*} -setup -end 2
set_multicycle_path -from {*|jt8051:u_mcu|*} -to {*|jtframe_dual_ram_cen:u_prom|*} -hold  -end 2
set_multicycle_path -from {*|jtframe_ram_rst:u_ramu|*} -to {*|jt8051:u_mcu|*} -setup -end 2
set_multicycle_path -from {*|jtframe_ram_rst:u_ramu|*} -to {*|jt8051:u_mcu|*} -hold  -end 2
set_multicycle_path -from {*|jtframe_dual_ram_cen:u_prom|*} -to {*|jt8051:u_mcu|*} -setup -end 2
set_multicycle_path -from {*|jtframe_dual_ram_cen:u_prom|*} -to {*|jt8051:u_mcu|*} -hold  -end 2
