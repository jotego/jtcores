# remove JTGNG_VGA scan doubler
# set_global_assignment -name VERILOG_MACRO -remove "SCAN2X_TYPE=1"
# set_global_assignment -name VERILOG_MACRO -remove "JTFRAME_VGA=1"

# set MiSTer scan doubler
set_global_assignment -name VERILOG_MACRO "SCAN2X_TYPE=2"
set_global_assignment -name VERILOG_MACRO "MISTER_VIDEO_MIXER=1"
