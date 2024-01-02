#set_multicycle_path -from {*alu_d1[*]*} -to {*eightthirtytwo_alu:alu|mulresult[*]} -setup -end 2
#set_multicycle_path -from {*alu_d2[*]*} -to {*eightthirtytwo_alu:alu|mulresult[*]} -setup -end 2
#set_multicycle_path -from {*alu_d1[*]*} -to {*eightthirtytwo_alu:alu|mulresult[*]} -hold -end 2
#set_multicycle_path -from {*alu_d2[*]*} -to {*eightthirtytwo_alu:alu|mulresult[*]} -hold -end 2
#set_multicycle_path -from {*flag_sgn*} -to {*eightthirtytwo_alu:alu|mulresult[*]} -setup -end 2
#set_multicycle_path -from {*flag_sgn*} -to {*eightthirtytwo_alu:alu|mulresult[*]} -hold -end 2
#set_multicycle_path -from {*alu_sgn*} -to {*eightthirtytwo_alu:alu|mulresult[*]} -setup -end 2
#set_multicycle_path -from {*alu_sgn*} -to {*eightthirtytwo_alu:alu|mulresult[*]} -hold -end 2


if {[info exists mulresult]==0} then {set mulresult "mulresult"}

set_multicycle_path -from {*alu_d1[*]*} -to [get_keepers *eightthirtytwo_alu:alu|${mulresult}[*]] -setup -end 2
set_multicycle_path -from {*alu_d2[*]*} -to [get_keepers *eightthirtytwo_alu:alu|${mulresult}[*]] -setup -end 2
set_multicycle_path -from {*alu_d1[*]*} -to [get_keepers *eightthirtytwo_alu:alu|${mulresult}[*]] -hold -end 2
set_multicycle_path -from {*alu_d2[*]*} -to [get_keepers *eightthirtytwo_alu:alu|${mulresult}[*]] -hold -end 2
set_multicycle_path -from {*flag_sgn*} -to [get_keepers *eightthirtytwo_alu:alu|${mulresult}[*]] -setup -end 2
set_multicycle_path -from {*flag_sgn*} -to [get_keepers *eightthirtytwo_alu:alu|${mulresult}[*]] -hold -end 2
set_multicycle_path -from {*alu_sgn*} -to [get_keepers *eightthirtytwo_alu:alu|${mulresult}[*]] -setup -end 2
set_multicycle_path -from {*alu_sgn*} -to [get_keepers *eightthirtytwo_alu:alu|${mulresult}[*]] -hold -end 2
