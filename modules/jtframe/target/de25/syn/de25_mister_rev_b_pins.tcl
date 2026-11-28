# Import the exact rev-B locations and I/O standards from Terasic's GHRD.
set reference_qsf [file normalize ip/terasic-ghrd/golden_top.qsf]

if {![file exists $reference_qsf]} {
    post_message -type error "Missing Terasic rev-B pin reference: $reference_qsf"
    return -code error
}

set pin_file [open $reference_qsf r]
set pin_text [read $pin_file]
close $pin_file

set target_pattern {^(CLOCK0_50|CLOCK1_50|CLOCK2_50|KEY|SW|LED|DRAM_|LPDDR4A_|HDMI_|FPGA_UART_|HPS_|FAN_ALERT_n)}

foreach line [split $pin_text "\n"] {
    set words [string trim $line]
    if {[llength $words] == 0} {
        continue
    }

    set assignment_command [lindex $words 0]
    if {$assignment_command ni {set_instance_assignment set_location_assignment}} {
        continue
    }

    set to_index [lsearch -exact $words -to]
    if {$to_index < 0 || $to_index + 1 >= [llength $words]} {
        continue
    }
    set target [lindex $words [expr {$to_index + 1}]]
    if {![regexp $target_pattern $target]} {
        continue
    }

    if {$assignment_command eq "set_location_assignment"} {
        set_location_assignment [lindex $words 1] -to $target
    } else {
        set name_index [lsearch -exact $words -name]
        set assignment_name [lindex $words [expr {$name_index + 1}]]
        set assignment_value [lindex $words [expr {$name_index + 2}]]
        set_instance_assignment -name $assignment_name $assignment_value -to $target
    }
}

# The ADV7513 parallel input is source-synchronous with HDMI_TX_CLK. Pack the
# final registered pixel, data-enable, and sync stages into the Agilex I/O
# output registers so every core gets deterministic clock-to-output timing.
# The forwarded pixel clock itself remains on its dedicated clock route.
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to HDMI_TX_D[*]
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to HDMI_TX_DE
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to HDMI_TX_HS
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to HDMI_TX_VS
