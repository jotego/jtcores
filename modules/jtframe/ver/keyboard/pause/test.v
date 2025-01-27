module test;

`include "test_tasks.vh"

wire        rst, clk;
wire        pause, lvbl;
reg         key, joy, osd, service;

initial begin
    key     = 0;
    joy     = 0;
    osd     = 0;
    service = 0;
    @(negedge rst)
    repeat (10) @(posedge clk);
    assert_msg(pause==0,"must be zero after reset");

    key = 1;
    repeat (4) @(posedge clk);
    assert_msg(pause==1,"must be high after a key press");

    joy = 1;
    osd = 1;
    repeat (4) @(posedge clk);
    assert_msg(pause==1,"must ignore new signals until all are released");

    key = 0; joy = 0; osd = 0;
    repeat (4) @(posedge clk);
    assert_msg(pause==1,"must keep high until the next event");

    osd = 1;
    repeat (4) @(posedge clk);
    assert_msg(pause==0,"must be low");
    osd = 0;
    repeat (4) @(posedge clk);
    assert_msg(pause==0,"must be low");

    joy = 1;
    repeat (4) @(posedge clk);
    joy = 0;
    assert_msg(pause==1,"must be high");

    @(posedge lvbl);
    service = 1;
    repeat (4) @(posedge clk);
    service = 0;
    @(negedge lvbl);
    repeat (4) @(posedge clk);
    assert_msg(pause==0,"service should release the pause");

    @(negedge lvbl);
    repeat (4) @(posedge clk);
    assert_msg(pause==1,"pause should have been restored");


    @(negedge lvbl);
    pass();
end

jtframe_pause uut(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .key_pause  ( key       ),
    .joy_pause  ( joy       ),
    .osd_pause  ( osd       ),
    .service    ( service   ),
    .lvbl       ( lvbl      ),
    .game_pause ( pause     )
);

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    (               ),
    .lhbl       ( lvbl          ), // for faster simulation
    .lvbl       (               ),
    .v          (               ),
    .framecnt   (               )
);

endmodule