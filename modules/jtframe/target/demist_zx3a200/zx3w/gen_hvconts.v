//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.04.2023 01:35:49
// Design Name: 
// Module Name: gen_hvconts
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps
//`default_nettype none

module gen_hvconts (
    input wire clk,
    input wire clken,
    input wire reset_n,
    input wire hs_n,
    input wire vs_n,
    output reg [10:0] hcont,
    output reg [10:0] vcont,
    output reg locked
    );
    
    initial locked = 0;
    reg [10:0] htotal, vtotal;
    reg [10:0] ihtotal, ivtotal;
    reg [10:0] ihcont,ivcont;
    reg [2:0] fase = 0;
    reg hs_n_prev = 1;
    reg vs_n_prev = 1;
    wire posedge_hs = (hs_n_prev == 0 && hs_n == 1);
    wire posedge_vs = (vs_n_prev == 0 && vs_n == 1);
    
    always @(posedge clk) begin
      if (reset_n == 0) begin
        fase <= 0;
        locked <= 0;
      end
      else if (clken == 1) begin

        if (locked == 1) begin
          if (hcont == htotal) begin
            hcont <= 0;
            if (vcont == vtotal)
              vcont <= 0;
            else
              vcont <= vcont + 1;
          end
          else
            hcont <= hcont + 1;
        end
      
        hs_n_prev <= hs_n;
        vs_n_prev <= vs_n;
        case (fase)
          0: begin
               if (posedge_vs)
                 fase <= 1;
             end
          1: begin
               if (posedge_hs) begin
                 fase <= 2;
                 ihcont <= 0;
               end
             end
          2: begin
               if (posedge_hs) begin  // ha pasado un scan (el primero)
                 ihtotal <= ihcont;
                 ihcont <= 0;
                 ivcont <= 1;
                 fase <= 3;
               end
               else
                 ihcont <= ihcont + 1;
             end
          3: begin
               if (posedge_vs) begin
                 ivtotal <= ivcont;
                 ivcont <= 0;
                 fase <= 4;
               end
               else if (hcont == htotal) begin
                 ihcont <= 0;
                 ivcont <= ivcont + 1;
               end
               else
                 ihcont <= ihcont + 1;
             end
          4: begin
               if (posedge_hs) begin  // en este punto tenemos htotal y vtotal, y estamos en la esquina sup. izq
                 fase <= 2;
                 ihcont <= 0;
                 hcont <= 0;
                 vcont <= 0;
                 htotal <= ihtotal;
                 vtotal <= ivtotal;
                 locked <= 1;
               end
             end
        endcase
      end
    end     
endmodule
