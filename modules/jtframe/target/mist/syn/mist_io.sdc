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
create_clock -name {SPI_SCK}  -period 41.666 -waveform { 20.8 41.666 } [get_ports {SPI_SCK}]

derive_pll_clocks -create_base_clocks


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


#**************************************************************
# Set Output Delay
#**************************************************************


#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks {*|altpll_component|auto_generated|pll1|clk[*]}]

#**************************************************************
# Set False Path
#**************************************************************

set_false_path -to [get_ports {LED}]
set_false_path -to [get_ports {AUDIO_L}]
set_false_path -to [get_ports {AUDIO_R}]
set_false_path -to [get_ports {VGA_*}]

# Reset synchronization signal
set_false_path -from [get_keepers {jtframe_mist:u_frame|jtframe_board:u_board|jtframe_reset:u_reset|rst_rom[0]}] -to [get_keepers {jtframe_mist:u_frame|jtframe_board:u_board|jtframe_reset:u_reset|rst_rom_sync}]

#**************************************************************
# Set Multicycle Path
#**************************************************************

# set_multicycle_path -from [get_clocks {u_clocks|u_pll_game|altpll_component|auto_generated|pll1|clk[1]}] -to [get_clocks {u_clocks|u_pll_game|altpll_component|auto_generated|pll1|clk[0]}] -start 2

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

set_input_delay -clock SPI_SCK -max 6.4 [get_ports SPI_DI]
set_input_delay -clock SPI_SCK -min 3.2 [get_ports SPI_DI]
set_input_delay -clock SPI_SCK -max 6.4 [get_ports SPI_SS*]
set_input_delay -clock SPI_SCK -min 3.2 [get_ports SPI_SS*]
set_input_delay -clock SPI_SCK -max 6.4 [get_ports CONF_DATA0]
set_input_delay -clock SPI_SCK -min 3.2 [get_ports CONF_DATA0]
#
#

set_output_delay -add_delay -max -clock SPI_SCK  6.4 [get_ports SPI_DO]
set_output_delay -add_delay -min -clock SPI_SCK  3.2 [get_ports SPI_DO]

set_false_path -to [get_keepers {*|jtframe_sync:*|synchronizer[*].s[0]}]

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
