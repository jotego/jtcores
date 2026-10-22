package require -exact qsys 16.1

set_module_property NAME jttms10_fpga_runner
set_module_property VERSION 1.0
set_module_property GROUP "Jotego/Regression"
set_module_property DISPLAY_NAME "JTTMS10 FPGA Regression Runner"
set_module_property DESCRIPTION "Autonomous TMS34010 timing batch executor"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set component_dir [file dirname [info script]]

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL jttms10_fpga_runner

foreach path [glob -nocomplain [file join $component_dir *.v]] {
    set file [file tail $path]
    if {$file eq "jttms10_fpga_runner.v"} {
        add_fileset_file $file VERILOG PATH $file TOP_LEVEL_FILE
    } else {
        add_fileset_file $file VERILOG PATH $file
    }
}
foreach path [glob -nocomplain [file join $component_dir *.vh]] {
    set file [file tail $path]
    add_fileset_file $file OTHER PATH $file
}
foreach path [glob -nocomplain [file join $component_dir *.hex]] {
    set file [file tail $path]
    add_fileset_file $file HEX PATH $file
}
foreach path [glob -nocomplain [file join $component_dir *.uc]] {
    set file [file tail $path]
    add_fileset_file $file OTHER PATH $file
}
add_interface clk clock sink
add_interface_port clk clk clk Input 1

add_interface reset_n reset sink
set_interface_property reset_n associatedClock clk
set_interface_property reset_n synchronousEdges DEASSERT
add_interface_port reset_n reset_n reset_n Input 1

add_interface s0 avalon end
set_interface_property s0 addressUnits WORDS
set_interface_property s0 associatedClock clk
set_interface_property s0 associatedReset reset_n
set_interface_property s0 bitsPerSymbol 8
set_interface_property s0 readLatency 1
set_interface_property s0 writeWaitTime 0
set_interface_property s0 holdTime 0
set_interface_property s0 maximumPendingReadTransactions 0
add_interface_port s0 avs_address address Input 4
add_interface_port s0 avs_read read Input 1
add_interface_port s0 avs_readdata readdata Output 32
add_interface_port s0 avs_write write Input 1
add_interface_port s0 avs_writedata writedata Input 32
add_interface_port s0 avs_waitrequest waitrequest Output 1
