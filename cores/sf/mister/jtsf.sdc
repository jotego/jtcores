# OBJ memory is troubled in MiSTer at full clock speed, but it can be
# set as multicycle because clock enable duty cycles is less than 50%

set_multicycle_path -hold -end -from [get_keepers {emu:emu|jtsf_game:u_game|jtsf_main:u_main|jtframe_dual_ram:u_objhi|altsyncram:mem_rtl_0|altsyncram_65s1:auto_generated|ram_block1a0~portb_we_reg}] -to [get_keepers {emu:emu|jtsf_game:u_game|jtsf_video:u_video|jtgng_obj:u_obj|jtgng_objdma:u_dma|wr_data[*]}] 2
set_multicycle_path -hold -end -from [get_keepers {emu:emu|jtsf_game:u_game|jtsf_main:u_main|jtframe_dual_ram:u_objlow|altsyncram:mem_rtl_0|altsyncram_65s1:auto_generated|ram_block1a0~portb_we_reg}] -to [get_keepers {emu:emu|jtsf_game:u_game|jtsf_video:u_video|jtgng_obj:u_obj|jtgng_objdma:u_dma|wr_data[*]}] 2
