set_global_assignment -name VERILOG_MACRO "CORETOP=jtgunsmoke_cyclone5"
set_global_assignment -name VERILOG_MACRO "JOY_GUNSMOKE=1"

set_global_assignment -name VERILOG_MACRO "CORENAME=\"JTGUN\""
set_global_assignment -name VERILOG_MACRO "VERTICAL_SCREEN=1"
set_global_assignment -name VERILOG_MACRO "HAS_TESTMODE=1"
set_global_assignment -name VERILOG_MACRO "GAMETOP=jtgunsmoke_game"
set_global_assignment -name VERILOG_MACRO "JT12=1"
set_global_assignment -name VERILOG_MACRO "VIDEO_WIDTH=384"

set_global_assignment -name VERILOG_FILE ../../../modules/jt12/jt49/hdl/filter/jt49_dcrm2.v
set_global_assignment -name VERILOG_FILE ../../../modules/jt12/hdl/mixer/jt12_mixer.v
 
