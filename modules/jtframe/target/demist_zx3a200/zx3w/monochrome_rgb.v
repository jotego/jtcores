`timescale 1ns / 1ps
//`default_nettype none

//    This file is part of the ZXUNO Spectrum core. 
//    Creation date is 21:14:58 2023-05-01 by Miguel Angel Rodriguez Jodar
//    (c)2014-2020 ZXUNO association.
//    ZXUNO official repository: http://svn.zxuno.com/svn/zxuno
//    Username: guest   Password: zxuno
//    Github repository for this core: https://github.com/mcleod-ideafix/zxuno_spectrum_core
//
//    ZXUNO Spectrum core is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    ZXUNO Spectrum core is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with the ZXUNO Spectrum core.  If not, see <https://www.gnu.org/licenses/>.
//
//    Any distributed copy of this file must keep this notice intact.

module monochrome (
  input wire [1:0] monochrome_selection,
  input wire [7:0] ri,
  input wire [7:0] gi,
  input wire [7:0] bi,
  output reg [7:0] ro,
  output reg [7:0] go,
  output reg [7:0] bo
  );

  // 0.299 ? Rojo + 0.587 ? Verde + 0.114 ? Azul.
  //wire [15:0] grisp = ri*8'd77 + gi*8'd150 + bi * 8'd29;  // los factores se multiplican por 256 (punto fijo 8.8)
  wire [15:0] grisp = ri*8'd80 + gi*8'd144 + bi * 8'd32;  // los factores se multiplican por 256 (punto fijo 8.8)
  wire [7:0] gris = grisp[15:8];  // dividido entre 256
  always @* begin
    case (monochrome_selection)
      2'b00:
        begin
          ro = ri;
          go = gi;
          bo = bi;
        end
      2'b01:
        begin
          ro = 8'h00;
          go = gris;
          bo = 8'h00;
        end
      2'b10:
        begin
          ro = gris;
          go = {1'b0,gris[7:1]};
          bo = 8'h00;
        end
      2'b11:
        begin
          ro = gris;
          go = gris;
          bo = gris;
        end
      default:
        begin
          ro = ri;
          go = gi;
          bo = bi;
        end
    endcase
  end
endmodule
