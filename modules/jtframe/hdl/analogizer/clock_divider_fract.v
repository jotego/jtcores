`timescale 1ns / 1ps

module clock_divider_fract (
    input wire i_clk,
    input wire i_rst,
    input wire [31:0] i_step,
    output reg o_stb
);
    reg [31:0] counter=33'd0;

    always @(posedge i_clk) begin
        if(i_rst) //synchronous reset
            counter <= 32'd0;
        else
            {o_stb,counter} <= counter + i_step;
    end
endmodule