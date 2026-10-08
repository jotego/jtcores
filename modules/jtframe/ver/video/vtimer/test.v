`timescale 1ns/1ps
`define SIMULATION_VTIMER

module test;

reg clk, pxl_cen;

initial begin
    clk = 0;
    pxl_cen = 0;
    forever #(83.333/2) clk = ~clk;
end

initial #(16600*1000*4) $finish;

always @(posedge clk) pxl_cen <= ~pxl_cen;

jtframe_vtimer #(
    .HCNT_START ( 9'h020    ),
    .HCNT_END   ( 9'h19F    ),
    .HB_START   ( 9'h19F    ),
    .HB_END     ( 9'h05F    ),  // 10.6 us
    .HS_START   ( 9'h039    ),
    .HS_END     ( 9'h059    ),  //  5.33 us

    .V_START    ( 9'h0F8    ),
    .VB_START   ( 9'h1F0    ),
    .VB_END     ( 9'h110    ),  //  2.56 ms
    .VS_START   ( 9'h1FF    ),
    .VS_END     ( 9'h0FF    ),
    .VCNT_END   ( 9'h1FF    )   // 16.896 ms (59.18Hz)
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      (           ),
    .vrender    (           ),
    .vrender1   (           ),
    .H          (           ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       (           ),
    .LVBL       (           ),
    .HS         (           ),
    .VS         (           )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end

endmodule