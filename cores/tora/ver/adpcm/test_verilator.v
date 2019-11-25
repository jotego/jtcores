module test(
    input           rst,
    input           clk,
    // CPU 2
    input   [ 7:0]  snd2_latch,
    output  [15:0]  snd2_addr,
    input   [ 7:0]  snd2_data,
    // ADPCM
    output  [ 3:0]  adpcm_din,
    output          adpcm_irq,
    output signed [15:0] snd
);

reg         rst;
wire        snd_cs, snd2_cs, sample;
wire        cen3, cenp384;

jtgng_cen #(.CLK_SPEED(48)) u_cen(
    .clk    ( clk       ),
    .cen12  (           ),
    .cen12b (           ),
    .cen8   (           ),
    .cen6   (           ),
    .cen6b  (           ),
    .cen3   ( cen3      ),
    .cen1p5 (           )
);

jtgng_cenp384 u_cenp384(
    .clk      ( clk       ),
    .cen_p384 ( cenp384   )
);

jttora_adpcm uut (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cen3           ),
    .cenp384        ( cenp384        ),
    .jap            ( 1'b1           ),
    // Interface with main CPU
    .snd2_latch     ( snd2_latch     ),
    // ADPCM ROM
    .rom2_addr      ( snd2_addr      ),
    .rom2_data      ( snd2_data      ),
    .rom2_cs        ( snd2_cs        ),
    .rom2_ok        ( 1'b1           ),
    .adpcm_din      ( adpcm_din      ),
    .adpcm_irq      ( adpcm_irq      ),
    // sound output
    .snd            ( snd            )
);

endmodule