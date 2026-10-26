/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-10-2026 */

module jtcrshrc_video(
    input               rst,
    input               clk,
    input               pxl_cen,
    output              spr_busy,

    input      [ 7:0]   gfxctrl,
    input               flip,
    input               roz_we,
    input      [ 4:1]   roz_mmr_addr,
    input      [15:0]   roz_din,
    input      [ 1:0]   roz_dsn,
    input      [ 7:0]   roz_bank,

    output     [11:1]   fgv_addr,
    input      [15:0]   fgv_dout,
    output     [12:1]   rozv_addr,
    input      [15:0]   rozv_dout,
    output     [12:1]   objr_addr,
    input      [15:0]   objr_dout,
    output     [15:1]   objl_addr,
    input      [15:0]   objl_dout,
    output     [11:1]   mix_addr,
    input      [15:0]   mix_pal,

    output     [20:2]   fg_addr,
    output              fg_cs,
    input      [31:0]   fg_data,
    input               fg_ok,
    output     [21:2]   obj_addr,
    output              obj_cs,
    input      [31:0]   obj_data,
    input               obj_ok,
    output     [21:1]   rozrom_addr,
    output              rozrom_cs,
    input      [15:0]   rozrom_data,
    input               rozrom_ok,

    input      [ 3:0]   gfx_en,

    output              LHBL, LVBL, HS, VS,
    output     [ 4:0]   red, green, blue
);

wire attrs_busy, lookup_busy;
assign spr_busy = attrs_busy || lookup_busy;
wire [12:1] scanr_addr;
wire [15:0] scanr_dout;
wire [15:1] scanl_addr;
wire [15:0] scanl_dout;

jtcrshrc_snapshot #(
    .AW      ( 12                ),
    .SIMFILE ( "sprvram_buf.bin" )
) u_attrs(
    .rst       ( rst        ),
    .clk       ( clk        ),
    .LVBL      ( preLVBL    ),
    .busy      ( attrs_busy ),
    .live_addr ( objr_addr  ),
    .live_data ( objr_dout  ),
    .draw_addr ( scanr_addr ),
    .draw_data ( scanr_dout )
);

jtcrshrc_snapshot #(
    .AW      ( 15              ),
    .SIMFILE ( "sprcg_buf.bin" )
) u_lookup(
    .rst       ( rst         ),
    .clk       ( clk         ),
    .LVBL      ( preLVBL     ),
    .busy      ( lookup_busy ),
    .live_addr ( objl_addr   ),
    .live_data ( objl_dout   ),
    .draw_addr ( scanl_addr  ),
    .draw_data ( scanl_dout  )
);

wire [ 8:0] hdump, vdump, vrender, vrender1;
wire [ 7:0] fg_pxl;
wire [10:0] obj_pxl;
wire [ 7:0] roz_pxl;
wire        roz_on;
wire [10:0] pxl;
wire        fg_op, obj_op;
wire [ 4:0] mix_red, mix_green, mix_blue;
wire        preLHBL, preLVBL;
reg  [ 1:0] blank_dly;

assign { LHBL, LVBL } = blank_dly;

always @(posedge clk) if( pxl_cen ) begin
    blank_dly <= { preLHBL, preLVBL };
end

assign red   = gfxctrl[2] ? 5'd0 : mix_red;
assign green = gfxctrl[2] ? 5'd0 : mix_green;
assign blue  = gfxctrl[2] ? 5'd0 : mix_blue;

localparam [8:0] H_END = 9'd455, V_END = 9'd261;
localparam [8:0] HB_START = 9'd319, HB_END = H_END;
localparam [8:0] VB_START = 9'd223, VB_END = V_END;
localparam [8:0] HS_START = 9'd344, HS_END = 9'd375;
localparam [8:0] VS_START = 9'd232, VS_END = 9'd235;

jtframe_vtimer #(
    .HCNT_START ( 9'd0     ),
    .HCNT_END   ( H_END    ),
    .HB_START   ( HB_START ),
    .HB_END     ( HB_END   ),
    .HS_START   ( HS_START ),
    .HS_END     ( HS_END   ),
    .V_START    ( 9'd0     ),
    .VCNT_END   ( V_END    ),
    .VB_START   ( VB_START ),
    .VB_END     ( VB_END   ),
    .VS_START   ( VS_START ),
    .VS_END     ( VS_END   )
) u_vtimer(
    .clk      ( clk      ),
    .pxl_cen  ( pxl_cen  ),
    .vdump    ( vdump    ),
    .vrender  ( vrender  ),
    .vrender1 ( vrender1 ),
    .H        ( hdump    ),
    .Hinit    (          ),
    .Vinit    (          ),
    .LHBL     ( preLHBL  ),
    .LVBL     ( preLVBL  ),
    .HS       ( HS       ),
    .VS       ( VS       )
);

jtf1grpr_fg #(
    .CODEW       ( 14 ),
    .VFLIP       ( 0  ),
    .HOFFSET     ( 0  ),
    .VOFFSET     ( 0  ),
    .SCROLL_COMP ( 0  )
) u_fg(
    .rst      ( rst      ),
    .clk      ( clk      ),
    .pxl_cen  ( pxl_cen  ),
    .flip     ( flip     ),
    .hdump    ( hdump    ),
    .h_last   ( H_END    ),
    .hsize    ( HB_START ),
    .vsize    ( VB_START ),
    .vdump    ( vdump    ),
    .scrx     ( 9'd0     ),
    .scry     ( 9'd0     ),

    .fgv_addr ( fgv_addr ),
    .fgv_dout ( fgv_dout ),

    .rom_addr ( fg_addr  ),
    .rom_cs   ( fg_cs    ),
    .rom_data ( fg_data  ),
    .rom_ok   ( fg_ok    ),

    .pxl      ( fg_pxl   )
);

jtf1gpr2_obj #(
    .ATTR_AW ( 12 ),
    .LUT_AW  ( 15 ),
    .ROM_AW  ( 22 )
) u_obj(
    .rst       ( rst        ),
    .clk       ( clk        ),
    .pxl_cen   ( pxl_cen    ),
    .hs        ( HS         ),
    .flip      ( flip       ),
    .hdump     ( hdump      ),
    .vrender   ( vrender    ),
    .hsize     ( HB_START   ),
    .vsize     ( VB_START   ),

    .objr_addr ( scanr_addr ),
    .objr_dout ( scanr_dout ),
    .objl_addr ( scanl_addr ),
    .objl_dout ( scanl_dout ),

    .rom_addr  ( obj_addr   ),
    .rom_cs    ( obj_cs     ),
    .rom_data  ( obj_data   ),
    .rom_ok    ( obj_ok     ),

    .pxl       ( obj_pxl    )
);

jtf1gpr2_roz #(
    .CODEW     ( 12      ),
    .XOFFSET   ( 27      ),
    .YOFFSET   ( 4       ),
    .ROM_BYTES ( 3145728 ),
    .PIPELINED ( 1       )
) u_roz(
    .rst       ( rst          ),
    .clk       ( clk          ),
    .pxl_cen   ( pxl_cen      ),
    .hs        ( HS           ),
    .vs        ( VS           ),
    .hdump     ( hdump        ),
    .vdump     ( vdump        ),
    .flip      ( flip         ),

    .cs        ( roz_we       ),
    .addr      ( roz_mmr_addr ),
    .din       ( roz_din      ),
    .dsn       ( roz_dsn      ),

    .roz_bank  ( roz_bank     ),

    .rozv_addr ( rozv_addr    ),
    .rozv_dout ( rozv_dout    ),

    .rom_addr  ( rozrom_addr  ),
    .rom_cs    ( rozrom_cs    ),
    .rom_data  ( rozrom_data  ),
    .rom_ok    ( rozrom_ok    ),

    .pxl       ( roz_pxl      ),
    .on        ( roz_on       )
);

assign fg_op  = gfx_en[0] && fg_pxl != 8'hff;
assign obj_op = gfx_en[3] && obj_pxl[3:0] != 4'hf;
wire roz_op   = gfx_en[1] && roz_on && roz_pxl[3:0] != 4'hf;
wire [10:0] roz_out = 11'h100 + { 3'd0, roz_pxl };

reg [10:0] pxl_r;
always @* begin
    if( gfxctrl[2] )
        pxl_r = 11'd0;
    else case( gfxctrl[1:0] )
        2'd0: pxl_r = roz_op ? roz_out : fg_op ? {3'd0,fg_pxl} : obj_op ? obj_pxl : 11'h1ff;
        2'd1, 2'd2: pxl_r = obj_op ? obj_pxl : roz_op ? roz_out : fg_op ? {3'd0,fg_pxl} : 11'h1ff;
        default: pxl_r = 11'h1ff;
    endcase
end
assign pxl = pxl_r;

jtf1grpr_colmix u_colmix(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .pxl_cen  ( pxl_cen   ),
    .LHBL     ( preLHBL   ),
    .LVBL     ( preLVBL   ),

    .pxl      ( pxl       ),

    .mix_addr ( mix_addr  ),
    .mix_pal  ( mix_pal   ),

    .red      ( mix_green ),
    .green    ( mix_blue  ),
    .blue     ( mix_red   )
);

endmodule
