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
#create_clock -name {jtgng_vga:vga_conv|vga_hsync} -period 1.000 -waveform { 0.000 0.500 } [get_registers {jtgng_vga:vga_conv|vga_hsync}]
create_clock -name {SPI_SCK} -period 41.666 -waveform { 0.000 0.500 } [get_ports {SPI_SCK}]
create_generated_clock -name {clk_E} -source [get_nets {clk_gen|altpll_component|auto_generated|wire_pll1_clk[0]}] -divide_by 4 -phase 180.000 -master_clock {clk_pxl} [get_keepers {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] 
create_generated_clock -name {clk_Q} -source [get_nets {game|main|cpu|rE}] -phase 270.000 -master_clock {clk_E} [get_nets {game|main|cpu|rQ}] 


#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name clk_pxl -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 2 -divide_by 9 -master_clock {CLOCK_27[0]} [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] 
create_generated_clock -name clk_rgb -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|inclk[1]}] -duty_cycle 50.000 -multiply_by 8 -divide_by 9 -master_clock {CLOCK_27[0]} [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] 
create_generated_clock -name clk_sdram -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|inclk[2]}] -duty_cycle 50.000 -multiply_by 10 -divide_by 3 -master_clock {CLOCK_27[0]} [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] 
create_generated_clock -name clk24 -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|inclk[3]}] -duty_cycle 50.000 -multiply_by 8 -divide_by 9 -master_clock {CLOCK_27[0]} [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[3]}] 
create_generated_clock -name clk_vga -source [get_pins {clk_gen2|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 25 -divide_by 24 -master_clock {clk24} [get_pins {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] 
create_generated_clock -name sdclk_pin -source [get_clocks clk_sdram] [get_ports {SDRAM_CLK}]

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

set_input_delay -clock sdclk_pin -max 6.4 [get_ports SDRAM_DQ*]
set_input_delay -clock sdclk_pin -min 3.2 [get_ports SDRAM_DQ*]

#**************************************************************
# Set Output Delay
#**************************************************************

set_output_delay -clock sdclk_pin -max 1.5 [get_ports SDRAM_*]
set_output_delay -clock sdclk_pin -min -0.8 [get_ports SDRAM_*]***



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************
set_false_path -from [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -to [get_keepers {jtgng_game:game|jtgng_rom:rom|pxl_sh[0]}]


#**************************************************************
# Set Multicycle Path
#**************************************************************

set_multicycle_path -from [get_clocks {sdclk_pin}] -to [get_clocks clk_sdram] -setup -end 2


#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

