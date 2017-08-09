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

## DATE    "Tue Aug  8 23:25:18 2017"

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
create_clock -name {SPI_SCK} -period 31.250 -waveform { 0.000 15.625 } [get_ports {SPI_SCK}]


#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE} -source [get_nets {clk_gen|altpll_component|auto_generated|wire_pll1_clk[0]}] -divide_by 4 -phase 270.000 -master_clock {clk_gen|altpll_component|auto_generated|pll1|clk[0]} [get_registers {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] 
create_generated_clock -name {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ} -source [get_nets {clk_gen|altpll_component|auto_generated|wire_pll1_clk[0]}] -divide_by 4 -phase 90.000 -master_clock {clk_gen|altpll_component|auto_generated|pll1|clk[0]} [get_registers {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] 
create_generated_clock -name {clk_gen|altpll_component|auto_generated|pll1|clk[0]} -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 2 -divide_by 9 -master_clock {CLOCK_27[0]} [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] 
create_generated_clock -name {clk_gen|altpll_component|auto_generated|pll1|clk[1]} -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 8 -divide_by 9 -master_clock {CLOCK_27[0]} [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] 
create_generated_clock -name {SDRAM_clk} -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 3 -master_clock {CLOCK_27[0]} [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[2]}] 
create_generated_clock -name {clk_gen|altpll_component|auto_generated|pll1|clk[3]} -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 8 -divide_by 9 -master_clock {CLOCK_27[0]} [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[3]}] 
create_generated_clock -name {clk_vga} -source [get_pins {clk_gen|altpll_component|auto_generated|pll1|clk[3]}] -multiply_by 25 -divide_by 24 -master_clock {clk_gen|altpll_component|auto_generated|pll1|clk[3]} [get_pins {clk_gen2|altpll_component|auto_generated|pll1|clk[0]}] 


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.070  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.100  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.070  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.100  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -setup 0.070  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -hold 0.100  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -setup 0.070  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -hold 0.100  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -rise_to [get_clocks {SDRAM_clk}] -setup 0.070  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -rise_to [get_clocks {SDRAM_clk}] -hold 0.100  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -fall_to [get_clocks {SDRAM_clk}] -setup 0.070  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -fall_to [get_clocks {SDRAM_clk}] -hold 0.100  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.070  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.100  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.070  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.100  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -setup 0.070  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -hold 0.100  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -setup 0.070  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -hold 0.100  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -rise_to [get_clocks {SDRAM_clk}] -setup 0.070  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -rise_to [get_clocks {SDRAM_clk}] -hold 0.100  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -fall_to [get_clocks {SDRAM_clk}] -setup 0.070  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -fall_to [get_clocks {SDRAM_clk}] -hold 0.100  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -setup 0.100  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -hold 0.070  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -setup 0.100  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -hold 0.070  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -setup 0.090  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -setup 0.090  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {SDRAM_clk}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {SDRAM_clk}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -setup 0.100  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -hold 0.070  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -setup 0.100  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -hold 0.070  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -setup 0.090  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -setup 0.090  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {SDRAM_clk}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {SDRAM_clk}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}]  0.010  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}]  0.010  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.060  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.090  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.060  
set_clock_uncertainty -rise_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.090  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}]  0.010  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}]  0.010  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.060  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.090  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.060  
set_clock_uncertainty -fall_from [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rQ}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.090  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {SDRAM_clk}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -setup 0.100  
set_clock_uncertainty -rise_from [get_clocks {SDRAM_clk}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -hold 0.070  
set_clock_uncertainty -rise_from [get_clocks {SDRAM_clk}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -setup 0.100  
set_clock_uncertainty -rise_from [get_clocks {SDRAM_clk}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -hold 0.070  
set_clock_uncertainty -rise_from [get_clocks {SDRAM_clk}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {SDRAM_clk}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {SDRAM_clk}] -rise_to [get_clocks {SDRAM_clk}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {SDRAM_clk}] -fall_to [get_clocks {SDRAM_clk}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {SDRAM_clk}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -setup 0.100  
set_clock_uncertainty -fall_from [get_clocks {SDRAM_clk}] -rise_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -hold 0.070  
set_clock_uncertainty -fall_from [get_clocks {SDRAM_clk}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -setup 0.100  
set_clock_uncertainty -fall_from [get_clocks {SDRAM_clk}] -fall_to [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}] -hold 0.070  
set_clock_uncertainty -fall_from [get_clocks {SDRAM_clk}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {SDRAM_clk}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {SDRAM_clk}] -rise_to [get_clocks {SDRAM_clk}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {SDRAM_clk}] -fall_to [get_clocks {SDRAM_clk}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}] -rise_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}] -fall_to [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[3]}]  0.020  


#**************************************************************
# Set Input Delay
#**************************************************************

set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[0]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[0]}]
set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[1]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[1]}]
set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[2]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[2]}]
set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[3]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[3]}]
set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[4]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[4]}]
set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[5]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[5]}]
set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[6]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[6]}]
set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[7]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[7]}]
set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[8]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[8]}]
set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[9]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[9]}]
set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[10]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[10]}]
set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[11]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[11]}]
set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[12]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[12]}]
set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[13]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[13]}]
set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[14]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[14]}]
set_input_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  6.400 [get_ports {SDRAM_DQ[15]}]
set_input_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  3.200 [get_ports {SDRAM_DQ[15]}]


#**************************************************************
# Set Output Delay
#**************************************************************

set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_A[0]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_A[0]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_A[1]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_A[1]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_A[2]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_A[2]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_A[3]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_A[3]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_A[4]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_A[4]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_A[5]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_A[5]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_A[6]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_A[6]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_A[7]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_A[7]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_A[8]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_A[8]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_A[9]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_A[9]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_A[10]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_A[10]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_A[11]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_A[11]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_A[12]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_A[12]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_BA[0]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_BA[0]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_BA[1]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_BA[1]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_CKE}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_CKE}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_CLK}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_CLK}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQMH}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQMH}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQML}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQML}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[0]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[0]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[1]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[1]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[2]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[2]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[3]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[3]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[4]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[4]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[5]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[5]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[6]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[6]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[7]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[7]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[8]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[8]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[9]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[9]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[10]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[10]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[11]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[11]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[12]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[12]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[13]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[13]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[14]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[14]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_DQ[15]}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_DQ[15]}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_nCAS}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_nCAS}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_nCS}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_nCS}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_nRAS}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_nRAS}]
set_output_delay -add_delay -max -clock [get_clocks {SDRAM_clk}]  1.500 [get_ports {SDRAM_nWE}]
set_output_delay -add_delay -min -clock [get_clocks {SDRAM_clk}]  -0.800 [get_ports {SDRAM_nWE}]


#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

set_false_path  -from  [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}]  -to  [get_clocks {SDRAM_clk}]
set_false_path  -from  [get_clocks {SDRAM_clk}]  -to  [get_clocks {jtgng_game:game|jtgng_main:main|mc6809:cpu|rE}]
set_false_path  -from  [get_clocks {SPI_SCK}]  -to  [get_clocks {clk_gen|altpll_component|auto_generated|pll1|clk[0]}]


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

