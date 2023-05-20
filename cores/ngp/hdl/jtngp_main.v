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
    input             cen6,

    // Bus access
    output       [15:1] cpu_addr,
    output       [15:0] cpu_dout,
    input        [15:0] gfx_dout,
    input        [15:0] shd_dout,
    output       [ 1:0] we,
    output       [ 1:0] shd_we,
    output reg          gfx_cs,
    output              flash0_cs,
    output              flash1_cs,

    // Firmware access
    output              rom_cs,
    input        [15:0] rom_data,
    input               rom_ok
);

reg  [15:0] din;
wire [23:0] addr;
wire [15:0] ram0_dout, ram1_dout;
reg         ram0_cs, ram1_cs,
            shd_cs,  io_cs;
wire [ 1:0] ram0_we, ram1_we;
wire [ 3:0] map_cs;

assign cpu_addr  = addr[15:1];
assign flash0_cs = map_cs[0], // in_range(24'h20_0000, 24'h40_0000);
       flash1_cs = map_cs[1]; // in_range(24'h80_0000, 24'hA0_0000);
assign ram0_we   = {2{ram0_cs}} & we,
       ram1_we   = {2{ram1_cs}} & we,
       shd_we    = {2{ shd_cs}} & we;

function in_range( input [23:0] min, max );
    in_range = addr>=min && addr<max;
endfunction

always @* begin
    io_cs     = in_range(24'h00_0080, 24'h00_00c0);
    ram0_cs   = in_range(24'h00_4000, 24'h00_6000); //  8kB exclusive
    ram1_cs   = in_range(24'h00_6000, 24'h00_7000); //  4kB exclusive
    shd_cs    = in_range(24'h00_7000, 24'h00_8000); //  4kB shared
    gfx_cs    = in_range(24'h00_8000, 24'h00_c000); // 16kB GFX RAM
    rom_cs    = in_range(24'hFF_0000, 24'h00_0000); // maybe map_cs[2/3] could be used too?
end

always @(posedge clk) begin
    din <= gfx_cs  ? gfx_dout  :
           rom_cs  ? rom_data  :
           ram0_cs ? ram0_dout :
           ram1_cs ? ram1_dout :
           shd_cs  ? shd_dout  : 16'h0;
           // io_cs   ? io_dout :
           // snd_cs   ?  :
end

jtframe_ram16 #(.AW(12)) u_ram0(
    .clk    ( clk           ),
    .data   ( cpu_dout      ),
    .addr   ( addr[12:1]    ),
    .we     ( ram0_we       ),
    .q      ( ram0_dout     )
);

jtframe_ram16 #(.AW(11)) u_ram1(
    .clk    ( clk           ),
    .data   ( cpu_dout      ),
    .addr   ( addr[11:1]    ),
    .we     ( ram1_we       ),
    .q      ( ram1_dout     )
);

jt95c061 u_mcu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen6      ),

    .addr       ( addr      ),
    .din        ( din       ),
    .dout       ( cpu_dout  ),
    .we         ( we        ),

    .map_cs     ( map_cs    )
);

endmodule