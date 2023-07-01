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
    Date: 14-3-2021 */

module jtframe_68kramcs #(parameter W=2)(
    input          rst,
    input          clk,
    input          cpu_cen,

    input          UDSWn,
    input          LDSWn,

    input  [W-1:0] pre_cs,
    output [W-1:0] cs
);

reg         dsn_dly;
reg [W-1:0] cs_latch;

// ram_cs and vram_cs signals go down before DSWn signals
// that causes a false read request to the SDRAM. In order
// to avoid that a little bit of logic is needed:
assign cs  = dsn_dly ? (cs_latch&pre_cs)  : pre_cs;

always @(posedge clk) begin
    if( rst ) begin
        cs_latch <= 0;
        dsn_dly  <= 1;
    end else if(cpu_cen) begin
        cs_latch <= pre_cs;
        dsn_dly  <= &{UDSWn,LDSWn}; // low if any DSWn was low
    end
end

endmodule