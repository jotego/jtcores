# Specify root clocks
create_clock -period "50.0 MHz"  [get_ports FPGA_CLK1_50]
create_clock -period "50.0 MHz"  [get_ports FPGA_CLK2_50]
create_clock -period "50.0 MHz"  [get_ports FPGA_CLK3_50]
create_clock -period "100.0 MHz" [get_pins -compatibility_mode *|h2f_user0_clk]
create_clock -period "100.0 MHz" [get_pins -compatibility_mode spi|sclk_out] -name spi_sck
create_clock -period "10.0 MHz"  [get_pins -compatibility_mode hdmi_i2c|out_clk] -name hdmi_sck

derive_pll_clocks
derive_clock_uncertainty

# Decouple different clock groups (to simplify routing)
set_clock_groups -exclusive \
   -group [get_clocks { *|pll|pll_inst|altera_pll_i|*[*].*|divclk}] \
   -group [get_clocks { pll_hdmi|pll_hdmi_inst|altera_pll_i|*[0].*|divclk}] \
   -group [get_clocks { pll_audio|pll_audio_inst|altera_pll_i|*[0].*|divclk}] \
   -group [get_clocks { spi_sck}] \
   -group [get_clocks { hdmi_sck}] \
   -group [get_clocks { *|h2f_user0_clk}] \
   -group [get_clocks { FPGA_CLK1_50 }] \
   -group [get_clocks { FPGA_CLK2_50 }] \
   -group [get_clocks { FPGA_CLK3_50 }]

set_false_path -from [get_ports {KEY*}]
set_false_path -from [get_ports {BTN_*}]
set_false_path -to   [get_ports {LED_*}]
set_false_path -to   [get_ports {VGA_*}]
set_false_path -from [get_ports {VGA_EN}]
set_false_path -to   [get_ports {AUDIO_SPDIF}]
set_false_path -to   [get_ports {AUDIO_L}]
set_false_path -to   [get_ports {AUDIO_R}]
set_false_path -from {get_ports {SW[*]}}
set_false_path -to   {cfg[*]}
set_false_path -from {cfg[*]}
set_false_path -from {VSET[*]}
set_false_path -to   {wcalc[*] hcalc[*]}
set_false_path -to   {hdmi_width[*] hdmi_height[*]}
set_false_path -to   {deb_* btn_en btn_up}

set_multicycle_path -to {*_osd|osd_vcnt*} -setup 2
set_multicycle_path -to {*_osd|osd_vcnt*} -hold 1

set_false_path -to   {*_osd|v_cnt*}
set_false_path -to   {*_osd|v_osd_start*}
set_false_path -to   {*_osd|v_info_start*}
set_false_path -to   {*_osd|h_osd_start*}
set_false_path -from {*_osd|v_osd_start*}
set_false_path -from {*_osd|v_info_start*}
set_false_path -from {*_osd|h_osd_start*}
set_false_path -from {*_osd|rot*}
set_false_path -from {*_osd|dsp_width*}
set_false_path -to   {*_osd|half}

set_false_path -to   {WIDTH[*] HFP[*] HS[*] HBP[*] HEIGHT[*] VFP[*] VS[*] VBP[*]}
set_false_path -from {WIDTH[*] HFP[*] HS[*] HBP[*] HEIGHT[*] VFP[*] VS[*] VBP[*]}
set_false_path -to   {FB_BASE[*] FB_BASE[*] FB_WIDTH[*] FB_HEIGHT[*] LFB_HMIN[*] LFB_HMAX[*] LFB_VMIN[*] LFB_VMAX[*]}
set_false_path -from {FB_BASE[*] FB_BASE[*] FB_WIDTH[*] FB_HEIGHT[*] LFB_HMIN[*] LFB_HMAX[*] LFB_VMIN[*] LFB_VMAX[*]}
set_false_path -to   {vol_att[*] scaler_flt[*] led_overtake[*] led_state[*]}
set_false_path -from {vol_att[*] scaler_flt[*] led_overtake[*] led_state[*]}
set_false_path -from {aflt_* acx* acy* areset* arc*}
set_false_path -from {arx* ary*}
set_false_path -from {vs_line*}
set_false_path -from {ColorBurst_Range* PhaseInc* pal_en cvbs yc_en}

set_false_path -from {ascal|o_ihsize*}
set_false_path -from {ascal|o_ivsize*}
set_false_path -from {ascal|o_format*}
set_false_path -from {ascal|o_hdown}
set_false_path -from {ascal|o_vdown}
set_false_path -from {ascal|o_hmin* ascal|o_hmax* ascal|o_vmin* ascal|o_vmax* ascal|o_vrrmax* ascal|o_vrr}
set_false_path -from {ascal|o_hdisp* ascal|o_vdisp*}
set_false_path -from {ascal|o_htotal* ascal|o_vtotal*}
set_false_path -from {ascal|o_hsstart* ascal|o_vsstart* ascal|o_hsend* ascal|o_vsend*}
set_false_path -from {ascal|o_hsize* ascal|o_vsize*}
set_false_path -from {ascal|i_hdown ascal|i_hsize* ascal|i_ohsize*} -to {ascal|i_hburst*}

set_false_path -from {mcp23009|flg_*}
set_false_path -to   {sysmem|fpga_interfaces|clocks_resets|f2h*}

# JTFRAME
set_false_path -to [get_keepers {audio_out:audio_out|cl1[*]}]
set_false_path -to [get_keepers {audio_out:audio_out|cr1[*]}]

# The VU meter is a debug-only display. Audio-rate mixer data may cross into
# its system-clock accumulators without affecting game audio or video.
set jtframe_vumeter_mixed [get_keepers -nowarn {*|jtframe_rcmix:u_rcmix|mixed[*]}]
set jtframe_vumeter_ml    [get_keepers -nowarn {*|jtframe_vumeter:vumeter|ml[*]}]
set jtframe_vumeter_mr    [get_keepers -nowarn {*|jtframe_vumeter:vumeter|mr[*]}]
set jtframe_vumeter_l2r2  [get_keepers -nowarn {*|jtframe_vumeter:vumeter|l2r2[*]}]
if { [get_collection_size $jtframe_vumeter_mixed] > 0 } {
    if { [get_collection_size $jtframe_vumeter_ml] > 0 } {
        set_false_path -from $jtframe_vumeter_mixed -to $jtframe_vumeter_ml
    }
    if { [get_collection_size $jtframe_vumeter_mr] > 0 } {
        set_false_path -from $jtframe_vumeter_mixed -to $jtframe_vumeter_mr
    }
    if { [get_collection_size $jtframe_vumeter_l2r2] > 0 } {
        set_false_path -from $jtframe_vumeter_mixed -to $jtframe_vumeter_l2r2
    }
}

# Reset synchronization signal
set_false_path -from [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_reset:u_reset|rst_rom[0]}] -to [get_keepers {emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_reset:u_reset|rst_rom_sync}]
set_false_path -to emu:emu|sRESET[0]
set_false_path -to emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_reset:u_reset|rst_req_sync[0]
# static signals
set_false_path -from FB_EN
set_false_path -to deb_osd[0]
set_false_path -from emu:emu|jtframe_mister:u_frame|jtframe_board:u_board|jtframe_led:u_led|led

# Keep asynchronous crossings into the HPS clocks false, but leave the HPS
# user clock's internal ascal paths timed.  Its external interfaces still
# need the legacy asynchronous cut, scoped through their actual data pins.
set jtframe_hps_clocks [get_clocks {sysmem|fpga_interfaces|clocks_resets*}]
set jtframe_hps_user_clock [get_clocks {sysmem|fpga_interfaces|clocks_resets|h2f_user0_clk}]
set jtframe_ascal_keepers [get_keepers -nowarn {ascal:ascal|*}]
if {[get_collection_size $jtframe_ascal_keepers] == 0} {
    # Keep the original exception in builds without the HDMI scaler (for
    # example, MiSTer no-HDMI builds).
    set_false_path -from [get_clocks *] -to $jtframe_hps_clocks
} else {
    if {[get_collection_size $jtframe_hps_clocks] == 0 || [get_collection_size $jtframe_hps_user_clock] != 1} {
        error "cannot identify the expected MiSTer HPS user clock"
    }
    set jtframe_hps_root_pin [get_pins -nowarn -compatibility_mode {*|h2f_user0_clk}]
    if {[get_collection_size $jtframe_hps_root_pin] != 1} {
        error "cannot identify the MiSTer HPS user clock pin"
    }

    # Preserve the broad legacy cut for any additional HPS clocks, while
    # keeping all non-HPS-to-HPS asynchronous crossings on the user clock.
    set jtframe_other_hps_clocks [remove_from_collection $jtframe_hps_clocks $jtframe_hps_user_clock]
    if {[get_collection_size $jtframe_other_hps_clocks] > 0} {
        set_false_path -from [get_clocks *] -to $jtframe_other_hps_clocks
    }
    set jtframe_other_clocks [remove_from_collection [get_clocks *] $jtframe_hps_user_clock]
    set_false_path -from $jtframe_other_clocks -to $jtframe_hps_user_clock

    # The HPS user clock also feeds non-ascal registers and memory interfaces.
    # Cut those boundary paths only when they pass through their real adjacent
    # data/control pins; this does not mask HPS-clock paths within ascal.
    set jtframe_external_hps_keepers [remove_from_collection \
        [get_fanouts $jtframe_hps_root_pin] $jtframe_ascal_keepers]
    if {[get_collection_size $jtframe_external_hps_keepers] == 0} {
        error "cannot identify external MiSTer HPS clock endpoints"
    }
    set jtframe_external_hps_pin_names [dict create]
    foreach_in_collection keeper $jtframe_external_hps_keepers {
        foreach field {synch_edges asynch_edges fanout_edges} {
            set side [expr {$field eq "fanout_edges" ? "-dst" : "-src"}]
            foreach edge [get_node_info $keeper -$field] {
                set pin_name [get_node_info [get_edge_info $edge $side] -name]
                dict set jtframe_external_hps_pin_names $pin_name 1
            }
        }
    }
    if {[dict size $jtframe_external_hps_pin_names] == 0} {
        error "cannot identify external MiSTer HPS boundary pins"
    }
    set jtframe_external_hps_pins [get_pins -nowarn -compatibility_mode \
        [dict keys $jtframe_external_hps_pin_names]]
    if {[get_collection_size $jtframe_external_hps_pins] != [dict size $jtframe_external_hps_pin_names]} {
        error "unmatched MiSTer HPS boundary pins"
    }
    set_false_path -from $jtframe_hps_user_clock -through $jtframe_external_hps_pins \
        -to $jtframe_hps_user_clock
}

set_false_path -from [get_keepers {cfg_ready}] -to [get_keepers {vsd}]
set_false_path -from [get_keepers {cfg_ready}] -to [get_keepers {vsd2}]
set_false_path -from [get_keepers {cfg_ready}] -to [get_keepers {cfg_got}]

