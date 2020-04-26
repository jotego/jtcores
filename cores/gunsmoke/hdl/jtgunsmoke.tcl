set_global_assignment -name VERILOG_MACRO "CORENAME=\"JTGUN\""
set_global_assignment -name VERILOG_MACRO "VERTICAL_SCREEN=1"
set_global_assignment -name VERILOG_MACRO "JTFRAME_MRA_DIP=1"
set_global_assignment -name VERILOG_MACRO "JTFRAME_OSD_FLIP=1"
set_global_assignment -name VERILOG_MACRO "GAMETOP=jtgunsmoke_game"
set_global_assignment -name VERILOG_MACRO "JT12=1"
set_global_assignment -name VERILOG_MACRO "AVATARS=1"
set_global_assignment -name VERILOG_MACRO "VIDEO_WIDTH=384"
set_global_assignment -name VERILOG_MACRO "BUTTONS=3"
set_global_assignment -name VERILOG_MACRO "JTFRAME_ARX=5"
set_global_assignment -name VERILOG_MACRO "JTFRAME_ARY=4"

set_global_assignment -name VERILOG_FILE ../../../modules/jt12/jt49/hdl/filter/jt49_dcrm2.v
set_global_assignment -name VERILOG_FILE ../../../modules/jt12/hdl/mixer/jt12_mixer.v
 
