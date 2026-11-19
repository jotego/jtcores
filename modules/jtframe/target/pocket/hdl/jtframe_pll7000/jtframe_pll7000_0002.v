// Intel PLL IP for the Pocket Cyclone V 27 MHz reference.
`timescale 1 ps / 1 ps
module jtframe_pll7000_0002(
    input  refclk,
    input  rst,
    output outclk_0,
    output locked
);

altera_pll #(
    .fractional_vco_multiplier("false"),
    .reference_clock_frequency("27.000 MHz"),
    .operation_mode("direct"),
    .number_of_clocks(1),
    .output_clock_frequency0("56.000000 MHz"),
    .phase_shift0("0 ps"),
    .duty_cycle0(50),
    .pll_type("General"),
    .pll_subtype("General")
) altera_pll_i (
    .rst       ( rst       ),
    .outclk    ( {outclk_0} ),
    .locked    ( locked    ),
    .fboutclk  (           ),
    .fbclk     ( 1'b0      ),
    .refclk    ( refclk    )
);

endmodule
