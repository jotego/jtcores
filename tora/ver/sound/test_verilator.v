module test(
    input           rst,
    input           clk,
    input   [ 7:0]  snd_latch,
    output  [14:0]  snd_addr,
    input   [ 7:0]  snd_data,
    output signed [15:0] snd,
    output          sample
);

wire        cen_fm;
reg         rst;
wire        snd_cs, sample;
wire  [7:0] snd2_latch;

jtgng_sound #(.LAYOUT(3)) u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( 1'b1           ),
    .cen1p5         ( 1'b1           ),  // unused
    // Interface with main CPU
    .sres_b         ( 1'b1           ),  // unused
    .snd_latch      ( snd_latch      ),
    .snd_int        ( 1'b1           ),  // unused
    .snd2_latch     ( snd2_latch     ),
    // sound control
    .enable_psg     ( 1'b1           ),
    .enable_fm      ( 1'b1           ),
    .psg_gain       ( 8'h10          ),
    // ROM
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_cs         ( snd_cs         ),
    .rom_ok         ( 1'b1           ),
    // sound output
    .ym_snd         ( snd            ),
    .sample         ( sample         )
);

endmodule