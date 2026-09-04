set_false_path -from [get_keepers {*|jtcps3_keyload:u_keyload|cps3_key1[*]}]
set_false_path -from [get_keepers {*|jtcps3_keyload:u_keyload|cps3_key2[*]}]

# QSPI download data is captured in the QSCK domain and consumed after the
# rclk3 toggle is synchronized into clk_sys. Exclude the CDC data/control edge
# reported between data_io's QSCK receiver and DATA_OUT block.
set_false_path -from [get_keepers {*|data_io:u_datain|data_w3[*]}] -to [get_keepers {*|data_io:u_datain|ioctl_dout[*]}]
set_false_path -from [get_keepers {*|data_io:u_datain|rclk3}] -to [get_keepers {*|data_io:u_datain|DATA_OUT.rclk3D}]

# SDRAM output path max_delay — see tasks/fitter.md
# The SDRAM controller FFs are placed far from the DDIO output cells
# (X46_Y19 → X50_Y0), causing long routing hops (4.3ns + 1.5ns = 58% of
# data delay). These constraints tell the fitter to prioritize placement
# and routing for the SDRAM control outputs.
# The clk96 setup relationship is 8.730 ns; with clock skew ~0.5 ns the
# achievable data delay target is ~8.1 ns.
set_max_delay -from [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|*}] \
              -to   [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|jtframe_burst_io:u_io|sdram_a[*]}] \
              8.0
set_max_delay -from [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|*}] \
              -to   [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|jtframe_burst_io:u_io|sdram_ba[*]}] \
              8.0
set_max_delay -from [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|*}] \
              -to   [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|jtframe_burst_io:u_io|sdram_nwe}] \
              8.0
set_max_delay -from [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|*}] \
              -to   [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|jtframe_burst_io:u_io|sdram_ncas}] \
              8.0
set_max_delay -from [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|*}] \
              -to   [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|jtframe_burst_io:u_io|sdram_nras}] \
              8.0
set_max_delay -from [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|*}] \
              -to   [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|jtframe_burst_io:u_io|sdram_ncs}] \
              8.0
set_max_delay -from [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|*}] \
              -to   [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|jtframe_burst_io:u_io|sdram_cke}] \
              8.0
set_max_delay -from [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|*}] \
              -to   [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|jtframe_burst_io:u_io|sdram_dqml}] \
              8.0
set_max_delay -from [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|*}] \
              -to   [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_board_sdram:u_sdram|jtframe_burst_sdram:u_sdram|jtframe_burst_io:u_io|sdram_dqmh}] \
              8.0
