/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 29-1-2023 */

// Generic RAM with clock enable
// parameters:
//      DW      => Data bit width, 8 for byte-based memories
//      AW      => Address bit width, 10 for 1kB
//      SIMFILE => binary file to load during simulation
//      SIMHEXFILE => hexadecimal file to load during simulation
//      SYNFILE => hexadecimal file to load for synthesis
//      CEN_RD  => Use clock enable for reading too, by default it is used
//                 only for writting.


module jtframe_ram_rst #(parameter DW=8, AW=10, CEN_RD=0,
        SIMFILE="", SIMHEXFILE="", SYNFILE=""
)(
    input           rst,
    input           clk,
    input           cen /* direct_enable */,
    input  [DW-1:0] data,
    input  [AW-1:0] addr,
    input           we,
    output [DW-1:0] q
);

reg  [AW-1:0] rst_cnt=0;
wire [AW-1:0] addr_eff;
wire [DW-1:0] data_eff;
wire          cen_eff, we_eff;
reg           rstl;

assign cen_eff  = rstl ? 1'b1       : cen;
assign addr_eff = rstl ? rst_cnt    : addr;
assign data_eff = rstl ? {DW{1'b0}} : data;
assign we_eff   = rstl ? 1'b1       : we;

always @(posedge clk) begin
    rstl <= rst;
    if(rstl) rst_cnt <= rst_cnt+1'd1;
end

jtframe_ram #(
    .AW        ( AW         ),
    .DW        ( DW         ),
    .CEN_RD    ( CEN_RD     ),
    .SIMFILE   ( SIMFILE    ),
    .SIMHEXFILE( SIMHEXFILE ),
    .SYNFILE   ( SYNFILE    )
)u_ramu(
    .clk        ( clk         ),
    .cen        ( cen_eff     ),
    .addr       ( addr_eff    ),
    .data       ( data_eff    ),
    .we         ( we_eff      ),
    .q          ( q           )
);

endmodule
