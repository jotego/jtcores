set_global_assignment -name VERILOG_MACRO "CORENAME=\"JT1942\""
set_global_assignment -name VERILOG_MACRO "VERTICAL_SCREEN=1"
set_global_assignment -name VERILOG_MACRO "JTFRAME_OSD_FLIP=1"
set_global_assignment -name VERILOG_MACRO "JTFRAME_OSD_TEST=1"
set_global_assignment -name VERILOG_MACRO "GAMETOP=jt1942_game"
set_global_assignment -name VERILOG_MACRO "SIGNED_SND=0"
set_global_assignment -name VERILOG_MACRO "JTFRAME_ARX=5"
set_global_assignment -name VERILOG_MACRO "JTFRAME_ARY=4"
set_global_assignment -name VERILOG_MACRO "BUTTONS=2"

# This game is missing one top line in MiST when using SCAN2X_TYPE=1
# set_global_assignment -name VERILOG_MACRO "SCAN2X_TYPE=0"

set_global_assignment -name QIP_FILE ../../../modules/t80/T80.qip
set_global_assignment -name QIP_FILE ../../../modules/jt12/jt49/hdl/jt49.qip
