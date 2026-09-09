/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-9-2026 */

module jtnnjema_video(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             m4_en,
    input             flip,
    input             dispen_n,
    input      [ 2:0] layers,

    // CPU access
    input             cpu_vram_we,
    input      [10:0] cpu_vram_addr,
    input      [ 7:0] cpu_dout,

    // scroll: galivan from CPU ports, ninjemak from the NB1414M4
    input      [12:0] main_scrx,
    input      [10:0] main_scry,
    input             blit_stb,
    input             vb_ack,

    // sprite RAM DMA
    output     [ 8:0] odma_addr,
    input      [ 7:0] oram_dout,

    // text RAM (brams in mem.yaml)
    output     [ 9:0] vcode_scan,
    input      [ 7:0] vcode_dout,
    output     [ 9:0] vattr_scan,
    input      [ 7:0] vattr_dout,
    output     [ 9:0] vcwr_addr,
    output     [ 7:0] vcwr_din,
    output            vcwr_we,
    input      [ 7:0] vcwr_dout,
    output     [ 9:0] vawr_addr,
    output     [ 7:0] vawr_din,
    output            vawr_we,

    // SDRAM
    output     [14:2] char_addr,
    input      [31:0] char_data,
    output            char_cs,
    input             char_ok,

    output     [14:1] bgmap_addr,
    input      [15:0] bgmap_data,
    output            bgmap_cs,
    input             bgmap_ok,

    output     [16:2] scr_addr,
    input      [31:0] scr_data,
    output            scr_cs,
    input             scr_ok,

    output     [16:2] obj_addr,
    input      [31:0] obj_data,
    output            obj_cs,
    input             obj_ok,

    // PROMs / NB1414M4 ROM
    output     [13:0] m4rom_addr,
    input      [ 7:0] m4rom_data,
    output     [ 7:0] objbank_addr,
    input      [ 3:0] objbank_data,
    output     [ 7:0] objlut_addr,
    input      [ 3:0] objlut_data,
    output     [ 7:0] red_addr,
    output     [ 7:0] green_addr,
    output     [ 7:0] blue_addr,
    input      [ 3:0] red_data,
    input      [ 3:0] green_data,
    input      [ 3:0] blue_data,

    output            LHBL,
    output            LVBL,
    output            HS,
    output            VS,
    output     [ 8:0] vdump,
    output     [ 8:0] hdump,
    output     [ 3:0] red,
    output     [ 3:0] green,
    output     [ 3:0] blue
);

wire [ 8:0] vrender;
wire [ 7:0] char_pxl, scr_pxl;
wire [11:0] obj_pxl;
wire [ 9:0] scan_addr;
wire [ 7:0] m4_dout;
wire [10:0] m4_addr;
wire [12:0] m4_scrx, scrx;
wire [10:0] m4_scry, scry;
wire        m4_we, m4_busy;
wire [10:0] wr_addr;
wire [ 7:0] wr_din;
wire        wr_we;
wire        blankn = LHBL & LVBL;

// the NB1414M4 owns the text RAM while blitting
assign wr_addr = m4_busy ? m4_addr : cpu_vram_addr;
assign wr_din  = m4_busy ? m4_dout : cpu_dout;
assign wr_we   = m4_busy ? m4_we   : cpu_vram_we;
assign scrx    = m4_en ? m4_scrx : main_scrx;
assign scry    = m4_en ? m4_scry : main_scry;

assign vcode_scan = scan_addr;
assign vattr_scan = scan_addr;
assign vcwr_addr  = wr_addr[9:0];
assign vawr_addr  = wr_addr[9:0];
assign vcwr_din   = wr_din;
assign vawr_din   = wr_din;
assign vcwr_we    = wr_we & ~wr_addr[10];
assign vawr_we    = wr_we &  wr_addr[10];

// 384x263 total, 256x224 visible, HS 15.624kHz
jtframe_vtimer #(
    .HCNT_END ( 9'd383 ),
    .HB_START ( 9'd255 ),
    .HB_END   ( 9'd383 ),
    .HS_START ( 9'd300 ),
    .HS_END   ( 9'd327 ),
    .V_START  ( 9'd0   ),
    .VCNT_END ( 9'd262 ),
    .VB_START ( 9'd239 ),
    .VB_END   ( 9'd15  ),
    .VS_START ( 9'd244 ),
    .VS_END   ( 9'd247 )
) u_vtimer(
    .clk      ( clk       ),
    .pxl_cen  ( pxl_cen   ),
    .vdump    ( vdump     ),
    .vrender  ( vrender   ),
    .vrender1 (           ),
    .H        ( hdump     ),
    .Hinit    (           ),
    .Vinit    (           ),
    .LHBL     ( LHBL      ),
    .LVBL     ( LVBL      ),
    .HS       ( HS        ),
    .VS       ( VS        )
);

jtnnjema_1414 u_1414(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .blit_stb ( blit_stb  ),
    .vb_ack   ( vb_ack    ),
    .vram_addr( m4_addr   ),
    .vram_dout( vcwr_dout ),
    .vram_din ( m4_dout   ),
    .vram_we  ( m4_we     ),
    .rom_addr ( m4rom_addr),
    .rom_data ( m4rom_data),
    .scrx     ( m4_scrx   ),
    .scry     ( m4_scry   ),
    .busy     ( m4_busy   )
);

jtnnjema_char u_char(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .pxl_cen  ( pxl_cen   ),
    .m4_en    ( m4_en     ),
    .flip     ( flip      ),
    .hdump    ( hdump     ),
    .vdump    ( vdump     ),
    .blankn   ( blankn    ),
    .scan_addr( scan_addr ),
    .code_dout( vcode_dout),
    .attr_dout( vattr_dout),
    .rom_addr ( char_addr ),
    .rom_cs   ( char_cs   ),
    .rom_ok   ( char_ok   ),
    .rom_data ( char_data ),
    .pxl      ( char_pxl  )
);

jtnnjema_scr u_scr(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .pxl_cen  ( pxl_cen   ),
    .m4_en    ( m4_en     ),
    .flip     ( flip      ),
    .hs       ( HS        ),
    .hdump    ( hdump     ),
    .vdump    ( vdump     ),
    .blankn   ( blankn    ),
    .scrx     ( scrx      ),
    .scry     ( scry      ),
    .map_addr ( bgmap_addr),
    .map_cs   ( bgmap_cs  ),
    .map_ok   ( bgmap_ok  ),
    .map_data ( bgmap_data),
    .rom_addr ( scr_addr  ),
    .rom_cs   ( scr_cs    ),
    .rom_ok   ( scr_ok    ),
    .rom_data ( scr_data  ),
    .pxl      ( scr_pxl   )
);

jtnnjema_obj u_obj(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .pxl_cen  ( pxl_cen   ),
    .m4_en    ( m4_en     ),
    .flip     ( flip      ),
    .hs       ( HS        ),
    .LVBL     ( LVBL      ),
    .hdump    ( hdump     ),
    .vrender  ( vrender   ),
    .oram_addr( odma_addr ),
    .oram_data( oram_dout ),
    .objbank_addr( objbank_addr ),
    .objbank_data( objbank_data ),
    .rom_addr ( obj_addr  ),
    .rom_cs   ( obj_cs    ),
    .rom_ok   ( obj_ok    ),
    .rom_data ( obj_data  ),
    .pxl      ( obj_pxl   )
);

jtnnjema_colmix u_colmix(
    .clk      ( clk       ),
    .pxl_cen  ( pxl_cen   ),
    .m4_en    ( m4_en     ),
    .layers   ( layers    ),
    .dispen_n ( dispen_n  ),
    .char_pxl ( char_pxl  ),
    .scr_pxl  ( scr_pxl   ),
    .obj_pxl  ( obj_pxl   ),
    .LHBL     ( LHBL      ),
    .LVBL     ( LVBL      ),
    .objlut_addr( objlut_addr ),
    .objlut_data( objlut_data ),
    .red_addr ( red_addr  ),
    .green_addr( green_addr ),
    .blue_addr( blue_addr ),
    .red_data ( red_data  ),
    .green_data( green_data ),
    .blue_data( blue_data ),
    .red      ( red       ),
    .green    ( green     ),
    .blue     ( blue      )
);

endmodule
