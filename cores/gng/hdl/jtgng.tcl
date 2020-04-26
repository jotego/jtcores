set_global_assignment -name VERILOG_MACRO "CORENAME=\"JTGNG\""
set_global_assignment -name VERILOG_MACRO "JTFRAME_MRA_DIP=1"
set_global_assignment -name VERILOG_MACRO "GAMETOP=jtgng_game"
set_global_assignment -name VERILOG_MACRO "JT12=1"
set_global_assignment -name VERILOG_MACRO "BUTTONS=2"
set_global_assignment -name VERILOG_MACRO "JTFRAME_ARX=5"
set_global_assignment -name VERILOG_MACRO "JTFRAME_ARY=4"

set_global_assignment -name VERILOG_MACRO "VIDEO_WIDTH=384"

set_global_assignment -name VERILOG_FILE ../../../modules/jt12/hdl/mixer/jt12_comb.v
set_global_assignment -name VERILOG_FILE ../../../modules/jt12/hdl/mixer/jt12_interpol.v
set_global_assignment -name VERILOG_FILE ../../../modules/jt12/jt49/hdl/filter/jt49_dcrm2.v
set_global_assignment -name VERILOG_FILE ../../../modules/jt12/hdl/mixer/jt12_mixer.v
