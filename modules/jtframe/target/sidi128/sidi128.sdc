

#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************


#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name SDRAM2_CLK -source \
    [get_pins {u_clocks2|u_pll_game|altpll_component|auto_generated|pll1|clk[2]}] \
    -divide_by 1 \
    [get_ports SDRAM2_CLK]



#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty

#**************************************************************
# Set Input Delay
#**************************************************************

# This is tAC in the data sheet. It is the time it takes to the
# output pins of the SDRAM to change after a new clock edge.
# This is used to calculate set-up time conditions in the FF
# latching the signal inside the FPGA
set_input_delay -clock SDRAM2_CLK -max 6 [get_ports SDRAM2_DQ[*]]

# This is tOH in the data sheet. It is the time data is hold at the
# output pins of the SDRAM after a new clock edge.
# This is used to calculate hold time conditions in the FF
# latching the signal inside the FPGA (3.2)
set_input_delay -clock SDRAM2_CLK -min 3 [get_ports SDRAM2_DQ[*]]

#**************************************************************
# Set Output Delay
#**************************************************************

# This is tDS in the data sheet, setup time, spec is 1.5ns
set_output_delay -clock SDRAM2_CLK -max 1.5 \
    [get_ports {SDRAM2_A[*] SDRAM2_BA[*] SDRAM2_CKE SDRAM2_DQMH SDRAM2_DQML \
                SDRAM2_DQ[*] SDRAM2_nCAS SDRAM2_nCS SDRAM2_nRAS SDRAM2_nWE}]
# This is tDH in the data sheet, hold time, spec is 0.8ns
set_output_delay -clock  SDRAM2_CLK -min -0.8 \
    [get_ports {SDRAM2_A[*] SDRAM2_BA[*] SDRAM2_CKE SDRAM2_DQMH SDRAM2_DQML \
                SDRAM2_DQ[*] SDRAM2_nCAS SDRAM2_nCS SDRAM2_nRAS SDRAM2_nWE}]



#**************************************************************
# Set Clock Groups
#**************************************************************

#**************************************************************
# Set False Path
#**************************************************************

#**************************************************************
# Set Multicycle Path
#**************************************************************

set_multicycle_path -hold -end -from  [get_clocks {SDRAM2_CLK}]  -to  [get_clocks {u_clocks2|u_pll_game|altpll_component|auto_generated|pll1|clk[1]}] 2

#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************



#**************************************************************
# Set Input Delay
#**************************************************************

