/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 22-9-2023 */

module jtshouse_cenloop(
    input             rst,
    input             clk,
    input      [ 1:0] busy,

    output reg [ 1:0] cpu_cen,
    output     [15:0] fave, fworst // average cpu_cen frequency in kHz
);

parameter FCLK = 49152,
          FCPU =  1536*2,
          NUM  = 1,
          DEN  = FCLK/FCPU,
          CW   = $clog2(FCLK/FCPU)+4;

reg           clk2;
wire          over;
wire [  CW:0] cencnt_nx;
reg  [CW-1:0] cencnt=0;

assign over      = cencnt > DEN[CW-1:0]-{NUM[CW-2:0],1'b0};
assign cencnt_nx = {1'b0,cencnt}+NUM[CW:0] -
                   (over && busy==0 ? DEN[CW:0] : {CW+1{1'b0}});

always @(posedge clk) begin
    cencnt  <= cencnt_nx[CW] ? {CW{1'b1}} : cencnt_nx[CW-1:0];
    if( (over && busy==0) || rst ) begin
        clk2 <= ~clk2;
        cpu_cen[0] <=  clk2;
        cpu_cen[1] <= ~clk2;
    end else begin
        cpu_cen <= 0;
    end
end

jtframe_freqinfo #(.MFREQ( FCLK )) u_info(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pulse      ( clk2      ),
    .fave       ( fave      ), // average cpu_cen frequency in kHz
    .fworst     ( fworst    )
);

endmodule