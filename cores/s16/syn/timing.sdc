# Most -but not all- of JT51 runs under a clock enable signal at 4MHz
# The CPU interface is not cen'ed but it has small combinational logic
# so the risk of including it here is low
set_multicycle_path -from {*|jt51:u_jt51|*} -to {*|jt51:u_jt51|*} -setup -end 2
set_multicycle_path -from {*|jt51:u_jt51|*} -to {*|jt51:u_jt51|*} -hold -end 2
