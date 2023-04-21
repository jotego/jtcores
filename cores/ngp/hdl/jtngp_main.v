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
    Date: 19-3-2023 */

module jtngp_main(
    input             rst,
    input             clk,
);

reg  [15:0] din;
wire [23:0] addr;
wire [15:0] dout, ram0_dout, ram1_dout;
wire [ 1:0] we;
wire [ 2:0] intrq;
wire        cpu_cen; // 6.144 MHz

function in_range( input [23:0] min, max );
    in_range = addr>=min && addr<max;
endfunction

always @* begin
    io_cs     = in_range(24'h00_0080, 24'h00_00c0);
    ram0_cs   = in_range(24'h00_4000, 24'h00_6000); //  8kB exclusive
    ram1_cs   = in_range(24'h00_6000, 24'h00_7000); //  4kB exclusive
    shd_cs    = in_range(24'h00_7000, 24'h00_8000); //  4kB shared
    gfx_cs    = in_range(24'h00_8000, 24'h00_c000); // 16kB GFX RAM
    flash0_cs = in_range(24'h20_0000, 24'h40_0000);
    flash1_cs = in_range(24'h80_0000, 24'hA0_0000);
    rom_cs    = in_range(24'hFF_0000, 24'h00_0000);
end

jtframe_ram16 #(.AW(12)) u_ram0(
    .clk    ( clk           ),
    .data   ( dout          ),
    .addr   ( addr[12:1]    ),
    .we     ( ram0_we       ),
    .q      ( ram0_dout     )
);

jtframe_ram16 #(.AW(11)) u_ram1(
    .clk    ( clk           ),
    .data   ( dout          ),
    .addr   ( addr[11:1]    ),
    .we     ( ram1_we       ),
    .q      ( ram1_dout     )
);

jt900h u_cpu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cpu_cen   ),

    .addr       ( addr      ),
    .din        ( din       ),
    .dout       ( dout      ),
    .we         ( we        ),

    .intrq      ( intrq     ),     // interrupt request
    // Register dump
    .dmp_addr   (           ),     // dump
    .dmp_dout   (           )
);

endmodule