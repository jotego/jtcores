// Pocket Cyclone V PLL: converts the 27 MHz Pocket reference to 56 MHz.
module jtframe_pll7000(
    input  inclk0,
    output c0,
    output locked
);

jtframe_pll7000_0002 jtframe_pll7000_inst(
    .refclk   ( inclk0 ),
    .rst      ( 1'b0   ),
    .outclk_0 ( c0     ),
    .locked   ( locked )
);

endmodule
