# remove JTGNG_VGA scan doubler
# set_global_assignment -name VERILOG_MACRO -remove "SCAN2X_TYPE=1"
# set_global_assignment -name VERILOG_MACRO -remove "JTFRAME_VGA=1"

# set MiSTer scan doubler
set_global_assignment -name VERILOG_MACRO "SCAN2X_TYPE=4"
set_global_assignment -name VERILOG_MACRO "MISTER_VIDEO_MIXER=1"
set_global_assignment -name VERILOG_MACRO "VIDEO_WIDTH=256"
set_global_assignment -name VERILOG_MACRO "VIDEO_HEIGHT=224"

# best 8: -3.076
set_global_assignment -name SEED 9
