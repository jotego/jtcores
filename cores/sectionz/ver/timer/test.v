`timescale 1ns / 1ps

module test;

reg clk;

initial begin
    clk = 0;
    forever #83.334 clk = ~clk;
end

wire [8:0] V,H;
wire       Hinit, Vinit, LHBL, LHBL_obj, LVBL, LVBL_obj, HS, VS;
wire       hs_out, vs_out;

wire [3:0] hoffset, voffset;

assign hoffset = `HOFFSET;
assign voffset = `VOFFSET;

jtframe_resync u_resync(
    .clk      (  clk         ),
    .pxl_cen  (  1'b1        ),
    .hs_in    (  HS          ),
    .vs_in    (  VS          ),
    .LVBL     (  LVBL        ),
    .LHBL     (  LHBL        ),
    .hoffset  (  hoffset     ),
    .voffset  (  voffset     ),
    .hs_out   (  hs_out      ),
    .vs_out   (  vs_out      )    
);


jtgng_timer #(.LAYOUT(`LAYOUT)) UUT(
    .clk       ( clk      ),
    .cen6      ( 1'b1     ),   //  6 MHz
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( Hinit    ),
    .Vinit     ( Vinit    ),
    .LHBL      ( LHBL     ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL      ( LVBL     ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       )
);

old_timer old(
    .clk       ( clk      ),
    .cen6      ( 1'b1     )    //  6 MHz
);

reg VS_last, HS_last;

wire new_HS = HS && !HS_last;
wire new_VS = VS && !VS_last;

integer framecnt=0;

always @(posedge clk) begin
    VS_last <= VS;
    HS_last <= HS;
    if( new_VS ) begin
        framecnt <= framecnt+1;
        if( framecnt==2 ) $finish;
    end
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    $dumpon;
end

endmodule