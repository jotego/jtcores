`timescale 1ns / 1ps

module test;

reg clk, rst, cen6;

initial begin
    clk=0;
    cen6=0;
    forever #41.66 clk=~clk;    // 12 MHz
end

always @(posedge clk) cen6<=~cen6 & ~rst;

initial begin
    rst = 1;
    #50 rst=0;
end

wire LHBL, LVBL, intrq, hsync, vsync, sync;

parameter LAYOUT=0;

jtgng_timer #(
    .LAYOUT ( LAYOUT    )
) u_timer(
    .clk        ( clk   ),
    .cen6       ( cen6  )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    $dumpon;
end

initial begin
    #60_000_000 $finish;
end

endmodule
