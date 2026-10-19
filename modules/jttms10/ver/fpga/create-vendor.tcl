# Reproduce the pinned TEI0022-03 / A5_C8_2GB reference hardware.
package require ::quartus::project
project_new -revision test_board test_board
set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE 5CSEMA5F31C8
source test_board.tcl
set_global_assignment -name NUM_PARALLEL_PROCESSORS 4
project_close
