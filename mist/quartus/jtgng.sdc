## Generated SDC file "jtgng.out.sdc"

## Copyright (C) 1991-2013 Altera Corporation
## Your use of Altera Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Altera Program License 
## Subscription Agreement, Altera MegaCore Function License 
## Agreement, or other applicable license agreement, including, 
## without limitation, that your use is for the sole purpose of 
## programming logic devices manufactured by Altera and sold by 
## Altera or its authorized distributors.  Please refer to the 
## applicable agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus II"
## VERSION "Version 13.1.0 Build 162 10/23/2013 SJ Web Edition"

## DATE    "Thu Aug 10 21:25:00 2017"

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
create_clock -name {jtgng_vga:vga_conv|vga_hsync} -period 31777.000 -waveform { 0.000 15888.500 } 


#**************************************************************
# Create Generated Clock
#**************************************************************

derive_pll_clocks -create_base_clocks
create_generated_clock -name {sdclk_pin} -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -master_clock {clk_gen|altpll_component|auto_generated|pll1|clk[2]} [get_ports {SDRAM_CLK}] 
create_generated_clock -name {jtgng_game:game|jtgng_main:u_main|mc6809:u_cpu|rE} -source [get_nets {clk_gen|altpll_component|auto_generated|wire_pll1_clk[1]}] -divide_by 4 -phase 135.000 -master_clock {clk_gen|altpll_component|auto_generated|pll1|clk[1]} 
create_generated_clock -name {jtgng_game:game|jtgng_main:u_main|mc6809:u_cpu|rQ} -source [get_nets {clk_gen|altpll_component|auto_generated|wire_pll1_clk[1]}] -divide_by 4 -phase 45.000 -master_clock {clk_gen|altpll_component|auto_generated|pll1|clk[1]} 



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

set_input_delay -clock sdclk_pin -max 6.4 [get_ports SDRAM_DQ[*]]
set_input_delay -clock sdclk_pin -min 3.2 [get_ports SDRAM_DQ[*]]

#**************************************************************
# Set Output Delay
#**************************************************************

set_output_delay -clock sdclk_pin -max 1.5 [get_ports SDRAM_*]
set_output_delay -clock sdclk_pin -min -0.8 [get_ports SDRAM_*]



#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks {*|altpll_component|auto_generated|pll1|clk[*]}]

#**************************************************************
# Set False Path
#**************************************************************

# set_false_path  -from  [get_clocks {clk_E}]  -to  [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}]
# set_false_path  -from  [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}]  -to  [get_clocks {rE}]

#**************************************************************
# Set Multicycle Path
#**************************************************************

# set_multicycle_path -from [get_clocks {sdclk_pin}] -to [get_clocks clk_sdram] -setup -end 2


#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

