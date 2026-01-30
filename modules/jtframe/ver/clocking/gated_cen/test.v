`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

reg pre=0, busy_en;
wire rst, clk, cen, busy, lvbl;
wire [8:0] v;
wire four_ms = v[5];
wire bad;

assign busy=busy_en & pre;
assign bad = cen & busy;

always @(posedge bad) begin
    $display("cen & busy active at the same time");
    #1000;
    fail();
end

always @(posedge clk) begin
    if(pre) begin
        if(($random & 32'hff) < 32'hc0) pre <= 0;
    end else begin
        if(($random & 32'hff) < 32'h20) pre <= 1;
    end
end

initial begin
    busy_en = 0;
    @(posedge lvbl) assert_msg(uut.u_info.fave==19'h18431,"average not correct with busy=0");
    busy_en = 1;
    @(posedge four_ms);
    repeat (20) begin
        @(posedge four_ms) assert_msg(uut.u_info.fave==19'h18431,"average not correct");
    end
    pass();
end

// example at 18.432 MHz
jtframe_gated_cen #(.W(1),.NUM(48),.DEN(125),.MFREQ(48000)) uut(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .busy   ( busy      ),
    .cen    ( cen       ),
    .fave   (           ),
    .fworst (           )
);

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    (               ),
    .hs         (               ),
    .lvbl       ( lvbl          ),
    .v          ( v             ),
    .framecnt   (               )
);

endmodule