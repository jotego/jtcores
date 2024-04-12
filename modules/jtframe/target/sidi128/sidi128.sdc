

#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {QSCK}  -period 41.666 -waveform { 20.8 41.666 } [get_ports {QSCK}]


#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name SDRAM_CLK -source \
    [get_pins {u_clocks|u_pll_game|altpll_component|auto_generated|pll1|clk[0]}] \
    -divide_by 1 \
    [get_ports SDRAM_CLK]

create_generated_clock -name SDRAM2_CLK -source \
    [get_pins {u_clocks2|u_pll_game|altpll_component|auto_generated|pll1|clk[0]}] \
    -divide_by 1 \
    [get_ports SDRAM2_CLK]

create_generated_clock -name HDMI_CLK -source \
    [get_pins {u_clocks|u_pll_game|altpll_component|auto_generated|pll1|clk[1]}] \
    -divide_by 1 \
    [get_ports HDMI_PCLK]

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
set_input_delay -clock SDRAM_CLK -max 6 [get_ports SDRAM_DQ[*]]

set_input_delay -clock SDRAM2_CLK -max 6 [get_ports SDRAM2_DQ[*]]

# This is tOH in the data sheet. It is the time data is hold at the
# output pins of the SDRAM after a new clock edge.
# This is used to calculate hold time conditions in the FF
# latching the signal inside the FPGA (3.2)
set_input_delay -clock SDRAM_CLK -min 3 [get_ports SDRAM_DQ[*]]

set_input_delay -clock SDRAM2_CLK -min 3 [get_ports SDRAM2_DQ[*]]

set_input_delay -clock QSCK -max 6.4 [get_ports {QCSn QDAT[*]}]
set_input_delay -clock QSCK -min 3.2 [get_ports {QCSn QDAT[*]}]

#**************************************************************
# Set Output Delay
#**************************************************************

# This is tDS in the data sheet, setup time, spec is 1.5ns
set_output_delay -clock SDRAM_CLK -max 1.5 \
    [get_ports {SDRAM_A[*] SDRAM_BA[*] SDRAM_CKE SDRAM_DQMH SDRAM_DQML \
                SDRAM_DQ[*] SDRAM_nCAS SDRAM_nCS SDRAM_nRAS SDRAM_nWE}]

set_output_delay -clock SDRAM2_CLK -max 1.5 \
    [get_ports {SDRAM2_A[*] SDRAM2_BA[*] SDRAM2_CKE SDRAM2_DQMH SDRAM2_DQML \
                SDRAM2_DQ[*] SDRAM2_nCAS SDRAM2_nCS SDRAM2_nRAS SDRAM2_nWE}]

# This is tDH in the data sheet, hold time, spec is 0.8ns
set_output_delay -clock  SDRAM_CLK -min -0.8 \
    [get_ports {SDRAM_A[*] SDRAM_BA[*] SDRAM_CKE SDRAM_DQMH SDRAM_DQML \
                SDRAM_DQ[*] SDRAM_nCAS SDRAM_nCS SDRAM_nRAS SDRAM_nWE}]

set_output_delay -clock  SDRAM2_CLK -min -0.8 \
    [get_ports {SDRAM2_A[*] SDRAM2_BA[*] SDRAM2_CKE SDRAM2_DQMH SDRAM2_DQML \
                SDRAM2_DQ[*] SDRAM2_nCAS SDRAM2_nCS SDRAM2_nRAS SDRAM2_nWE}]

# Video data hold time 0.5ns
set_output_delay -clock  HDMI_CLK -min -0.5 \
    [get_ports {HDMI_R[*] HDMI_G[*] HDMI_B[*] HDMI_DE HDMI_HS HDMI_VS}]

# Video data setup time 1.0ns
set_output_delay -clock  HDMI_CLK -max -1.0 \
    [get_ports {HDMI_R[*] HDMI_G[*] HDMI_B[*] HDMI_DE HDMI_HS HDMI_VS}]


#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group [get_clocks {QSCK}] -group [get_clocks {*|altpll_component|auto_generated|pll1|clk[*]}]

#**************************************************************
# Set False Path
#**************************************************************

set_false_path -to [get_ports {SPDIF}]
set_false_path -to [get_ports {HDMI_BCK HDMI_LRCK HDMI_SDATA}]
set_false_path -to [get_ports {I2S_BCK I2S_LRCK I2S_DATA}]
set_false_path -to [get_ports {HDMI_SCL HDMI_SDA}]
set_false_path -from [get_ports HDMI_SDA]

#**************************************************************
# Set Multicycle Path
#**************************************************************

set_multicycle_path -hold -end -to [get_clocks {HDMI_CLK}]  -from  [get_clocks {u_clocks|u_pll_game|altpll_component|auto_generated|pll1|clk[1]}] 2
set_multicycle_path -hold -end -to [get_clocks {HDMI_CLK}]  -from  [get_clocks {u_clocks|u_pll_game|altpll_component|auto_generated|pll1|clk[2]}] 2

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

