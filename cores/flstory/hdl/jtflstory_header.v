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
    Date: 23-11-2024 */

module jtflstory_header(
    input       clk,
                header, prog_we,
    input [2:0] prog_addr,
    input [7:0] prog_data,
    output reg  mirror=0, mcu_enb=0, coinxor=0, gfx=0, prio=0,
                palw=0,   cab=0,     obj=0
);

localparam [2:0] MIRROR  = 3'd1,
                 MCUENB  = 3'd2,
                 COINXOR = 3'd3,
                 GFXCFG  = 3'd4,
                 PRIOCFG = 3'd5,
                 PALW    = 3'd6;

always @(posedge clk) begin
    if( header && prog_addr[2:0]==MIRROR  && prog_we ) mirror  <= prog_data[0];
    if( header && prog_addr[2:0]==MCUENB  && prog_we ) mcu_enb <= prog_data[0];
    if( header && prog_addr[2:0]==COINXOR && prog_we ) coinxor <= prog_data[0];
    if( header && prog_addr[2:0]==GFXCFG  && prog_we ) gfx     <= prog_data[0];
    if( header && prog_addr[2:0]==PRIOCFG && prog_we ) prio    <= prog_data[0];
    if( header && prog_addr[2:0]==PALW    && prog_we ) begin
        {obj,cab,palw} <= prog_data[2:0];
    end
end

endmodule