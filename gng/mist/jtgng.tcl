set_global_assignment -name VERILOG_MACRO "CORENAME=\"JTGNG\""
set_global_assignment -name VERILOG_MACRO "HAS_TESTMODE=1"
set_global_assignment -name VERILOG_MACRO "GAMETOP=jtgng_game"
set_global_assignment -name VERILOG_MACRO "MISTTOP=jtgng_mist"
set_global_assignment -name VERILOG_MACRO "JT12=1"

# JTGNG_VGA scan doubler
set_global_assignment -name VERILOG_MACRO "SCAN2X_TYPE=1"
set_global_assignment -name VERILOG_MACRO "JTFRAME_VGA=1"
#set_global_assignment -name VERILOG_MACRO "MISTER_VIDEO_MIXER=1"

set_global_assignment -name VERILOG_FILE ../../../jt12/hdl/mixer/jt12_comb.v
set_global_assignment -name VERILOG_FILE ../../../jt12/hdl/mixer/jt12_interpol.v
set_global_assignment -name VERILOG_FILE ../../../jt12/jt49/hdl/filter/jt49_dcrm2.v
set_global_assignment -name VERILOG_FILE ../../modules/jt12/hdl/mixer/jt12_mixer.v
