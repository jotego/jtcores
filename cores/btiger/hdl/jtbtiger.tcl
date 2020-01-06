set_global_assignment -name VERILOG_MACRO "CORENAME=\"JTBTIGER\""
set_global_assignment -name VERILOG_MACRO "GAMETOP=jtbtiger_game"
set_global_assignment -name VERILOG_MACRO "JT12=1"
set_global_assignment -name VERILOG_MACRO "AVATARS=1"
set_global_assignment -name VERILOG_MACRO "VIDEO_WIDTH=384"

# OSD options
set_global_assignment -name VERILOG_MACRO "HAS_TESTMODE=1"
set_global_assignment -name VERILOG_MACRO "JOIN_JOYSTICKS=1"
set_global_assignment -name VERILOG_MACRO "VIDEO_WIDTH=384"

set_global_assignment -name VERILOG_FILE ../../modules/jt12/jt49/hdl/filter/jt49_dcrm2.v
set_global_assignment -name VERILOG_FILE ../../modules/jt12/hdl/mixer/jt12_mixer.v
 
