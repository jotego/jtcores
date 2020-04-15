set_global_assignment -name VERILOG_MACRO "CORETOP=jttora_cyclone5"

set_global_assignment -name VERILOG_MACRO "CORENAME=\"JTTORA\""
set_global_assignment -name VERILOG_MACRO "GAMETOP=jttora_game"
set_global_assignment -name VERILOG_MACRO "JT12=1"
set_global_assignment -name VERILOG_MACRO "VIDEO_WIDTH=384"

set_global_assignment -name VERILOG_MACRO "HAS_TESTMODE=1"
set_global_assignment -name VERILOG_MACRO "JOIN_JOYSTICKS=1"

set_global_assignment -name VERILOG_FILE ../../../modules/jt12/jt49/hdl/filter/jt49_dcrm2.v
set_global_assignment -name VERILOG_FILE ../../../modules/jt12/hdl/mixer/jt12_mixer.v
 
