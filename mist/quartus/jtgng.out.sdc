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

## DATE    "Sun Aug 20 22:12:57 2017"

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
create_clock -name {SPI_SCK} -period 41.666 -waveform { 0.000 0.500 } [get_ports {SPI_SCK}]
create_clock -name {jtgng_vga:vga_conv|vga_hsync} -period 31777.000 -waveform { 0.000 15888.500 } 


#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name {clk_gen|altpll_component|auto_generated|pll1|clk[0]} -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 2 -divide_by 9 -master_clock {CLOCK_27[0]} [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] 
create_generated_clock -name {clk_gen|altpll_component|auto_generated|pll1|clk[1]} -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 8 -divide_by 9 -master_clock {CLOCK_27[0]} [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] 
create_generated_clock -name {clk_gen|altpll_component|auto_generated|pll1|clk[2]} -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 10 -divide_by 3 -master_clock {CLOCK_27[0]} [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] 
create_generated_clock -name {clk_gen|altpll_component|auto_generated|pll1|clk[3]} -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 8 -divide_by 9 -master_clock {CLOCK_27[0]} [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[3]}] 
create_generated_clock -name {clk_gen2|altpll_component|auto_generated|pll1|clk[0]} -source [get_pins {clk_gen2|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 25 -divide_by 24 -master_clock {clk_gen|altpll_component|auto_generated|pll1|clk[3]} [get_pins {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] 
create_generated_clock -name {rE} -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -divide_by 4 -phase 135.000 -master_clock {clk_gen|altpll_component|auto_generated|pll1|clk[0]} [get_registers { jtgng_game:game|jtgng_main:main|mc6809:cpu|rE }] 
create_generated_clock -name {rQ} -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -divide_by 4 -phase 45.000 -master_clock {clk_gen|altpll_component|auto_generated|pll1|clk[0]} [get_registers { jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ }] 
create_generated_clock -name {sdclk_pin} -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -master_clock {clk_gen|altpll_component|auto_generated|pll1|clk[2]} [get_ports {SDRAM_CLK}] 


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {rE}] -rise_to [get_clocks {rE}]  0.030  
set_clock_uncertainty -rise_from [get_clocks {rE}] -fall_to [get_clocks {rE}]  0.030  
set_clock_uncertainty -rise_from [get_clocks {rE}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {rE}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {rE}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {rE}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {rE}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {rE}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {rE}] -rise_to [get_clocks {rE}]  0.030  
set_clock_uncertainty -fall_from [get_clocks {rE}] -fall_to [get_clocks {rE}]  0.030  
set_clock_uncertainty -fall_from [get_clocks {rE}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {rE}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {rE}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {rE}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {rE}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {rE}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {rQ}] -rise_to [get_clocks {rE}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {rQ}] -fall_to [get_clocks {rE}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {rQ}] -rise_to [get_clocks {rQ}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {rQ}] -fall_to [get_clocks {rQ}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {rQ}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {rQ}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {rQ}] -rise_to [get_clocks {rE}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {rQ}] -fall_to [get_clocks {rE}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {rQ}] -rise_to [get_clocks {rQ}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {rQ}] -fall_to [get_clocks {rQ}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {rQ}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {rQ}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {SPI_SCK}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -setup 0.090  
set_clock_uncertainty -rise_from [get_clocks {SPI_SCK}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -hold 0.120  
set_clock_uncertainty -rise_from [get_clocks {SPI_SCK}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -setup 0.090  
set_clock_uncertainty -rise_from [get_clocks {SPI_SCK}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -hold 0.120  
set_clock_uncertainty -rise_from [get_clocks {SPI_SCK}] -rise_to [get_clocks {SPI_SCK}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {SPI_SCK}] -fall_to [get_clocks {SPI_SCK}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {SPI_SCK}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.090  
set_clock_uncertainty -rise_from [get_clocks {SPI_SCK}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.120  
set_clock_uncertainty -rise_from [get_clocks {SPI_SCK}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.090  
set_clock_uncertainty -rise_from [get_clocks {SPI_SCK}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.120  
set_clock_uncertainty -fall_from [get_clocks {SPI_SCK}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -setup 0.090  
set_clock_uncertainty -fall_from [get_clocks {SPI_SCK}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -hold 0.120  
set_clock_uncertainty -fall_from [get_clocks {SPI_SCK}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -setup 0.090  
set_clock_uncertainty -fall_from [get_clocks {SPI_SCK}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] -hold 0.120  
set_clock_uncertainty -fall_from [get_clocks {SPI_SCK}] -rise_to [get_clocks {SPI_SCK}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {SPI_SCK}] -fall_to [get_clocks {SPI_SCK}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {SPI_SCK}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.090  
set_clock_uncertainty -fall_from [get_clocks {SPI_SCK}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.120  
set_clock_uncertainty -fall_from [get_clocks {SPI_SCK}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.090  
set_clock_uncertainty -fall_from [get_clocks {SPI_SCK}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.120  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {rE}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {rE}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.130  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.150  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.130  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.150  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {rQ}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {rQ}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {rE}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {rE}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.130  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.150  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.130  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.150  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {rQ}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {rQ}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[2]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.130  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.150  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.130  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.150  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.130  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.150  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.130  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.150  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  


#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

set_false_path -from [get_keepers {user_io:userio|joystick_0[*]}] -to [get_keepers {jtgng_game:game|jtgng_main:main|cpu_din[*]}]
set_false_path -from [get_keepers {user_io:userio|joystick_1[*]}] -to [get_keepers {jtgng_game:game|jtgng_main:main|cpu_din[*]}]
set_false_path -from [get_keepers {user_io:userio|status[*]}] -to [get_keepers {jtgng_game:game|jtgng_main:main|cpu_din[*]}]
set_false_path -from [get_keepers {user_io:userio|status[5]}] -to [get_keepers {jtgng_game:game|jtgng_main:main|nRESET}]


#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

