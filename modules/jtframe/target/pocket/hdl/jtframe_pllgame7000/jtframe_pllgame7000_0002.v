// Intel PLL IP for the Pocket Cyclone V 56 MHz game-clock input. c0 and c1
// stay in phase, matching the Pocket game's established PLL relationship.
`timescale 1 ps / 1 ps
module jtframe_pllgame7000_0002(
    input  refclk,
    input  rst,
    output outclk_0,
    output outclk_1,
    output outclk_2,
    output outclk_3,
    output locked
);

altera_pll #(
    .fractional_vco_multiplier("false"),
    .reference_clock_frequency("56.000 MHz"),
    .operation_mode("direct"),
    .number_of_clocks(4),
    .output_clock_frequency0("56.000000 MHz"),
    .phase_shift0("0 ps"),
    .duty_cycle0(50),
    .output_clock_frequency1("56.000000 MHz"),
    .phase_shift1("0 ps"),
    .duty_cycle1(50),
    .output_clock_frequency2("112.000000 MHz"),
    .phase_shift2("0 ps"),
    .duty_cycle2(50),
    .output_clock_frequency3("28.000000 MHz"),
    .phase_shift3("0 ps"),
    .duty_cycle3(50),
    .pll_type("General"),
    .pll_subtype("General")
) altera_pll_i (
    .rst       ( rst                                        ),
    .outclk    ( {outclk_3, outclk_2, outclk_1, outclk_0} ),
    .locked    ( locked                                    ),
    .fboutclk  (                                            ),
    .fbclk     ( 1'b0                                       ),
    .refclk    ( refclk                                     )
);

endmodule
