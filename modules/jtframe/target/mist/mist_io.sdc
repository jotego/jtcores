##
## DEVICE  "EP3C25E144C8"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {CLOCK_27[0]} -period 37.037 -waveform { 0.000 18.518 } [get_ports {CLOCK_27[0]}]
create_clock -name {SPI_SCK}  -period 41.666 -waveform { 20.8 41.666 } [get_ports {SPI_SCK}]

derive_pll_clocks -create_base_clocks


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

# This is tOH in the data sheet. It is the time data is hold at the
# output pins of the SDRAM after a new clock edge.
# This is used to calculate hold time conditions in the FF
# latching the signal inside the FPGA (3.2)
set_input_delay -clock SDRAM_CLK -min 3 [get_ports SDRAM_DQ[*]]

#**************************************************************
# Set Output Delay
#**************************************************************

# This is tDS in the data sheet, setup time, spec is 1.5ns
set_output_delay -clock SDRAM_CLK -max 1.5 \
    [get_ports {SDRAM_A[*] SDRAM_BA[*] SDRAM_CKE SDRAM_DQMH SDRAM_DQML \
                SDRAM_DQ[*] SDRAM_nCAS SDRAM_nCS SDRAM_nRAS SDRAM_nWE}]
# This is tDH in the data sheet, hold time, spec is 0.8ns
set_output_delay -clock  SDRAM_CLK -min -0.8 \
    [get_ports {SDRAM_A[*] SDRAM_BA[*] SDRAM_CKE SDRAM_DQMH SDRAM_DQML \
                SDRAM_DQ[*] SDRAM_nCAS SDRAM_nCS SDRAM_nRAS SDRAM_nWE}]



#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks {*|altpll_component|auto_generated|pll1|clk[*]}]

#**************************************************************
# Set False Path
#**************************************************************

set_false_path -to [get_ports {LED}]
set_false_path -to [get_ports {AUDIO_L}]
set_false_path -to [get_ports {AUDIO_R}]
set_false_path -to [get_ports {VGA_*}]

# These are static signals that don't need to be concerned with
set_false_path -from [get_registers {u_frame|u_board|u_dip|enable_psg}]
set_false_path -from [get_registers {:u_frame|u_board|u_dip|enable_fm}]

# Reset synchronization signal
set_false_path -from [get_keepers {jtframe_mist:u_frame|jtframe_board:u_board|jtframe_reset:u_reset|rst_rom[0]}] -to [get_keepers {jtframe_mist:u_frame|jtframe_board:u_board|jtframe_reset:u_reset|rst_rom_sync}]

#**************************************************************
# Set Multicycle Path
#**************************************************************

set_multicycle_path -hold -end -from  [get_clocks {SDRAM_CLK}]  -to  [get_clocks {u_clocks|u_pll_game|altpll_component|auto_generated|pll1|clk[1]}] 2

set_multicycle_path -setup -end -from [get_keepers {SDRAM_DQ[*]}] -to [get_keepers {jtframe_mist:u_frame|jtframe_board:u_board|jtframe_sdram64:u_sdram|dout[*]}] 2

# set_multicycle_path -from [get_clocks {u_clocks|u_pll_game|altpll_component|auto_generated|pll1|clk[1]}] -to [get_clocks {u_clocks|u_pll_game|altpll_component|auto_generated|pll1|clk[2]}] -start 2

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

set_input_delay -clock SPI_SCK -max 6.4 [get_ports SPI_DI]
set_input_delay -clock SPI_SCK -min 3.2 [get_ports SPI_DI]
set_input_delay -clock SPI_SCK -max 6.4 [get_ports SPI_SS*]
set_input_delay -clock SPI_SCK -min 3.2 [get_ports SPI_SS*]
set_input_delay -clock SPI_SCK -max 6.4 [get_ports CONF_DATA0]
set_input_delay -clock SPI_SCK -min 3.2 [get_ports CONF_DATA0]
#
#

set_output_delay -add_delay -max -clock SPI_SCK  6.4 [get_ports SPI_DO]
set_output_delay -add_delay -min -clock SPI_SCK  3.2 [get_ports SPI_DO]

set_false_path -to [get_keepers {*|jtframe_sync:*|synchronizer[*].s[0]}]
