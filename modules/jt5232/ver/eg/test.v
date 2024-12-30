`timescale 1ns / 1ps

module test;

`include "../../hdl/jt5232.vh"

reg           clk=0, we, rst, clk_ref=0;
wire          cen1, cen2;
wire [TW-1:0] tone_a, tone_b;
reg  [   1:0] div=0;
reg  [   7:0] din;
reg  [   3:0] addr;

assign cen1 = clk & div[0];
assign cen2 = clk && div==1;

initial forever #10.416 clk =~clk; // 48 MHz


always @(posedge clk) begin
    div <= div+2'd1;
end

integer fsel;
wire fsignal = uut.u_tg0.pipes[fsel];

initial begin
    we=0; din=0; addr=0;
    // reset
    rst=1;
    repeat(20) @(negedge clk);
    @(negedge uut.cen256);
    rst=0;
    repeat(20) @(negedge clk);
    // enable harmonics and EG
    addr=12; din=8'h2f; we=1; @(negedge clk);
                        we=0; @(negedge clk);
    // program 440 Hz signal
    // Try fast ON/OFF
    @(negedge clk);
    addr=0; din=8'hA1; we=1; @(negedge clk);
                       we=0; @(negedge clk);
    repeat(200) @(negedge uut.cen256);
    @(negedge clk);
    addr=0; din=8'h21; we=1; @(negedge clk);
                       we=0; @(negedge clk);
    repeat(2_000) @(negedge uut.cen256);
    @(negedge clk);
    addr=0; din=8'hA1; we=1; @(negedge clk);
                       we=0; @(negedge clk);
    repeat(4000) @(negedge uut.cen256);
    // release
    @(negedge clk);
    addr=0; din=8'h21; we=1; @(negedge clk);
                       we=0; @(negedge clk);
    repeat(20_000) @(negedge uut.cen256);
    //
    // try ARM=1
    @(negedge clk);
    addr=12; din=8'h30; we=1; @(negedge clk);
                        we=0; @(negedge clk);
    @(negedge clk);
    addr=0; din=8'hA1; we=1; @(negedge clk);
                       we=0; @(negedge clk);
    repeat(20_000) @(negedge uut.cen256);
    @(negedge clk); // key off
    addr=0; din=8'h21; we=1; @(negedge clk);
                       we=0; @(negedge clk);
    repeat(20_000) @(negedge uut.cen256);
    $display("PASS");
    $finish;
end

jt5232 uut(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen1   ( cen1      ),
    .cen2   ( cen2      ),
    .din    ( din       ),
    .addr   ( addr      ),
    .we     ( we        ),
    .snd1   ( tone_a    ),
    .snd2   ( tone_b    )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
    #400_000_000;
    $fatal(1,"Time over\nFAIL"); // fallback
end

endmodule
