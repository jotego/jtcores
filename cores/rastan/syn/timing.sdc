# Operation Wolf C-chip MCU multicycle relaxation.
#
# The C-chip MCU (jttc0030cmd -> IKA87AD, a decap-accurate uPD78C11) advances
# only on the 12 MHz cchip_cen clock enable. cchip_cen is a fractional cen off
# the ~53.4 MHz game clock, so consecutive MCU register updates are always at
# least floor(53.4/12) = 4 game-clock cycles apart. Every internal register is
# gated by mcuclk_pcen: the cycle strobes opcode_tick and rw_tick (and hence
# cycle_tick) are all "& mcuclk_pcen", and the timing state machine is guarded
# by "if(mcuclk_pcen)" as well.
#
# Without this exception STA demands the entire MCU datapath -- instruction
# decode + the 16-bit DEU adder + flag generation -- close in a single 18.7 ns
# clk cycle. It cannot: the worst path (reg_OPCODE -> ... -> Add14 -> flag_Z) is
# ~21 ns, giving -2.6 ns setup slack and failing timing closure on Pocket.
#
# Relaxing intra-MCU paths to 2 cycles (37.5 ns budget vs. the ~21 ns path) is
# safe because both endpoints only sample on cen (>=4 cycles apart). This mirrors
# the cen-gated-block relaxation already used in cores/s16 (jt51) and s16b (jt7759).
set_multicycle_path -from {*|IKA87AD:u_mcu|*} -to {*|IKA87AD:u_mcu|*} -setup -end 2
set_multicycle_path -from {*|IKA87AD:u_mcu|*} -to {*|IKA87AD:u_mcu|*} -hold  -end 2
