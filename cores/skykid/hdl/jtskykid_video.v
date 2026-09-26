/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-9-2026 */

module jtskykid_video(
    input             rst,
    input             clk,
    input             pxl_cen, pxl2_cen, flip, rot,

    output            lvbl, lhbl, hs, vs,
    input      [ 7:0] pri,
    input      [ 8:0] scrx,
    input      [ 7:0] scry,

    output     [12:1] oram_addr,
    output     [10:1] vram0_addr,
    output     [11:1] vram1_addr,
    input      [15:0] vram0_dout, vram1_dout, oram_dout,

    // ROMs
    output            scr0_cs,   scr1_cs,
    output     [12:1] scr0_addr, scr1_addr,
    input      [15:0] scr0_data, scr1_data,
    input             scr0_ok,   scr1_ok,
    output            obj_cs,
    output     [15:2] obj_addr,
    input      [31:0] obj_data,
    input             obj_ok,

    // Palette PROMs
    output     [ 8:0] scrpal_addr, objpal_addr,
    input      [ 7:0] scrpal_data, objpal_data,

    output reg [ 7:0] rgb_addr,
    input      [ 7:0] r_data, g_data, b_data,
    output reg [ 3:0] red, green, blue,

    // Debug
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [ 8:0] hdump, vdump, vrender, vrender1;
wire [ 7:0] obj_pxl;
wire [ 9:0] obj_pal;
wire        obj_op, txt_low, txt_hi;
wire [ 6:0] scr_pal;
wire [ 1:0] scr_pxl;
wire [ 5:0] txt_pal;
wire [ 3:0] txt_cat;
wire [ 1:0] txt_pxl;
wire        txt_op;

assign st_dout     = 0;
assign scrpal_addr = { scr_pal, scr_pxl };

assign txt_op  = txt_pxl!=0    && gfx_en[0];
assign obj_op  = obj_pxl!=8'hff && gfx_en[3];
assign txt_low = txt_op && pri[2] && txt_cat==pri[7:4];
assign txt_hi  = txt_op && !txt_low;

always @(posedge clk) if(pxl_cen) begin
    rgb_addr <= txt_hi  ? {txt_pal,txt_pxl} :
                obj_op  ? obj_pxl           :
                txt_low ? {txt_pal,txt_pxl} :
                (gfx_en[1] ? scrpal_data : 8'd0);
    {red,green,blue} <= {r_data[3:0],g_data[3:0],b_data[3:0]};
end

assign objpal_addr = obj_pal[8:0];

jtpaclan_obj #(.SKYKID(1)) u_obj(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .lvbl       ( lvbl          ),
    .flip       ( flip          ),
    .rot        ( rot           ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),

    .ram_addr   ( oram_addr     ),
    .ram_dout   ( oram_dout     ),

    .pal_addr   ( obj_pal       ),
    .pal_data   ( objpal_data   ),

    .rom_cs     ( obj_cs        ),
    .rom_addr   ( obj_addr      ),
    .rom_data   ( obj_data      ),
    .rom_ok     ( obj_ok        ),

    .pxl        ( obj_pxl       ),
    .debug_bus  ( debug_bus     )
);

jtshouse_vtimer u_vtimer(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .vrender1   ( vrender1      ),
    .hdump      ( hdump         ),
    .lhbl       ( lhbl          ),
    .lvbl       ( lvbl          ),
    .hs         ( hs            ),
    .vs         ( vs            )
);

jtskykid_scroll u_scroll(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .flip       ( flip          ),
    .rot        ( rot           ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .scrx       ( scrx          ),
    .scry       ( scry          ),

    .vram_addr  ( vram1_addr    ),
    .vram_dout  ( vram1_dout    ),

    .rom_cs     ( scr1_cs       ),
    .rom_addr   ( scr1_addr     ),
    .rom_data   ( scr1_data     ),
    .rom_ok     ( scr1_ok       ),

    .pal        ( scr_pal       ),
    .pxl        ( scr_pxl       )
);

jtskykid_text u_text(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .flip       ( flip ^ rot    ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),

    .vram_addr  ( vram0_addr    ),
    .vram_dout  ( vram0_dout    ),

    .rom_cs     ( scr0_cs       ),
    .rom_addr   ( scr0_addr     ),
    .rom_data   ( scr0_data     ),
    .rom_ok     ( scr0_ok       ),

    .pal        ( txt_pal       ),
    .cat        ( txt_cat       ),
    .pxl        ( txt_pxl       )
);

endmodule
