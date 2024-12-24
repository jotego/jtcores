set_multicycle_path -from {jts18_game_sdram:u_game|jts18_game:u_game|jts18_video:u_video|jts18_vdp:u_vdp|ym7101:u_vdp|*} -setup 2
set_multicycle_path -from {jts18_game_sdram:u_game|jts18_game:u_game|jts18_video:u_video|jts18_vdp:u_vdp|ym7101:u_vdp|*} -hold 1

set_multicycle_path -from {jts18_game_sdram:u_game|jts18_game:u_game|jts18_video:u_video|jts18_vdp:u_vdp|clk2} -setup 2
set_multicycle_path -from {jts18_game_sdram:u_game|jts18_game:u_game|jts18_video:u_video|jts18_vdp:u_vdp|clk2} -hold 1

set_multicycle_path -from {jts18_game_sdram:u_game|jts18_game:u_game|jts18_video:u_video|jts18_vdp:u_vdp|rst_n} -setup 2
set_multicycle_path -from {jts18_game_sdram:u_game|jts18_game:u_game|jts18_video:u_video|jts18_vdp:u_vdp|rst_n} -hold 1

set_multicycle_path -from {jts18_game_sdram:u_game|jts18_game:u_game|jts18_video:u_video|jts18_vdp:u_vdp|edclk_l} -setup 2
set_multicycle_path -from {jts18_game_sdram:u_game|jts18_game:u_game|jts18_video:u_video|jts18_vdp:u_vdp|edclk_l} -hold 1

set_multicycle_path -from {jts18_game_sdram:u_game|jts18_game:u_game|jts18_main:u_main|jtframe_m68k:u_cpu|fx68k:u_cpu|busControl:busControl|rAS} \
                   -to {jts18_game_sdram:u_game|jts18_game:u_game|jts18_video:u_video|jts18_vdp:u_vdp|ym7101:u_vdp|*} -end -setup 2
set_multicycle_path -from {jts18_game_sdram:u_game|jts18_game:u_game|jts18_main:u_main|jtframe_m68k:u_cpu|fx68k:u_cpu|busControl:busControl|rAS} \
                   -to {jts18_game_sdram:u_game|jts18_game:u_game|jts18_video:u_video|jts18_vdp:u_vdp|ym7101:u_vdp|*} -end -hold 1

set_multicycle_path -setup -end -from [get_keepers {jts18_game_sdram:u_game|jts18_game:u_game|jts18_main:u_main|jtframe_m68k:u_cpu|fx68k:u_cpu|busControl:busControl|rRWn}] -to [get_keepers {jts18_game_sdram:u_game|jts18_game:u_game|jts18_video:u_video|jts18_vdp:u_vdp|ym7101:u_vdp|ym_cnt_bit_load:cnt_sa_low_2|ym_sr_bit_array:mem|ym_sr_bit:l1[*].sr|v1[0]}] 2
set_multicycle_path -hold -end -from [get_keepers {jts18_game_sdram:u_game|jts18_game:u_game|jts18_main:u_main|jtframe_m68k:u_cpu|fx68k:u_cpu|busControl:busControl|rRWn}] -to [get_keepers {jts18_game_sdram:u_game|jts18_game:u_game|jts18_video:u_video|jts18_vdp:u_vdp|ym7101:u_vdp|ym_cnt_bit_load:cnt_sa_low_2|ym_sr_bit_array:mem|ym_sr_bit:l1[*].sr|v1[0]}] 2
