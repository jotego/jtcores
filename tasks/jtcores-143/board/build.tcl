package require ::quartus::project
set src [file normalize [file join [file dirname [info script]] ..]]
if {![info exists ::env(JTFRAME)]} { error "Source jtcores/setprj.sh first" }
project_new c96 -overwrite
set_global_assignment -name FAMILY "Cyclone V"
# Schematic part; conservative C8 timing.
set_global_assignment -name DEVICE 5CSEBA6U19C8
set_global_assignment -name TOP_LEVEL_ENTITY c96_top
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name VERILOG_FILE $src/rtl/c96_top.v
set_global_assignment -name VERILOG_FILE $src/rtl/c96_capture.v
set_global_assignment -name VERILOG_FILE $src/rtl/c96_pcm_sampler.v
set_global_assignment -name VERILOG_FILE $src/rtl/c96_yamaha_sampler.v
set_location_assignment PIN_E5 -to {pcm_pins[0]}
set_location_assignment PIN_F5 -to {pcm_pins[1]}
set_location_assignment PIN_A6 -to {pcm_pins[2]}
set_location_assignment PIN_A5 -to {pcm_pins[3]}
set_instance_assignment -name IO_STANDARD "1.8 V" -to {pcm_pins[*]}
set_instance_assignment -name WEAK_PULL_UP_RESISTOR OFF -to {pcm_pins[*]}
set_global_assignment -name VERILOG_FILE $::env(JTFRAME)/hdl/ram/jtframe_ram.v
set_global_assignment -name SDC_FILE $src/board/c96.sdc
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"
set_global_assignment -name NUM_PARALLEL_PROCESSORS 4
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
set_global_assignment -name STRATIXV_CONFIGURATION_SCHEME "PASSIVE PARALLEL X16"
set_global_assignment -name ENABLE_CONFIGURATION_PINS OFF
set_global_assignment -name CRC_ERROR_OPEN_DRAIN OFF
set_global_assignment -name ENABLE_OCT_DONE OFF
export_assignments
project_close
