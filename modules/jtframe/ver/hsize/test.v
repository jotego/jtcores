`timescale 1ns/1ps

module test;

reg clk;
wire [8:0] vdump, vrender, vrender1, H;
wire Hinit, Vinit, LHBL, LVBL, HS, VS,
     pxl2_cen, pxl_cen;

reg [1:0] cen_cnt=0;
reg [3:0] scale=8;
reg       HSl, VSl;

assign pxl2_cen = cen_cnt[0];
assign pxl_cen  = cen_cnt==3;

reg [3:0] linecnt=0;

initial begin
    clk = 0;
    forever #5 clk=~clk;
end

always @(posedge clk) begin
    cen_cnt <= cen_cnt + 1'd1;
    HSl <= HS;
    VSl <= VS;
    if( HS & ~HSl) {scale, linecnt } <= {scale, linecnt } + 1'd1;
    if( VS & ~VSl ) $finish;
end

jtframe_hsize uut(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    .scale      ( scale     ),
    .offset     ( 5'd0      ),
    .enable     ( 1'b1      ),

    .r_in       ( 4'd0      ),
    .g_in       ( 4'd0      ),
    .b_in       ( 4'd0      ),
    .HS_in      ( HS        ),
    .VS_in      ( VS        ),
    .HB_in      ( ~LHBL     ),
    .VB_in      ( ~LVBL     ),
    // filtered video
    .HS_out     (           ),
    .VS_out     (           ),
    .HB_out     (           ),
    .VB_out     (           ),
    .r_out      (           ),
    .g_out      (           ),
    .b_out      (           )
);

jtframe_vtimer u_timer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      (           ),
    .vrender    (           ),
    .vrender1   (           ),
    .H          (           ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    #10000000 $finish;
end

endmodule