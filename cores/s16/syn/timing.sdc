# Most -but not all- of JT51 runs under a clock enable signal at 4MHz
# The CPU interface is not cen'ed but it has small combinational logic
# so the risk of including it here is low
set_multicycle_path -from {*|jt51:u_jt51|*} -to {*|jt51:u_jt51|*} -setup -end 2
set_multicycle_path -from {*|jt51:u_jt51|*} -to {*|jt51:u_jt51|*} -hold -end 2

##################
# MiSTer specific

# false path between reset clock, pll clock and game clock:
set_false_path  -from  [get_clocks {emu|pll|jtframe_pll6293_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  -to  [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}]
set_false_path  -from  [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}]  -to  [get_clocks {emu|pll|jtframe_pll6293_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path  -from  [get_clocks {emu|pll|jtframe_pll6293_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  -to  [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}]
set_false_path  -from  [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}]  -to  [get_clocks {emu|pll|jtframe_pll6293_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path  -from  [get_clocks {emu|pll|jtframe_pll6293_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  -to  [get_clocks {pll_audio|pll_audio_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path  -from  [get_clocks {emu|pll|jtframe_pll6293_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  -to  [get_clocks {sysmem|fpga_interfaces|clocks_resets|h2f_user0_clk}]
set_false_path  -from  [get_clocks {sysmem|fpga_interfaces|clocks_resets|h2f_user0_clk}]  -to  [get_clocks {sysmem|fpga_interfaces|clocks_resets|h2f_user0_clk}]
set_false_path  -from  [get_clocks {sysmem|fpga_interfaces|clocks_resets|h2f_user0_clk}]  -to  [get_clocks {emu|pll|jtframe_pll6293_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path  -from  [get_clocks {pll_audio|pll_audio_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  -to  [get_clocks {emu|pll|jtframe_pll6293_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]

set_false_path  -from  [get_clocks {emu|pll|jtframe_pll6293_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  -to  [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}]
set_false_path  -from  [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}]  -to  [get_clocks {emu|pll|jtframe_pll6293_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path  -from  [get_clocks {emu|pll|jtframe_pll6293_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  -to  [get_clocks {emu|pll|jtframe_pll6293_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path  -from  [get_clocks {FPGA_CLK1_50}]  -to  [get_clocks {emu|pll|jtframe_pll6293_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path  -from  [get_clocks {FPGA_CLK2_50}]  -to  [get_clocks {emu|pll|jtframe_pll6293_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]


# HDMI configuration, it should be ok to have it multicycle
set_false_path -from [get_keepers {lowlat}]
set_false_path -from [get_keepers {cfg_done}]
set_false_path -from [get_keepers {cfg_custom_p1[*]}] -to [get_keepers {adj_address[*]}]
set_false_path -from [get_keepers {cfg_custom_p2[*]}] -to [get_keepers {adj_data[*]}]
set_false_path -from [get_keepers {cfg_got}] -to [get_keepers {gotd}]
set_false_path -from [get_keepers {cfg_custom_t}] -to [get_keepers {custd}]
set_false_path -from [get_keepers {pll_hdmi_adj:pll_hdmi_adj|i_vss_delay}] -to [get_keepers {pll_hdmi_adj:pll_hdmi_adj|ivss}]
