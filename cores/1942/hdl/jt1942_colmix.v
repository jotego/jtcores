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
    Date: 20-1-2019 */

// 1942 Colour Mixer
// Schematics page 4

module jt1942_colmix(
    input           rst,
    input           clk,    // 24 MHz
    input           cen6 /* synthesis direct_enable = 1 */,
    input [1:0]     game_id,
    // pixel input from generator modules
    input [3:0]     char_pxl,        // character color code
    input [5:0]     scr_pxl,
    input [3:0]     obj_pxl,
    // Palette PROMs E8, E9, E10
    input           prom_e8_we,
    input           prom_e9_we,
    input           prom_e10_we,
    // Single palette PROM for Higemaru
    input   [7:0]   prog_addr,
    input   [7:0]   prom_din,

    input           preLVBL,
    input           preLHBL,
    output          LHBL,
    output          LVBL,

    output    [3:0] red,
    output    [3:0] green,
    output    [3:0] blue,
    // Debug
    input     [3:0] gfx_en
);

`include "1942.vh"
localparam       BLANK_DLY = 2;

wire [11:0] vulgus_pre, vulgus_rgb, hige_pre12;
wire [ 7:0] hige_pre8;
wire        prom_pal_we;
reg  [ 7:0] pixel_mux;
wire [ 3:0] prom_dinlo;

wire char_blank_b = |(~char_pxl);
wire obj_blank_b  = |(~obj_pxl);
reg        vulgus, hige;

assign prom_dinlo  = prom_din[3:0];
assign prom_pal_we = prom_e8_we; // Higemaru's 32-byte palette falls in the rom file at the same position as the red palette in 1942/Vulgus
assign hige_pre12  = { hige_pre8[2:0], hige_pre8[2],
                         hige_pre8[5:3], hige_pre8[5],
                         hige_pre8[7:6], hige_pre8[7:6] };

always @(posedge clk ) begin
    vulgus <= game_id==VULGUS;
    hige   <= game_id==HIGEMARU;
end

always @(*) begin
    if( hige ) begin
        // Object or char
        if( !obj_blank_b || !gfx_en[3])
            pixel_mux = { 4'b0, gfx_en[0]?char_pxl : 4'h0 };
        else
            pixel_mux = { 4'b1, obj_pxl };
    end else begin
        if( !char_blank_b || !gfx_en[0] ) begin
            // Object or scroll
            if( !obj_blank_b || !gfx_en[3])
                pixel_mux[5:0] = gfx_en[2]?(vulgus?{2'b0, scr_pxl[3:0]}:scr_pxl) : ~6'h0; // scroll wins
            else
                pixel_mux[5:0] = {1'b0, vulgus, obj_pxl }; // object wins
        end
        else begin // characters
            pixel_mux[5:0] = { vulgus, 1'b0, char_pxl };
        end
        pixel_mux[7:6] = vulgus ? scr_pxl[5:4] : { char_blank_b, obj_blank_b };
    end
end

// Vulgus / 1942
jtframe_blank #(.DLY(BLANK_DLY),.DW(12)) u_dly(
    .clk        ( clk           ),
    .pxl_cen    ( cen6          ),
    .preLHBL    ( preLHBL       ),
    .preLVBL    ( preLVBL       ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .preLBL     (               ),
    .rgb_in     ( hige ? hige_pre12 : vulgus_pre   ),
    .rgb_out    ( {red,green,blue}    )
);

// palette ROM
jtframe_prom #(.AW(8),.DW(4),.SIMFILE("rom/1942/sb-5.e8")) u_red(
    .clk    ( clk         ),
    .cen    ( cen6        ),
    .data   ( prom_dinlo  ),
    .rd_addr( pixel_mux   ),
    .wr_addr( prog_addr   ),
    .we     ( prom_e8_we  ),
    .q      (vulgus_pre[11:8])
);

jtframe_prom #(.AW(8),.DW(4),.SIMFILE("rom/1942/sb-6.e9")) u_green(
    .clk    ( clk         ),
    .cen    ( cen6        ),
    .data   ( prom_dinlo  ),
    .rd_addr( pixel_mux   ),
    .wr_addr( prog_addr   ),
    .we     ( prom_e9_we  ),
    .q      (vulgus_pre[7:4])
);

jtframe_prom #(.AW(8),.DW(4),.SIMFILE("rom/1942/sb-7.e10")) u_blue(
    .clk    ( clk         ),
    .cen    ( cen6        ),
    .data   ( prom_dinlo  ),
    .rd_addr( pixel_mux   ),
    .wr_addr( prog_addr   ),
    .we     ( prom_e10_we ),
    .q      (vulgus_pre[3:0])
);

// palette ROM
jtframe_prom #(.AW(8),.DW(8),.SIMFILE("rom/hige/hgb3.l6")) u_palette(
    .clk    ( clk                 ),
    .cen    ( cen6                ),
    .data   ( prom_din            ),
    .rd_addr( pixel_mux           ),
    .wr_addr( prog_addr           ),
    .we     ( prom_pal_we         ),
    .q      ( hige_pre8           )
);

endmodule
