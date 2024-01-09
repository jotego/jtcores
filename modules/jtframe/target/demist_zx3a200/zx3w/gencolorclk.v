//////////////////////////////////////////////////////////////////////////////////
//    This file is gencolorclk
//    Creation date is 21:39:48 07/31/2020 by Miguel Angel Rodriguez Jodar
//    (c)2020 Miguel Angel Rodriguez Jodar. ZXProjects
//
//    This core is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    This core is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this core.  If not, see <https://www.gnu.org/licenses/>.
//
//    All copies of this file must keep this notice intact.
//
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ns
//`default_nettype none

module gencolorclk (
  input wire clk,        // reloj lo más rápido posible (ahora mismo, 140 MHz o 165 Mhz segun valor de altern)
  input wire en,         // habilitar la generación de este reloj de color
  input wire mode,       // 0=PAL, 1=NTSC
  output wire clkcolor4x // (17.734475 MHz PAL ó 14.31818 MHz NTSC)
  );

  // Fout = Fclk * prescaler / (2^nbits)
  // prescaler = Fdesired * (2^nbits) / Fclk
  localparam PHASEACUMPAL  = 29'd95211238;
  localparam PHASEACUMNTSC = 29'd76870144;

  reg [28:0] cnt = 29'h00000000;
  reg [28:0] prescaler = PHASEACUMPAL;
  assign clkcolor4x = (cnt[28] | ~en);
  always @(posedge clk) begin
    case (mode)
      1'b0 : prescaler <= PHASEACUMPAL;
      1'b1 : prescaler <= PHASEACUMNTSC;
      default : prescaler <= PHASEACUMPAL;
    endcase
    cnt <= cnt + prescaler;
  end
endmodule
