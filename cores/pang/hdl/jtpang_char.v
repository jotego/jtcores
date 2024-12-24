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
    Date: 21-5-2022 */

module jtpang_char(
    input             rst,
    input             clk,
    input             pxl_cen,

    input     [ 8:0]  h,
    input     [ 8:0]  hf,
    input     [ 7:0]  vf,
    input             hs,
    input             flip,
    input             char_en,

    input             vram_msb,
    input             vram_cs,
    input             attr_cs,
    input             wr_n,
    input      [11:0] cpu_addr,
    input      [ 7:0] cpu_dout,
    output     [ 7:0] vram_dout,
    output     [ 7:0] attr_dout,

    // DMA
    input      [ 8:0] dma_addr,
    input             busak_n,

    output reg [20:2] rom_addr,
    input      [31:0] rom_data,
    output            rom_cs,

    output     [10:0] pxl
);

wire [ 7:0] code_dout, scan_dout;
wire        vram_we, attr_we;
wire [12:0] scan_addr, vram_addr;
reg  [ 7:0] code_lsb;
reg  [31:0] pxl_data;
reg  [ 6:0] pal, nx_pal;
reg         hflip, nx_hflip;

assign vram_we   = vram_cs & ~wr_n;
assign attr_we   = attr_cs & ~wr_n;
assign scan_addr = { 1'b0, vf[7:3], hf[8:3], h[0] };
assign rom_cs    = ~hs;
assign pxl       = { pal, hflip ? pxl_data[31:28] : pxl_data[3:0] };
assign vram_addr = busak_n ? { vram_msb, cpu_addr } : { 1'b1, dma_addr[8:2], 3'b0, dma_addr[1:0] };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
    end else if(pxl_cen) begin
        case( { hf[2:1], h[0] } )
            0: code_lsb <= code_dout;
            1: begin
                rom_addr <= { code_dout, code_lsb, vf[2:0] };
                { nx_hflip, nx_pal } <= scan_dout;
            end
        endcase
        if( {hf[2:1],h[0]}==1 ) begin
            pxl_data <= {
                rom_data[11], rom_data[15], rom_data[ 3], rom_data[ 7],
                rom_data[10], rom_data[14], rom_data[ 2], rom_data[ 6],
                rom_data[ 9], rom_data[13], rom_data[ 1], rom_data[ 5],
                rom_data[ 8], rom_data[12], rom_data[ 0], rom_data[ 4],
                rom_data[27], rom_data[31], rom_data[19], rom_data[23],
                rom_data[26], rom_data[30], rom_data[18], rom_data[22],
                rom_data[25], rom_data[29], rom_data[17], rom_data[21],
                rom_data[24], rom_data[28], rom_data[16], rom_data[20]
            };
            if( !char_en ) pxl_data <= 0;
            { hflip, pal } <= { nx_hflip^~flip, nx_pal };
        end else
            pxl_data <= hflip ? pxl_data << 4 : pxl_data >> 4;
    end
end

// Upper half = objects, lower half = tile map
jtframe_dual_ram #(.AW(13)) u_vram (
    // CPU
    .clk0  ( clk        ),
    .data0 ( cpu_dout   ),
    .addr0 ( vram_addr  ),
    .we0   ( vram_we    ),
    .q0    ( vram_dout  ),
    // Scan
    .clk1  ( clk        ),
    .data1 ( 8'd0       ),
    .addr1 ( scan_addr  ),
    .we1   ( 1'd0       ),
    .q1    ( code_dout  )
);

jtframe_dual_ram #(.AW(11)) u_attr (
    // CPU
    .clk0  ( clk        ),
    .data0 ( cpu_dout   ),
    .addr0 ( cpu_addr[10:0]   ),
    .we0   ( attr_we    ),
    .q0    ( attr_dout  ),
    // Scan
    .clk1  ( clk        ),
    .data1 ( 8'd0       ),
    .addr1 ( scan_addr[11:1] ),
    .we1   ( 1'd0       ),
    .q1    ( scan_dout  )
);

endmodule