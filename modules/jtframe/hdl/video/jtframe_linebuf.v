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
    Date: 27-10-2017 */

module jtframe_linebuf #(parameter
    DW=8,
    AW=9
)(
    input            clk,
    input            LHBL,  // the line buffer is swapped when this signal goes low
                            // you can use ~HS instead of LHBL too
    // New data writes
    input   [AW-1:0] wr_addr,
    input   [DW-1:0] wr_data,
    input            we,
    // Old data reads
    input   [AW-1:0] rd_addr,
    output  [DW-1:0] rd_data,
    output  [DW-1:0] rd_gated
);

reg     line, last_LHBL;

wire [DW-1:0]       dump_data;

`ifdef SIMULATION
initial begin
    line = 0;
end
`endif

always @(posedge clk) begin
    last_LHBL <= LHBL;
    if( !LHBL && last_LHBL )
        line <= ~line;
end

assign rd_gated = LHBL ? rd_data : {DW{1'b0}};

jtframe_rpwp_ram #(.AW(AW+1),.DW(DW)) u_line(
    .clk    ( clk           ),

    .din    ( wr_data       ),
    .wr_addr( {line,wr_addr}),
    .we     ( we            ),

    .rd_addr({~line,rd_addr}),
    .dout   ( rd_data       )
);

endmodule