package require qsys 25.1

create_system de25_game_pll
set_project_property DEVICE_FAMILY "Agilex 5"
set_project_property DEVICE A5EB013BB23BE4SCS

# Run in the generated project's ip/ directory. jtcore has already resolved
# macros.def, including the clock family and SDRAM96, into this revision's QSF.
set qsf_files [glob ../*.qsf]
if {[llength $qsf_files] != 1} { error "Expected one generated core QSF in the parent directory" }
set f [open [lindex $qsf_files 0]]
set settings [read $f]
close $f
set ref_mhz 50.0
set base_mhz 48.0
if {[regexp {VERILOG_MACRO "DE25_GAME_REF_HZ=([0-9]+)"} $settings -> hz]} {
    set ref_mhz [expr {$hz / 1.0e6}]
    set base_mhz $ref_mhz
}
if {![regexp {VERILOG_MACRO "JTFRAME_MCLK=([0-9]+)"} $settings -> master_hz]} {
    error "Missing JTFRAME_MCLK in generated core QSF"
}
set ram_mhz [expr {$master_hz / 1.0e6}]
set ram_shift_ps 5500.0
if {[regexp {VERILOG_MACRO "JTFRAME_180SHIFT=([0-9]+)"} $settings -> inverted] && $inverted} {
    set ram_shift_ps [expr {500000.0 / $ram_mhz}]
}

add_instance system_pll altera_iopll 21.0.0
set_instance_parameter_value system_pll gui_reference_clock_frequency $ref_mhz
set_instance_parameter_value system_pll gui_number_of_clocks 4
# The forwarded clock has its own output and board timing constraint.
set_instance_parameter_value system_pll gui_output_clock_frequency0 $base_mhz
set_instance_parameter_value system_pll gui_output_clock_frequency1 $ram_mhz
set_instance_parameter_value system_pll gui_phase_shift1 $ram_shift_ps
set_instance_parameter_value system_pll gui_output_clock_frequency2 [expr {$base_mhz / 2}]
set_instance_parameter_value system_pll gui_output_clock_frequency3 [expr {$base_mhz * 2}]

add_interface refclk clock sink
set_interface_property refclk EXPORT_OF system_pll.refclk

add_interface reset reset sink
set_interface_property reset EXPORT_OF system_pll.reset

add_interface locked conduit end
set_interface_property locked EXPORT_OF system_pll.locked

for {set index 0} {$index < 4} {incr index} {
    set interface_name "outclk${index}"
    add_interface $interface_name clock source
    set_interface_property $interface_name EXPORT_OF "system_pll.${interface_name}"
}

save_system de25_game_pll.qsys
