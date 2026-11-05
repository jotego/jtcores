create_clock -name hps_user0 -period 10.000 [get_pins {u_clocks|h2f_user0_clk}]
derive_clock_uncertainty
# Bundled-data request is held from before its toggle until the reply.
set_false_path -to [get_registers {*|request_meta[*]}]
# GPI is sampled asynchronously by software after the delayed acknowledgement.
set_false_path -from [get_registers {*|gp_in[*]}] -to [get_pins {u_gp|gp_in[*]}]
set_false_path -to [get_registers {reset_pipe[0]}]
# External PCM signals are asynchronous to the HPS clock. Only the first
# synchronizer stage is exempt; the second stage and decoder remain timed.
set_false_path -from [get_ports {pcm_pins[*]}] -to [get_registers {*|pins_meta[*]}]
