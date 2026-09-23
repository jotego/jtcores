# The i960 advances on cpu_cen (20.16 MHz = clk/3, a strict three-cycle
# spacing), so CPU-internal register-to-register paths have a three-cycle
# budget at the 60.48 MHz base period.
set cpu_regs [get_registers {emu|u_game|u_game|u_main|u_cpu|*}]
set_multicycle_path -from $cpu_regs -to $cpu_regs -setup -end 3
set_multicycle_path -from $cpu_regs -to $cpu_regs -hold  -end 2

# The instruction cache and register cache RAMs sample their address/data
# ports every clock (no cen): restore single-cycle timing into them. These
# paths are shallow and close at 48 MHz.
set cpu_rams [get_registers {emu|u_game|u_game|u_main|u_cpu|icd* emu|u_game|u_game|u_main|u_cpu|ict* emu|u_game|u_game|u_main|u_cpu|ic_ra* emu|u_game|u_game|u_main|u_cpu|u_rcache|*}]
set_multicycle_path -from $cpu_regs -to $cpu_rams -setup -end 1
set_multicycle_path -from $cpu_regs -to $cpu_rams -hold  -end 0

# The bus funnel captures the CPU outputs in the CAPT state, two clocks
# after the cen edge that launched them, and the CPU holds them until the
# transaction is acknowledged. The wram32/main data return is muxed by the
# registered sel_* flags, so the CPU only consumes it on the following cen.
set fun_regs [get_registers {emu|u_game|u_game|u_main|fa* emu|u_game|u_game|u_main|fd* emu|u_game|u_game|u_main|fdsn* emu|u_game|u_game|u_main|fwr emu|u_game|u_game|u_main|half emu|u_game|u_game|u_main|wram_addr* emu|u_game|u_game|u_main|wram_din* emu|u_game|u_game|u_main|wram_dsn*}]
set_multicycle_path -from $cpu_regs -to $fun_regs -setup -end 2
set_multicycle_path -from $cpu_regs -to $fun_regs -hold  -end 1

# Clock-rate sources inside the CPU: the icache output/sweep/invalidate
# registers and the rcache read ports update every clk, so they get only one
# cycle to any CPU register despite the blanket two-cycle budget above.
set cpu_1clk [get_registers {emu|u_game|u_game|u_main|u_cpu|icd_q* emu|u_game|u_game|u_main|u_cpu|ict_q* emu|u_game|u_game|u_main|u_cpu|ic_ra* emu|u_game|u_game|u_main|u_cpu|swa* emu|u_game|u_game|u_main|u_cpu|sweeping emu|u_game|u_game|u_main|u_cpu|icinv* emu|u_game|u_game|u_main|u_cpu|u_rcache|dout* emu|u_game|u_game|u_main|u_cpu|u_rcache|fa_dout*}]
set_multicycle_path -from $cpu_1clk -to $cpu_regs -setup -end 1
set_multicycle_path -from $cpu_1clk -to $cpu_regs -hold  -end 0

# The mid-cen pipeline stage samples every clk, but its inputs only change on
# cen edges (strict three-clock spacing): the sample one clock after a cen is
# the only one that matters and it is held for two more clocks before the
# consuming cen. The icache turn-around, the one unstable input, is gated by
# s1_ok. Two cycles are therefore safe on both halves.
set s1_regs [get_registers {emu|u_game|u_game|u_main|u_cpu|s1_*}]
set_multicycle_path -from $cpu_regs -to $s1_regs -setup -end 2
set_multicycle_path -from $cpu_regs -to $s1_regs -hold  -end 1
set_multicycle_path -from $s1_regs -to $cpu_regs -setup -end 2
set_multicycle_path -from $s1_regs -to $cpu_regs -hold  -end 1
