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
    Date: 1-5-2022 */

module jtvigil_scr1(
    input         rst,
    input         clk,
    input         clk_cpu,
    input         pxl_cen,
    input         flip,

    input  [11:0] main_addr,
    input  [ 7:0] main_dout,
    output [ 7:0] main_din,
    input         main_rnw,
    input         scr1_cs,

    input  [ 8:0] h,
    input  [ 8:0] v,
    input         hs,
    input  [ 8:0] scrpos,
    output [17:2] rom_addr,
    input  [31:0] rom_data, // 32/4 = 8 pixels
    output        rom_cs,
    input         rom_ok,
    input  [ 7:0] debug_bus,
    output [ 7:0] pxl
);

localparam SCORE_ROW = 6; // 6*8 = 48,  256-48=208

reg  [ 8:0] hsum;
reg  [31:0] pxl_data;
reg  [ 3:0] pal;

// Scan
wire        ram_we;
wire [11:0] scan_addr;
wire [ 9:0] hraw;
wire [ 7:0] scan_dout;
reg  [ 7:0] pre_code, code, attr;

assign ram_we   = scr1_cs & ~main_rnw;
assign rom_cs   = ~hs; // do not read while HS can occur
assign rom_addr = { 1'b0, attr[7:4], code, v[2:0] };
assign pxl = { pal, flip ?
    {pxl_data[31], pxl_data[23], pxl_data[15], pxl_data[7] } :
    {pxl_data[24], pxl_data[16], pxl_data[ 8], pxl_data[0] } };
assign scan_addr = { v[7:3], hsum[8:3], hsum[0] };
assign hraw = {1'b0, h[8], h[7]|h[8], h[6:0] } +
            (v[7:3] >= SCORE_ROW ? { 1'b0, scrpos } : 10'd0)
            + 10'h7f;
jtframe_dual_ram #(.AW(12)) u_vram(
    // CPU
    .clk0 ( clk_cpu   ),
    .addr0( main_addr ),
    .data0( main_dout ),
    .we0  ( ram_we    ),
    .q0   ( main_din  ),
    // Tilemap scan
    .clk1 ( clk       ),
    .addr1( scan_addr ),
    .data1(           ),
    .we1  ( 1'b0      ),
    .q1   ( scan_dout )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hsum     <= 0;
    end else if(pxl_cen) begin
        hsum     <= { hraw[8], hraw[7:0] };
        case( hsum[2:0] )
            0: pre_code <= scan_dout;
            1: if(rom_ok) begin // do not change the rom_addr while rom_ok is low
                code <= pre_code;
                attr <= scan_dout;
            end
        endcase
    end
end

always @(posedge clk) if(pxl_cen) begin
    case( hsum[2:0] )   // 8 pixel delay
        7: begin
            pxl_data <= {
                rom_data[15:12], rom_data[31:28],
                rom_data[11: 8], rom_data[27:24],
                rom_data[ 7: 4], rom_data[23:20],
                rom_data[ 3: 0], rom_data[19:16]
            };
            pal <= attr[3:0];
        end
        default: begin
            pxl_data <= flip ? pxl_data << 1 : pxl_data >> 1;
        end
    endcase
end

endmodule