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
    Date: 31-10-2019 */

// Converts an input strobe (stin) defined in some clock gating domain
// to a strobe in the specified cen input domain
// both clock-enable signals belong to the same clock domain

module jtframe_cencross_strobe(
    input       rst,
    (* direct_enable *) input       cen,
    input       clk,
    input       stin,
    output reg  stout
);

reg  last, st_latch;
wire st_edge = stin && !last;

always @(posedge clk, posedge rst) begin
    if(rst) begin
        last     <= 1'b0;
        st_latch <= 1'b0;
    end else begin 
        last <= stin;
        if( st_edge ) st_latch <= 1'b1;
        if( stout ) st_latch <= 1'b0;
    end
end

always @(posedge clk, posedge rst) begin
    if(rst) begin
        stout    <= 1'b0;
    end else  if(cen) begin
        stout <= st_latch | st_edge;
    end
end

endmodule