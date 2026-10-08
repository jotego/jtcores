`timescale 1ns/1ps

module pll(
    input      refclk,
    output reg locked,
    output reg outclk_0,    // clk_rom, 108 MHz
    output reg outclk_1,    // SDRAM_CLK
    output reg outclk_2=1'b0     // clk_sys, 24 MHz
);

assign locked = 1'b1;

`ifdef BASE_CLK
real base_clk = `BASE_CLK;
initial $display("INFO mister_pll24: base clock set to %f ns",base_clk);
`else
real base_clk = 10.4; // 96MHz
`endif

initial begin
    outclk_0 = 1'b0;
    forever outclk_0 = #(base_clk/2.0) ~outclk_0; // 108 MHz
end

reg div=1'b0;

initial outclk_2=1'b0;

always @(posedge outclk_0) begin
    { outclk_2, div } <= { outclk_2, div } + 2'd1;
end

`ifdef SDRAM_DELAY
real sdram_delay = `SDRAM_DELAY;
initial $display("INFO mister_pll24: SDRAM_CLK delay set to %f ns",sdram_delay);
assign #sdram_delay outclk_1 = outclk_0;
`else
initial $display("INFO mister_pll24: SDRAM_CLK delay set to 0 ns");
assign outclk_1 = outclk_0;
`endif

endmodule // pll