# Rev-B external timing from the DE25 Atari7800 port, using JTFRAME's
# forwarded game PLL clock. Values include the board flight-time mismatch.
set dram_clk [get_ports DRAM_CLK]
set pll_out [get_pins {core|game_clocks|system_pll|system_pll|tennm_ph2_iopll|out_clk[1]}]
create_generated_clock -name DE25_JT_SDRAM -source $pll_out $dram_clk
set dram_ref [get_clocks DE25_JT_SDRAM]
set dq [get_ports {DRAM_DQ[*]}]
set dram_out [get_ports {
    DRAM_ADDR[*] DRAM_BA[*] DRAM_DQ[*] DRAM_LDQM DRAM_UDQM
    DRAM_WE_n DRAM_CAS_n DRAM_RAS_n DRAM_CKE DRAM_CS_n[*]
}]
set_input_delay  -clock $dram_ref -reference_pin $dram_clk -max  5.600 $dq
set_input_delay  -clock $dram_ref -reference_pin $dram_clk -min  2.400 $dq
set_output_delay -clock $dram_ref -reference_pin $dram_clk -max  1.600 $dram_out
set_output_delay -clock $dram_ref -reference_pin $dram_clk -min -1.100 $dram_out
set_false_path -to $dram_clk
