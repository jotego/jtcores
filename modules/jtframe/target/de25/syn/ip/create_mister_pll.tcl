package require qsys 25.1

create_system mister_pll
set_project_property DEVICE_FAMILY "Agilex 5"
set_project_property DEVICE A5EB013BB23BE4SCS

add_instance system_pll altera_iopll 21.0.0
set_instance_parameter_value system_pll gui_reference_clock_frequency 50.0
set_instance_parameter_value system_pll gui_number_of_clocks 3
set_instance_parameter_value system_pll gui_output_clock_frequency0 100.0
set_instance_parameter_value system_pll gui_output_clock_frequency1 24.576
# Standard 640x480 HDMI pixel clock. PC110's VGA engine advances at exactly
# 25.175 MHz on average, so matching it here prevents the two-line scanout
# from drifting vertically through the source frame.
set_instance_parameter_value system_pll gui_output_clock_frequency2 25.175

add_interface refclk clock sink
set_interface_property refclk EXPORT_OF system_pll.refclk

add_interface reset reset sink
set_interface_property reset EXPORT_OF system_pll.reset

add_interface locked conduit end
set_interface_property locked EXPORT_OF system_pll.locked

for {set index 0} {$index < 3} {incr index} {
    set interface_name "outclk${index}"
    add_interface $interface_name clock source
    set_interface_property $interface_name EXPORT_OF "system_pll.${interface_name}"
}

save_system mister_pll.qsys
