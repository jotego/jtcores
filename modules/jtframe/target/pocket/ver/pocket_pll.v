`timescale 1ns/1ps

// 96 MHz PLL
module pll_pocket(
    input        rst,
    input        refclk,
    output reg   outclk_0,
    output reg   locked
);
    initial begin
        locked = 0;
        #30 locked = 1;
    end

    real base_clk = 37.037; //  27 MHz

    initial begin
        outclk_0 = 0;
        forever outclk_0 = #(base_clk/2.0) ~outclk_0;
    end
endmodule


module pll_audio(
    input      rst,
    input      refclk,
    output reg outclk_0
);
    initial begin
        outclk_0 = 0;
        forever outclk_0 = #40.69 ~outclk_0;
    end
endmodule