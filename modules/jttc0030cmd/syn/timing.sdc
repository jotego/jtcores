# This assumes the MCU is never run at full clock speed but always uses a
# clock enable without consequitive active cycles
set_multicycle_path -from {*|IKA87AD:u_mcu|*} -to {*|IKA87AD:u_mcu|*} -setup -end 2
set_multicycle_path -from {*|IKA87AD:u_mcu|*} -to {*|IKA87AD:u_mcu|*} -hold  -end 2
