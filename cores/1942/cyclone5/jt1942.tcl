set_global_assignment -name VERILOG_MACRO "CORETOP=jt1942_cyclone5"

set_global_assignment -name VERILOG_MACRO "CORENAME=\"JT1942\""
set_global_assignment -name VERILOG_MACRO "VERTICAL_SCREEN=1"
set_global_assignment -name VERILOG_MACRO "HAS_TESTMODE=1"
set_global_assignment -name VERILOG_MACRO "GAMETOP=jt1942_game"
set_global_assignment -name VERILOG_MACRO "SIGNED_SND=0"

set_global_assignment -name QIP_FILE ../../../modules/t80/T80.qip
set_global_assignment -name QIP_FILE ../../../modules/jt12/jt49/hdl/jt49.qip
