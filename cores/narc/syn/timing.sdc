# GSP (clk48) <-> bus responder (clk 96 MHz): requests are sampled and
# acknowledges are launched only on clk edges aligned with clk48
set narc_gsp  [get_registers -nowarn {*|jtnarc_main:u_main|jtnarc_gsp:u_gsp|*}]
set narc_bus  [remove_from_collection [get_registers -nowarn {*|jtnarc_main:u_main|*}] $narc_gsp]
if { [get_collection_size $narc_gsp] > 0 } {
    set_multicycle_path -from $narc_gsp -to $narc_bus -setup -end 2
    set_multicycle_path -from $narc_gsp -to $narc_bus -hold  -end 1
    set_multicycle_path -from $narc_bus -to $narc_gsp -setup -start 2
    set_multicycle_path -from $narc_bus -to $narc_gsp -hold  -start 1
}
