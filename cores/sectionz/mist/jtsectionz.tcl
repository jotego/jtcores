set_global_assignment -name VERILOG_MACRO "MISTTOP=jtsectionz_mist"
set_global_assignment -name VERILOG_MACRO "SCAN2X_TYPE=2"
set_global_assignment -name VERILOG_MACRO "MISTER_VIDEO_MIXER=1"
# Better to leave direct speed to zero as this game needs some extra
# cycles in between ioctl_wr pulses
set_global_assignment -name VERILOG_MACRO "JTFRAME_MIST_DIRECT=0"
