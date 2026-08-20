# SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
# SPDX-License-Identifier: GPL-3.0-or-later
#
# JT8051 only advances on cen.  Integrations must leave an idle clk cycle
# between active cen pulses; jt8051.v checks this invariant in simulation.
set_multicycle_path -from {*|jt8051:u_mcu|*} -to {*|jt8051:u_mcu|*} -setup -end 2
set_multicycle_path -from {*|jt8051:u_mcu|*} -to {*|jt8051:u_mcu|*} -hold  -end 2
