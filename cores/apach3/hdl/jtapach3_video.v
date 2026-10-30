/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

module jtapach3_video(
    input             rst,
    input             clk,
    input             pxl_cen,
    input      [15:0] rotate_data,
    input             rotate_we,
    input       [7:0] road_z,
    input             ground_invalidate,
    input             road_invalidate,
    output      [8:1] road_x_addr,
    input      [15:0] road_x_data,
    output      [8:0] prom_addr,
    input       [7:0] prom_data,
    output     [15:1] ground_addr,
    output            ground_cs,
    input      [15:0] ground_data,
    input             ground_ok,
    output     [13:1] objram_addr,
    input      [15:0] objram_data,
    output      [8:1] obj_ctrl_addr,
    input      [15:0] obj_ctrl_data,
    output     [20:3] sprites_addr,
    output            sprites_cs,
    input      [63:0] sprites_data,
    input             sprites_ok,
    output     [12:1] txmap_addr,
    input      [15:0] txmap_data,
    output     [16:2] text_rom_addr,
    output            text_rom_cs,
    input      [31:0] text_rom_data,
    input             text_rom_ok,
    output     [11:1] palette_video_addr,
    input      [15:0] palette_video_data,
    output reg [ 4:0] red,
    output reg [ 4:0] green,
    output reg [ 4:0] blue,
    output            LHBL,
    output            LVBL,
    output            HS,
    output            VS
);

wire [8:0] h, v;
wire [6:0] text_pxl;
wire [10:0] ground_pxl;
wire [9:0] obj_pxl;
wire obj_overflow;
reg shadow;
wire ground_overflow;
wire rgb_visible = h == 399 ? (v == 279 || v < 239) : LHBL && LVBL;
assign palette_video_addr = text_pxl[2:0] != 0 ? 11'd768 + {4'd0,text_pxl} :
                            obj_pxl[8] ? {3'd0,obj_pxl[7:0]} : ground_pxl;

always @(posedge clk) begin
    if (rst) begin
        shadow <= 0;
        red <= 0;
        green <= 0;
        blue <= 0;
    end else if (pxl_cen) begin
        shadow <= obj_pxl[9] && text_pxl[2:0] == 0 && !obj_pxl[8];
        red   <= rgb_visible ? (shadow ? {1'b0,palette_video_data[14:11]} : palette_video_data[14:10]) : 5'd0;
        green <= rgb_visible ? (shadow ? {1'b0,palette_video_data[ 9: 6]} : palette_video_data[ 9: 5]) : 5'd0;
        blue  <= rgb_visible ? (shadow ? {1'b0,palette_video_data[ 4: 1]} : palette_video_data[ 4: 0]) : 5'd0;
    end
end

jtframe_vtimer #(
    .VB_START ( 9'd239 ),
    .VB_END   ( 9'd279 ),
    .VS_START ( 9'd244 ),
    .VS_END   ( 9'd248 ),
    .HB_START ( 9'd319 ),
    .HB_END   ( 9'd399 ),
    .HS_START ( 9'd336 ),
    .HS_END   ( 9'd367 ),
    .H_VNEXT  ( 9'd399 )
) u_vtimer (
    .clk      ( clk     ),
    .pxl_cen  ( pxl_cen ),
    .vdump    ( v       ),
    .vrender  (         ),
    .vrender1 (         ),
    .H        ( h       ),
    .Hinit    (         ),
    .Vinit    (         ),
    .LHBL     ( LHBL    ),
    .LVBL     ( LVBL    ),
    .HS       ( HS      ),
    .VS       ( VS      )
);

jtapach3_obj u_obj (
    .rst       ( rst           ),
    .clk       ( clk           ),
    .pxl_cen   ( pxl_cen       ),
    .h         ( h             ),
    .v         ( v             ),
    .ram_addr  ( objram_addr   ),
    .ram_data  ( objram_data   ),
    .ctrl_addr ( obj_ctrl_addr ),
    .ctrl_data ( obj_ctrl_data ),
    .rom_addr  ( sprites_addr  ),
    .rom_cs    ( sprites_cs    ),
    .rom_data  ( sprites_data  ),
    .rom_ok    ( sprites_ok    ),
    .pxl       ( obj_pxl       ),
    .overflow  ( obj_overflow  )
);

jtapach3_text u_text (
    .rst      ( rst           ),
    .clk      ( clk           ),
    .pxl_cen  ( pxl_cen       ),
    .h        ( h             ),
    .v        ( v             ),
    .map_addr ( txmap_addr    ),
    .map_data ( txmap_data    ),
    .gfx_addr ( text_rom_addr ),
    .gfx_data ( text_rom_data ),
    .gfx_cs   ( text_rom_cs   ),
    .gfx_ok   ( text_rom_ok   ),
    .pxl      ( text_pxl      )
);

jtapach3_ground u_ground (
    .rst             ( rst               ),
    .clk             ( clk               ),
    .pxl_cen         ( pxl_cen           ),
    .h               ( h                 ),
    .v               ( v                 ),
    .rotate_data     ( rotate_data       ),
    .rotate_we       ( rotate_we         ),
    .road_z          ( road_z            ),
    .invalidate      ( ground_invalidate ),
    .road_invalidate ( road_invalidate   ),
    .road_x_addr     ( road_x_addr       ),
    .road_x_data     ( road_x_data       ),
    .prom_addr       ( prom_addr         ),
    .prom_data       ( prom_data         ),
    .ram_addr        ( ground_addr       ),
    .ram_cs          ( ground_cs         ),
    .ram_data        ( ground_data       ),
    .ram_ok          ( ground_ok         ),
    .pxl             ( ground_pxl        ),
    .overflow        ( ground_overflow   )
);

`ifdef SIMULATION
`ifdef APACH3_OBJ_RGB_TRACE
always @(posedge clk) if (pxl_cen && v>=162 && v<=164 && (h<3 || h>395))
    $display("OBJ_RGB h=%0d v=%0d obj=%h text=%h ground=%h paladdr=%h pal=%h shadow=%b blank=%b/%b rgb=%h/%h/%h",h,v,obj_pxl,text_pxl,ground_pxl,palette_video_addr,palette_video_data,shadow,LHBL,LVBL,red,green,blue);
`endif
`endif
endmodule
