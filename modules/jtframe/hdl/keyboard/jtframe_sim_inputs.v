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
    Date: 19-1-2024 */

module jtframe_sim_inputs(
    input             rst,
    input             vs,

    output      [6:0] joy1,
    output            start, service,
    output            coin,test, game_rst
);
`ifndef SIMINPUTS
assign {game_rst,test,joy1,service,start,coin} = 0;
`else
assign {game_rst,test,joy1,service,start,coin} = sim_inputs[frame_cnt][12:0];

reg [15:0] sim_inputs[0:16383];

integer frame_cnt;

initial begin : read_sim_inputs
    integer c;
    for( c=0; c<16384; c=c+1 ) sim_inputs[c] = 0;
    $display("INFO: input simulation enabled");
    $readmemh( "sim_inputs.hex", sim_inputs );
end

always @(negedge vs, posedge rst) begin
    if( rst ) begin
        frame_cnt <= 0;
    end else begin
        frame_cnt <= frame_cnt+1;
    end
end
`endif
endmodule