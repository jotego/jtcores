`timescale 1ns/1ps

module test;

localparam COLORW=4;
localparam DW=COLORW*3;


reg           clk, rst_n;
wire          pxl_cen, pxl2_cen;
reg  [DW-1:0] base_pxl;
wire          HS, VS;
integer       frame_cnt=0;

initial begin
    clk = 0;
    base_pxl = {3{4'b1010}};
    forever #(20.833/2) clk = ~clk; // 48 MHz
end

initial begin
    rst_n = 0;
    #100 rst_n = 1;
end

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( pxl2_cen  ),
    .cen6   ( pxl_cen   )
);

// Get a random pixel
always @(posedge clk) if(pxl_cen) begin
    //base_pxl <= { base_pxl[DW-2:0], base_pxl[4]^base_pxl[DW-1] };
    base_pxl <= base_pxl+12'h632;
end

always @(posedge VS) begin
    frame_cnt <= frame_cnt + 1;
    if( frame_cnt == 1 ) $finish;
end

jtframe_scan2x #(.HLEN(396)) UUT(
    .rst_n      ( rst_n     ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .base_pxl   ( base_pxl  ),
    .HS         ( HS        ),
    .x2_pxl     (           ),
    .x2_HS      (           )
);

jtframe_vtimer u_timer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .HS         ( HS        ),
    .VS         ( VS        )
);
/*
jtgng_timer #(.LAYOUT(5)) u_timer(
    .clk       ( clk      ),
    .cen6      ( pxl_cen  ),
    .HS        ( HS       ),
    .VS        ( VS       )
);
*/

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end

endmodule
