`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

reg rst, clk, clr;
reg [15:0] addr, addr64;
reg cs, we, dst, rdy;
reg cs64, we64, dst64, rdy64;
reg [15:0] din, din64;
wire req, ok, req64, ok64;
wire [15:0] dout;
wire [63:0] dout64;
wire [21:0] sdram_addr, sdram_addr64;

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

jtframe_romrq_lcache #(
    .SDRAMW    ( 22   ),
    .AW        ( 16   ),
    .DW        ( 64   ),
    .CACHE_SIZE( 1024 ),
    .BURSTLEN  ( 64   ),
    .TAG_RAM   ( 1    )
) uut_quad (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clr        ( 1'b0          ),
    .offset     ( 22'd0         ),
    .din        ( din64         ),
    .din_ok     ( rdy64         ),
    .dst        ( dst64         ),
    .we         ( we64          ),
    .req        ( req64         ),
    .sdram_addr ( sdram_addr64  ),
    .addr       ( addr64        ),
    .addr_ok    ( cs64          ),
    .data_ok    ( ok64          ),
    .dout       ( dout64        )
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

task finish_quad_fill;
    begin
        @(posedge clk);
        @(negedge clk); we64=1; dst64=1; din64=16'h1122;
        @(negedge clk); dst64=0; din64=16'h3344;
        @(negedge clk); din64=16'h5566;
        @(negedge clk); din64=16'h7788; rdy64=1;
        @(negedge clk); we64=0; rdy64=0;
    end
endtask

task request_quad_line(input [15:0] new_addr, input [21:0] expected_sdram_addr);
    begin
        @(negedge clk); addr64=new_addr; cs64=1;
        #1 assert_msg(!req64, "quad tag RAM request must wait for the clocked lookup");
        @(posedge clk); #1;
        assert_msg(req64, "quad tag RAM miss request missing after lookup");
        assert_msg(sdram_addr64==expected_sdram_addr, "quad tag RAM request address is wrong");
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
    addr64=0; cs64=0; we64=0; dst64=0; rdy64=0; din64=0;
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

    request_quad_line(16'h0080, 22'h080);
    finish_quad_fill();
    @(posedge clk); #1;
    @(posedge clk); #1;
    assert_msg(ok64 && !req64 && dout64==64'h7788_5566_3344_1122,
               "filled quad tag RAM line did not return both lanes");

    @(negedge clk); cs64=0;
    @(posedge clk);
    @(negedge clk); addr64=16'h0280; cs64=1;
    @(posedge clk); #1;
    assert_msg(req64, "quad tag RAM conflict did not miss");
    assert_msg(sdram_addr64==22'h280, "quad tag RAM conflict address is wrong");
    finish_quad_fill();
    @(posedge clk); #1;
    @(posedge clk); #1;
    assert_msg(ok64 && dout64==64'h7788_5566_3344_1122,
               "quad tag RAM conflict line data is wrong");

    @(negedge clk); cs64=0;
    @(posedge clk);
    request_quad_line(16'h0080, 22'h080);
    @(negedge clk); cs64=0;

    pass();
end

endmodule
