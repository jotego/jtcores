// Pocket Cyclone V game PLL for the 56 MHz core clock chain.
module jtframe_pllgame7000(
    input  inclk0,
    output c0,
    output c1,
    output c2,
    output c3,
    output locked
);

jtframe_pllgame7000_0002 jtframe_pllgame7000_inst(
    .refclk   ( inclk0 ),
    .rst      ( 1'b0   ),
    .outclk_0 ( c0     ),
    .outclk_1 ( c1     ),
    .outclk_2 ( c2     ),
    .outclk_3 ( c3     ),
    .locked   ( locked )
);

endmodule
