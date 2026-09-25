# The i960 advances on cpu_cen (20 MHz from clk48, 5/12 fractional enable,
# minimum spacing 2 clock cycles), so CPU-internal register-to-register
# paths have a two-cycle budget. Without this, the single-cycle fuse loop
# (IP -> icache hit compare -> decoder -> operand muxes -> branch adder ->
# IP) reports about -7.3 ns at the 48 MHz period.
set cpu_regs [get_registers {emu|u_game|u_game|u_main|u_cpu|*}]
set_multicycle_path -from $cpu_regs -to $cpu_regs -setup -end 2
set_multicycle_path -from $cpu_regs -to $cpu_regs -hold  -end 1

# The instruction cache and register cache RAMs sample their address/data
# ports every clock (no cen): restore single-cycle timing into them. These
# paths are shallow and close at 48 MHz.
set cpu_rams [get_registers {emu|u_game|u_game|u_main|u_cpu|icd* emu|u_game|u_game|u_main|u_cpu|ict* emu|u_game|u_game|u_main|u_cpu|ic_ra* emu|u_game|u_game|u_main|u_cpu|u_rcache|*}]
set_multicycle_path -from $cpu_regs -to $cpu_rams -setup -end 1
set_multicycle_path -from $cpu_regs -to $cpu_rams -hold  -end 0

# Clock-rate sources inside the CPU: the icache output/sweep/invalidate
# registers and the rcache read ports update every clk, so they get only one
# cycle to any CPU register despite the blanket two-cycle budget above.
set cpu_1clk [get_registers {emu|u_game|u_game|u_main|u_cpu|icd_q* emu|u_game|u_game|u_main|u_cpu|ict_q* emu|u_game|u_game|u_main|u_cpu|ic_ra* emu|u_game|u_game|u_main|u_cpu|swa* emu|u_game|u_game|u_main|u_cpu|sweeping emu|u_game|u_game|u_main|u_cpu|icinv* emu|u_game|u_game|u_main|u_cpu|u_rcache|dout* emu|u_game|u_game|u_main|u_cpu|u_rcache|fa_dout*}]
set_multicycle_path -from $cpu_1clk -to $cpu_regs -setup -end 1
set_multicycle_path -from $cpu_1clk -to $cpu_regs -hold  -end 0

# The mid-cen pipeline stage samples every clk and is consumed at the next cen
# edge, one clock later in the worst case: single-cycle both ways.
set s1_regs [get_registers {emu|u_game|u_game|u_main|u_cpu|s1_*}]
set_multicycle_path -from $cpu_regs -to $s1_regs -setup -end 1
set_multicycle_path -from $cpu_regs -to $s1_regs -hold  -end 0
set_multicycle_path -from $s1_regs -to $cpu_regs -setup -end 1
set_multicycle_path -from $s1_regs -to $cpu_regs -hold  -end 0
