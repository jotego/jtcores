# IKA32010 advances on its CLKIN enable, which jtframe_tms32010 requires never
# to be active on two consecutive clocks
set_multicycle_path -from {*|IKA32010:*|*} -to {*|IKA32010:*|*} -setup -end 2
set_multicycle_path -from {*|IKA32010:*|*} -to {*|IKA32010:*|*} -hold  -end 1
