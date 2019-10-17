set_global_assignment -name VERILOG_MACRO "CORENAME=\"JTTORA\""
set_global_assignment -name VERILOG_MACRO "GAMETOP=jttora_game"
set_global_assignment -name VERILOG_MACRO "MISTTOP=jttora_mist"
set_global_assignment -name VERILOG_MACRO "JT12=1"
#set_global_assignment -name VERILOG_MACRO "AVATARS=1"
set_global_assignment -name VERILOG_MACRO "SCAN2X_TYPE=1"

# OSD options
set_global_assignment -name VERILOG_MACRO "HAS_TESTMODE=1"
set_global_assignment -name VERILOG_MACRO "JOIN_JOYSTICKS=1"

# Avatars on MiST too:
# set_global_assignment -name VERILOG_MACRO "AVATAR_ROM=1"
# set_global_assignment -name VERILOG_MACRO "AVATAR_PAL=1"
# set_global_assignment -name VERILOG_MACRO "AVATAR_OBJDRAW=1"
# set_global_assignment -name VERILOG_MACRO "AVATAR_DATA=1"

set_global_assignment -name VERILOG_FILE ../../modules/jt12/jt49/hdl/filter/jt49_dcrm2.v
set_global_assignment -name VERILOG_FILE ../../modules/jt12/hdl/mixer/jt12_mixer.v
 
