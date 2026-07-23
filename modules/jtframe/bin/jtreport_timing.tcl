# jtreport_timing.tcl - detailed worst-path timing report for triage.
#
# Run from the build directory (where the compiled revision DB lives):
#   quartus_sta -t $JTFRAME/bin/jtreport_timing.tcl <revision>
#
# Emits the worst setup/hold/recovery/removal paths with full path detail so a
# timing failure can be diagnosed from the CI log artifact alone, without
# re-running the fitter or opening the design in the GUI.

set rev [lindex $quartus(args) 0]
if { $rev eq "" } {
    puts "jtreport_timing.tcl: missing revision name argument"
    exit 1
}

project_open $rev -revision $rev

# Slow corner (worst voltage/temperature) is where setup normally fails.
create_timing_netlist -model slow
read_sdc
update_timing_netlist

puts "############################################################"
puts "# Worst-case SETUP paths (slow model, full path detail)     "
puts "############################################################"
report_timing -setup -npaths 30 -detail full_path -stdout

puts "############################################################"
puts "# Worst-case HOLD paths (slow model)                        "
puts "############################################################"
report_timing -hold -npaths 10 -detail full_path -stdout

puts "############################################################"
puts "# Worst-case RECOVERY paths (slow model)                    "
puts "############################################################"
report_timing -recovery -npaths 5 -detail full_path -stdout

puts "############################################################"
puts "# Clocks                                                    "
puts "############################################################"
report_clocks -stdout

delete_timing_netlist
project_close
