`timescale 1ns/1ps

// Two jtframe_pxlcen instances start counting at different times, as if the
// FPGA configuration and the PLL lock had a different timing. Once ph24 runs,
// both must produce pixel enables on the same clk24 phase. Which clk24 cycle
// starts a pixel does not matter.
module test;

`include "test_tasks.vh"

localparam CLK_MHZ = `ifdef JTFRAME_SDRAM96 96 `else 48 `endif,
           P       = CLK_MHZ/24;

reg  clk=0, en_b=0, ph24=0;
reg  [2:0] div=0;
wire clk_b = clk & en_b;
wire pxl_a, pxl2_a, pxl_b, pxl2_b;
integer k, pa=-1, pb=-1;

always #5 clk=~clk;

// clk24 rising edge every P clk cycles
always @(posedge clk) begin
    div <= div==P-1 ? 3'd0 : div+3'd1;
    if( div==P-1 ) ph24 <= ~ph24;
end

initial begin
    repeat(5) @(negedge clk); en_b = 1;   // instance b starts 5 cycles later
    repeat(200) @(posedge clk);
    for( k=0; k<400; k=k+1 ) begin
        @(negedge clk);
        // only the clk24 phase of each pxl_cen pulse must match. pxl_cen drives the
        // video timer. pxl2_cen may alternate phases when its period is not a
        // multiple of the clk24 period
        if( pxl_a ) begin if( pa>=0 ) assert_msg( pa==div, "pxl_cen a changes its clk24 phase" ); pa = div; end
        if( pxl_b ) begin if( pb>=0 ) assert_msg( pb==div, "pxl_cen b changes its clk24 phase" ); pb = div; end
        if( pa>=0 && pb>=0 ) assert_msg( pa==pb, "pxl_cen is not locked to clk24" );
    end
    assert_msg( pa>=0 && pb>=0, "missing pixel enables" );
    pass();
end

jtframe_pxlcen uut_a(
    .clk        ( clk       ),
    .ph24       ( ph24      ),
    .pxl_cen    ( pxl_a     ),
    .pxl2_cen   ( pxl2_a    )
);

jtframe_pxlcen uut_b(
    .clk        ( clk_b     ),
    .ph24       ( ph24      ),
    .pxl_cen    ( pxl_b     ),
    .pxl2_cen   ( pxl2_b    )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

endmodule
