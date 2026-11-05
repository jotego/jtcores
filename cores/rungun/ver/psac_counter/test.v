`timescale 1ns/1ps

module test;

reg         rst=1, clk=0, cen=1, hs=0, vs=0, ln_en=0, hmul=0;
reg  [15:0] hstep=1, vstep=0, cnt0=0;
wire [23:0] cnt;

`include "test_tasks.vh"

always #5 clk=~clk;

task expect_cnt(input [23:0] expected, input [8*48-1:0] message);
begin
    if(cnt!==expected) begin
        $display("FAIL: %0s: got %h, expected %h",message,cnt,expected);
        $finish;
    end
end
endtask

initial begin
    repeat(2) @(posedge clk);
    rst = 0;

    // VS starts a fresh frame and samples the horizontal increment.
    vs = 1;
    @(posedge clk);
    #1 expect_cnt(24'd0,"frame start");
    vs = 0;

    @(posedge clk);
    #1 expect_cnt(24'd1,"first horizontal increment");

    // This write can arrive while the current line is being rendered. It
    // must not make a one-pixel discontinuity in this line.
    hstep = 16'd3;
    @(posedge clk);
    #1 expect_cnt(24'd2,"mid-line update held back");

    // The HS event makes the new step effective for the following line.
    @(negedge clk);
    hs = 1;
    @(posedge clk);
    #1 expect_cnt(24'd3,"last old-line horizontal increment");
    @(negedge clk);
    hs = 0;
    @(posedge clk);
    #1 expect_cnt(24'd0,"line reload");
    @(posedge clk);
    #1 expect_cnt(24'd3,"next-line horizontal increment");

    // Signed increments use the same latch. This covers the reverse
    // scrolling direction used by perspective transformations.
    @(negedge clk);
    hstep = -16'sd2;
    vs    = 1;
    @(posedge clk);
    @(negedge clk);
    vs = 0;
    @(posedge clk);
    #1 expect_cnt(24'hfffffe,"signed horizontal increment");

    // Super-mode shifts the increment by eight bits before it is latched.
    @(negedge clk);
    hstep = 16'd2;
    hmul  = 1;
    vs    = 1;
    @(posedge clk);
    @(negedge clk);
    vs = 0;
    @(posedge clk);
    #1 expect_cnt(24'h000200,"high-resolution horizontal increment");

    pass();
end

jt053936_counter uut(
    .rst   ( rst   ),
    .clk   ( clk   ),
    .cen   ( cen   ),
    .hs    ( hs    ),
    .vs    ( vs    ),
    .ln_en ( ln_en ),
    .hstep ( hstep ),
    .vstep ( vstep ),
    .cnt0  ( cnt0  ),
    .hmul  ( hmul  ),
    .vmul  ( 1'b0  ),
    .cnt   ( cnt   )
);

endmodule
