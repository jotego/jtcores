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
    Date: 3-9-2022 */

module jtkchamp_char(
    input               rst,
    input               clk,        // 48 MHz
    input               clk24,      // 24 MHz

    input               pxl_cen,
    input        [ 8:0] vdump,
    input        [ 8:0] hdump,
    input               flip,

    input        [10:0] cpu_addr,
    input        [ 7:0] cpu_dout,
    output       [ 7:0] cpu_din,
    input               vram_cs,
    input               cpu_rnw,

    output              rom_cs,
    input               rom_ok,
    output reg   [13:0] rom_addr,
    input        [15:0] rom_data,
    input        [ 7:0] debug_bus,

    output       [ 6:0] pxl
);

wire        we_hi, we_lo;
wire [ 7:0] dout_lo, dout_hi;
wire [15:0] scan_dout;
reg  [15:0] pxl_data;
reg  [ 4:0] pal, nx_pal;
wire [ 9:0] scan_addr;
reg  [ 7:0] heff;

assign cpu_din   = cpu_addr[10] ? dout_hi : dout_lo;
assign we_hi     = vram_cs &  cpu_addr[10] & ~cpu_rnw;
assign we_lo     = vram_cs & ~cpu_addr[10] & ~cpu_rnw;
assign scan_addr = { vdump[7:3], heff[7:3] };
assign rom_cs    = ~vdump[8];
assign pxl       = { pal, flip ? {pxl_data[ 8], pxl_data[0]} :
                                 {pxl_data[15], pxl_data[7]} };

always @* begin
    heff = hdump[7:0];
    if( flip ) begin
        heff = hdump[7:0]+ 8'hf8;
        if( hdump[8:7]==2'b11 ) heff[7] = 1;
    end
end

always @(posedge clk) if( pxl_cen ) begin
    if( heff[2:0]==0 ) begin
        rom_addr <= { scan_dout[10:0], vdump[2:0] };
        pxl_data <= rom_data;
        pal      <= nx_pal;
        nx_pal   <= scan_dout[15:11];
    end else begin
        pxl_data <= flip ? pxl_data >> 1 : pxl_data << 1;
    end
end

jtframe_dual_ram #(.SIMFILE("chlo.bin")) u_low(
    // CPU
    .clk0   ( clk24     ),
    .data0  ( cpu_dout  ),
    .addr0  (cpu_addr[9:0]),
    .we0    ( we_lo     ),
    .q0     ( dout_lo   ),
    // VIDEO
    .clk1   ( clk       ),
    .data1  (           ),
    .addr1  ( scan_addr ),
    .we1    ( 1'b0      ),
    .q1     ( scan_dout[7:0] )
);

jtframe_dual_ram #(.SIMFILE("chhi.bin")) u_high(
    // CPU
    .clk0   ( clk24     ),
    .data0  ( cpu_dout  ),
    .addr0  (cpu_addr[9:0]),
    .we0    ( we_hi     ),
    .q0     ( dout_hi   ),
    // VIDEO
    .clk1   ( clk       ),
    .data1  (           ),
    .addr1  ( scan_addr ),
    .we1    ( 1'b0      ),
    .q1     ( scan_dout[15:8])
);

endmodule