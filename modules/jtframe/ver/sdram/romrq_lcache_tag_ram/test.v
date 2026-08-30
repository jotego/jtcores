`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

reg rst, clk, clr;
reg [15:0] addr;
reg cs, we, dst, rdy;
reg [15:0] din;
wire req, ok;
wire [15:0] dout;
wire [21:0] sdram_addr;

always #5 clk = ~clk;

jtframe_romrq_lcache #(
    .SDRAMW    ( 22   ),
    .AW        ( 16   ),
    .DW        ( 16   ),
    .CACHE_SIZE( 2048 ),
    .BURSTLEN  ( 32   ),
    .TAG_RAM   ( 1    )
) uut (
    .rst        ( rst        ),
    .clk        ( clk        ),
    .clr        ( clr        ),
    .offset     ( 22'd0      ),
    .din        ( din        ),
    .din_ok     ( rdy        ),
    .dst        ( dst        ),
    .we         ( we         ),
    .req        ( req        ),
    .sdram_addr ( sdram_addr ),
    .addr       ( addr       ),
    .addr_ok    ( cs         ),
    .data_ok    ( ok         ),
    .dout       ( dout       )
);

task finish_fill(input [15:0] first, input [15:0] second);
    begin
        // TAG_RAM adds a registered tag lookup, so let the request be
        // captured before modelling the controller selecting its slot.
        @(posedge clk);
        @(negedge clk); we=1; dst=1; din=first;
        @(negedge clk); dst=0; din=second; rdy=1;
        @(negedge clk); we=0; rdy=0;
    end
endtask

task request_line(input [15:0] new_addr, input [21:0] expected_sdram_addr);
    begin
        @(negedge clk); addr=new_addr; cs=1;
        #1 assert_msg(!req, "tag RAM request must wait for the clocked lookup");
        @(posedge clk); #1;
        assert_msg(req, "tag RAM miss request missing after lookup");
        assert_msg(sdram_addr==expected_sdram_addr, "tag RAM request address is wrong");
    end
endtask

initial begin
    clk=0; rst=1; clr=0;
    addr=0; cs=0; we=0; dst=0; rdy=0; din=0;
    repeat(3) @(posedge clk);
    rst=0;

    request_line(16'h0040, 22'h040);
    finish_fill(16'h3412, 16'h7856);
    // The tag written by the fill is read back through the synchronous tag
    // RAM before it can validate the synchronous data RAM output.
    @(posedge clk); #1;
    @(posedge clk); #1;
    assert_msg(ok && dout==16'h3412, "filled tag RAM line did not return first word");

    // Remove the previous response first, so the next assertion observes
    // only the new address rather than the registered result it replaces.
    @(negedge clk); cs=0;
    @(posedge clk);
    @(negedge clk); addr=16'h0041; cs=1;
    #1 assert_msg(!ok, "tag RAM hit must not be combinational");
    @(posedge clk); #1;
    assert_msg(!ok, "tag RAM hit must take an extra clock");
    @(posedge clk); #1;
    assert_msg(ok && !req && dout==16'h7856, "tag/data RAM hit is not aligned");

    // A client glitching its address while the controller delays accepting a
    // miss may see an invalid dout, but it must not redirect the cache fill.
    // The pending request owns the line and tag until the fill completes.
    @(negedge clk); cs=0;
    @(posedge clk);
    request_line(16'h0440, 22'h440);
    @(negedge clk); addr=16'h0002;
    @(negedge clk); addr=16'h0204;
    @(negedge clk); addr=16'h0a06;
    finish_fill(16'habcd, 16'hef01);
    cs=0; addr=16'h0440;
    @(posedge clk);
    @(negedge clk); cs=1;
    @(posedge clk); #1;
    @(posedge clk); #1;
    assert_msg(ok && !req && dout==16'habcd,
               "address glitch corrupted the filled cache line");

    @(negedge clk); clr=1;
    @(negedge clk); clr=0;
    @(posedge clk); #1;
    assert_msg(req, "cache clear did not invalidate synchronous tag RAM line");
    @(negedge clk); cs=0;

    pass();
end

endmodule
