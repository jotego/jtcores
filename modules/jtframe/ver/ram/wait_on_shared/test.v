module test;

`include "test_tasks.vh"

wire rst, clk, mwait, swait;
reg  mreq=0, sreq=0;

initial begin
    @(negedge rst);
    assert_msg(mwait==0 && swait==0,"no wait at reset");
    repeat (20) @(negedge clk);

    mreq = 1;
    sreq = 0;
    @(negedge clk);
    assert_msg(mwait==0 && swait==0,"no wait if only one request");

    mreq = 0;
    sreq = 1;
    @(negedge clk);
    assert_msg(mwait==0 && swait==0,"no wait if only one request");

    // make sub wait
    mreq = 1;
    sreq = 0;
    @(negedge clk);
    @(negedge clk);
    assert_msg(mwait==0 && swait==0,"no wait if only one request");
    sreq = 1;
    @(negedge clk);
    assert_msg(swait==1,"sub should be waiting");
    assert_msg(mwait==0,"main should not be waiting");
    mreq = 0;
    @(negedge clk);
    @(negedge clk);
    assert_msg(mwait==0 && swait==0,"no wait if only one request");

    // make main wait
    mreq = 0;
    sreq = 1;
    @(negedge clk);
    assert_msg(mwait==0 && swait==0,"no wait if only one request");
    mreq = 1;
    @(negedge clk);
    assert_msg(mwait==1,"main should be waiting");
    assert_msg(swait==0,"sub  should not be waiting");
    sreq = 0;
    repeat (3) @(negedge clk);
    assert_msg(mwait==0 && swait==0,"no wait if only one request");

    // on a simultaneous request, main should prevail
    mreq = 0;
    sreq = 0;
    repeat (10) @(negedge clk);
    mreq = 1;
    sreq = 1;
    repeat (2) @(negedge clk);
    assert_msg(mwait==0 && swait==1,"main should take priority");
    repeat (2) @(negedge clk);
    mreq = 0;
    repeat (2) @(negedge clk);
    assert_msg(mwait==0 && swait==0,"no wait if only one request - Z");

    pass();
end

jtframe_wait_on_shared uut(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .mreq   ( mreq  ),
    .sreq   ( sreq  ),
    .mwait  ( mwait ),
    .swait  ( swait )
);

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           )
);

endmodule