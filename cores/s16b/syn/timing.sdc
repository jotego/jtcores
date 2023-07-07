# Games using the MCU don't use the FD1094/89
set_false_path -from [get_keepers *mcu*] -to [get_keepers *fd1094*]
set_false_path -from [get_keepers *mcu*] -to [get_keepers *fd1089*]

# Most -but not all- of JT7751 runs under a clock enable signal at 640kHz
# The CPU interface is not cen'ed but it has small combinational logic
# so the risk of including it here is low
set_multicycle_path -from {*|jt7759:u_pcm|*} -to {*|jt7759:u_pcm|*} -setup -end 2
set_multicycle_path -from {*|jt7759:u_pcm|*} -to {*|jt7759:u_pcm|*} -hold -end 2