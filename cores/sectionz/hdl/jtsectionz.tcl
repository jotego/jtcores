set_global_assignment -name VERILOG_MACRO "CORENAME=\"JTSZR\""
set_global_assignment -name VERILOG_MACRO "GAMETOP=jtsectionz_game"
set_global_assignment -name VERILOG_MACRO "JTFRAME_MRA_DIP=1"
set_global_assignment -name VERILOG_MACRO "JT12=1"
#set_global_assignment -name VERILOG_MACRO "AVATARS=1"
set_global_assignment -name VERILOG_MACRO "BUTTONS=2"
set_global_assignment -name VERILOG_MACRO "VIDEO_WIDTH=256"
set_global_assignment -name VERILOG_MACRO "VIDEO_HEIGHT=224"

set_global_assignment -name VERILOG_MACRO "JTFRAME_ARX=5"
set_global_assignment -name VERILOG_MACRO "JTFRAME_ARY=4"

# OSD options
#set_global_assignment -name VERILOG_MACRO "JTFRAME_OSD_TEST=1"

# Verilog version of Z80 IP
# set_global_assignment -name VERILOG_MACRO "TV80S=1"

set_global_assignment -name VERILOG_FILE ../../../modules/jt12/jt49/hdl/filter/jt49_dcrm2.v
set_global_assignment -name VERILOG_FILE ../../../modules/jt12/hdl/mixer/jt12_mixer.v
 
