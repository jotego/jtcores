`timescale 1ns/1ps

module pll(
    input      refclk,
    input      rst,
    output     locked,
    output     outclk_0,    // clk_sys, 48 MHz
    output     outclk_1,    // SDRAM_CLK = clk_sys delayed
    output     outclk_2,    // 24
    output     outclk_3,    // 6
    output reg outclk_4,    // 96
    output     outclk_5     // 96 shifted
);

assign locked = 1'b1;

`ifdef BASE_CLK
real base_clk = `BASE_CLK;
initial $display("INFO mister_pll48: base clock set to %f ns",base_clk);
`else
real base_clk = 10.417; // 96 MHz
`endif

reg [3:0] clkdiv;

initial begin
    clkdiv   = 4'd0;
    outclk_4 = 0;
    forever outclk_4 = #(base_clk/2.0) ~outclk_4; // 108 MHz
end

always @(posedge outclk_4)
    clkdiv <= clkdiv+4'd1;

reg div=1'b0;

`ifndef SDRAM_DELAY
`define SDRAM_DELAY 4
`endif

real sdram_delay = `SDRAM_DELAY;
initial $display("INFO mister_pll24: SDRAM_CLK delay set to %f ns",sdram_delay);
assign outclk_0 = clkdiv[0];
assign outclk_2 = clkdiv[1];
assign outclk_3 = clkdiv[3];
assign #sdram_delay outclk_1 = outclk_0;
assign #sdram_delay outclk_5 = outclk_4;

endmodule // pll