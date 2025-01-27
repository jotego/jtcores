module test;

`include "test_tasks.vh"

wire       rst, clk, pxl_cen, lhbl, lvbl;
wire [8:0] v,h;
reg        flip;

initial begin
    flip=0;
    @(negedge rst);
    repeat(2) @(posedge clk);
    @(negedge lhbl);
    assert_msg(h==279,"wrong h length");
    @(posedge lhbl);
    assert_msg(h==0,  "h must start at zero");
    @(negedge lvbl)
    assert_msg(v==239,"wrong v length");
    @(posedge lvbl)
    assert_msg(v==0,"v must start at zero");
    @(negedge lvbl)
    assert_msg(v==239,"wrong v length");
    $display("PASS");
    $finish;
end

jtframe_video_counter uut(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .pxl_cen    ( pxl_cen     ),

    .lhbl       ( lhbl        ),
    .lvbl       ( lvbl        ),
    .flip       ( flip        ),

    .v          ( v           ),
    .h          ( h           )
);

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .lhbl       ( lhbl          ),
    .lvbl       ( lvbl          ),
    .framecnt   (               )
);

endmodule : test