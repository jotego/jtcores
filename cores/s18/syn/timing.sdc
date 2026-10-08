set s18_vdp_root {*jts18_game_sdram:u_game|jts18_game:u_game|jts18_video:u_video|jts18_vdp:u_vdp}

foreach s18_vdp_mcp [list \
    [get_keepers -nowarn ${s18_vdp_root}|ym7101:u_vdp|*] \
    [get_keepers -nowarn ${s18_vdp_root}|vram:u_vram|*] \
    [get_keepers -nowarn ${s18_vdp_root}|clk2] \
    [get_keepers -nowarn ${s18_vdp_root}|rst_n] \
    [get_keepers -nowarn ${s18_vdp_root}|edclk_l] \
    [get_keepers -nowarn ${s18_vdp_root}|asn_r] \
    [get_keepers -nowarn ${s18_vdp_root}|rnw_r] \
    [get_keepers -nowarn ${s18_vdp_root}|dsn_r*] \
] {
    if { [get_collection_size $s18_vdp_mcp] > 0 } {
        set_multicycle_path -from $s18_vdp_mcp -setup 2
        set_multicycle_path -from $s18_vdp_mcp -hold 1
    }
}
