##
## DEVICE  Artix7 A35T, A100T, A200T
##

# Set pin definitions for downstream constraints
set RAM_CLK DRAM_CLK
set RAM_OUT {DRAM_DQ* DRAM_ADDR* DRAM_BA* DRAM_RAS_N DRAM_CAS_N DRAM_WE_N DRAM_*DQM DRAM_CS_N DRAM_CKE}
set RAM_IN {DRAM_D*}

set VGA_OUT {VGA_R[*] VGA_G[*] VGA_B[*] VGA_HS VGA_VS}

# non timing-critical pins would be in the "FALSE_IN/OUT" collection (IN inputs, OUT outputs)
set FALSE_OUT {LED* PWM_AUDIO_* PS2_* JOY_SEL UART_TXD SD_CS_N_O SD_MOSI_O SD_SCLK_O dp_tx_lane_* dp_tx_auxch_tx_* dp_tx_auxch_rx_*}
set FALSE_IN  {PS2_* JOY_DATA SD_MISO_I EAR_I UART_RXD dp_refclk_* dp_tx_hp_detect dp_tx_auxch_tx_* dp_tx_auxch_rx_*}


#**************************************************************
# Time Information
#**************************************************************

#set_time_format -unit ns -decimal_places 3

#**************************************************************
# Create Clock
#**************************************************************

# create_clock -name {CLOCK_27[0]} -period 37.037 -waveform { 0.000 18.518 } [get_ports {CLOCK_27[0]}]
# create_clock -name {SPI_SCK}  -period 41.666 -waveform { 20.8 41.666 } [get_ports {SPI_SCK}]

#**************************************************************
# Create Generated Clock
#**************************************************************

#derive_pll_clocks -create_base_clocks

create_clock -name {clk_50} -period 20.000 -waveform {0.000 10.000} { CLK_50 }

create_generated_clock -name spiclk -source [get_ports CLK_50] -divide_by 16 [get_pins controller/spi/sck_reg/Q]

set hostclk { clk_50 }
set supportclk { clk_50 }
set topmodule "guest/"

# set sdram_clock "guest/u_clocks/u_pll_game/clk_out3_pll"

create_generated_clock -name SDRAM_CLK -source [get_pins guest/u_clocks/u_pll_game/mmcm_adv_inst/CLKOUT2] -divide_by 1 [get_ports ${RAM_CLK}]

#**************************************************************
# Set Clock Latency
#**************************************************************

#**************************************************************
# Set Clock Uncertainty
#**************************************************************
#derive_clock_uncertainty

#**************************************************************
# Set Input Delay
#**************************************************************

# This is tAC in the data sheet. It is the time it takes to the
# output pins of the SDRAM to change after a new clock edge.
# This is used to calculate set-up time conditions in the FF
# latching the signal inside the FPGA
set_input_delay -clock SDRAM_CLK -max 6 [get_ports ${RAM_IN}]

# This is tOH in the data sheet. It is the time data is hold at the
# output pins of the SDRAM after a new clock edge.
# This is used to calculate hold time conditions in the FF
# latching the signal inside the FPGA (3.2)
set_input_delay -clock SDRAM_CLK -min 3 [get_ports ${RAM_IN}]

#**************************************************************
# Set Output Delay
#**************************************************************

# This is tDS in the data sheet, setup time, spec is 1.5ns
set_output_delay -clock SDRAM_CLK -max 1.5 \
    [get_ports ${RAM_OUT}]
# This is tDH in the data sheet, hold time, spec is 0.8ns
set_output_delay -clock  SDRAM_CLK -min -0.8 \
    [get_ports ${RAM_OUT}]


#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group [get_clocks spiclk] -group [get_clocks {guest/u_clocks/u_pll_game/clk_out1_clk_wiz_0 clk_out2_clk_wiz_0 clk_out3_clk_wiz_0 clk_out4_clk_wiz_0 clk_out5_clk_wiz_0 dp_refclk tx_symbol_clk}]

set_clock_groups -asynchronous -group [get_clocks $hostclk] -group [get_clocks {guest/u_clocks/u_pll_game/clk_out1_clk_wiz_0 clk_out2_clk_wiz_0 clk_out3_clk_wiz_0 clk_out4_clk_wiz_0 clk_out5_clk_wiz_0 dp_refclk tx_symbol_clk}]
set_clock_groups -asynchronous -group [get_clocks $supportclk] -group [get_clocks {guest/u_clocks/u_pll_game/clk_out1_clk_wiz_0 clk_out2_clk_wiz_0 clk_out3_clk_wiz_0 clk_out4_clk_wiz_0 clk_out5_clk_wiz_0 dp_refclk tx_symbol_clk}]
set_clock_groups -asynchronous -group [get_clocks spiclk] -group [get_clocks SDRAM_CLK]
set_clock_groups -asynchronous -group [get_clocks $hostclk] -group [get_clocks SDRAM_CLK]
set_clock_groups -asynchronous -group [get_clocks $supportclk] -group [get_clocks SDRAM_CLK]


#**************************************************************
# Set False Path
#**************************************************************

set_false_path -to [get_ports ${FALSE_OUT}]
set_false_path -from [get_ports ${FALSE_IN}]

# These are static signals that don't need to be concerned with
set_false_path -from [get_cells ${topmodule}u_frame/u_board/u_dip/enable_psg_reg]
set_false_path -from [get_cells ${topmodule}u_frame/u_board/u_dip/enable_fm_reg]

# Reset synchronization signal
set_false_path -from [get_cells ${topmodule}u_frame/u_board/u_reset/rst_rom_reg[0]] -to [get_cells ${topmodule}u_frame/u_board/u_reset/rst_rom_sync_reg]

#**************************************************************
# Set Multicycle Path
#**************************************************************

set_multicycle_path -hold -end -from  [get_clocks {SDRAM_CLK}]  -to  [get_clocks {clk_out2_clk_wiz_0}] 2

set_multicycle_path -setup -end -from [get_ports ${RAM_IN}] -to [get_cells ${topmodule}u_frame/u_board/u_sdram/dout_reg[*]] 2

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

# set_input_delay -clock SPI_SCK -max 6.4 [get_ports SPI_DI]
# set_input_delay -clock SPI_SCK -min 3.2 [get_ports SPI_DI]
# set_input_delay -clock SPI_SCK -max 6.4 [get_ports SPI_SS*]
# set_input_delay -clock SPI_SCK -min 3.2 [get_ports SPI_SS*]
# set_input_delay -clock SPI_SCK -max 6.4 [get_ports CONF_DATA0]
# set_input_delay -clock SPI_SCK -min 3.2 [get_ports CONF_DATA0]
#
#

# set_output_delay -add_delay -max -clock SPI_SCK  6.4 [get_ports SPI_DO]
# set_output_delay -add_delay -min -clock SPI_SCK  3.2 [get_ports SPI_DO]

set_false_path -to [get_cells {*/jtframe_sync:*/synchronizer[*].s_reg[0]}]


#**************************************************************
# # TIMINGS S16B   ./cores/s16b/syn/timing.sdc
#**************************************************************
# # Games using the MCU don't use the FD1094/89
# set_false_path -from [get_keepers *mcu*] -to [get_keepers *fd1094*]
# set_false_path -from [get_keepers *mcu*] -to [get_keepers *fd1089*]

# # Most -but not all- of JT7751 runs under a clock enable signal at 640kHz
# # The CPU interface is not cen'ed but it has small combinational logic
# # so the risk of including it here is low
# set_multicycle_path -from {*|jt7759:u_pcm|*} -to {*|jt7759:u_pcm|*} -setup -end 2
# set_multicycle_path -from {*|jt7759:u_pcm|*} -to {*|jt7759:u_pcm|*} -hold -end 2


#**************************************************************
# # TIMINGS S16    ./cores/s16b/syn/timing.sdc
#**************************************************************
# # Most -but not all- of JT51 runs under a clock enable signal at 4MHz
# # The CPU interface is not cen'ed but it has small combinational logic
# # so the risk of including it here is low
# set_multicycle_path -from {*|jt51:u_jt51|*} -to {*|jt51:u_jt51|*} -setup -end 2
# set_multicycle_path -from {*|jt51:u_jt51|*} -to {*|jt51:u_jt51|*} -hold -end 2

# set_multicycle_path -from [get_pins -hierarchical -regexp guest/u_game/u_game/u_sound/u_jt51/] -to [get_pins -hierarchical u_jt51/*] -setup -end 2
# set_multicycle_path -from {-hierarchical "*u_jt51*"} -to {-hierarchical "*u_jt51*"} -hold -end 2
