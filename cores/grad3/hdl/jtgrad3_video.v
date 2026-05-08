/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jtgrad3_video(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             pxl2_cen,
    input             prio,

    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,
    output            tile_irqn,
    output            tile_nmin,
    output reg        sub_irq2,

    input      [16:1] m_cpu_addr,
    input      [ 1:0] m_cpu_dsn,
    input      [15:0] m_cpu_dout,
    input             m_cpu_we,
    input      [16:1] s_cpu_addr,
    input      [ 1:0] s_cpu_dsn,
    input      [15:0] s_cpu_dout,
    input             s_cpu_we,
    input             m_tilesys_cs,
    input             s_tilesys_cs,
    input             objsys_cs,
    output            vdtack,
    output     [ 7:0] tilesys_dout,
    output     [ 7:0] objsys_dout,
    output     [11:1] pal_rd_addr,
    input      [15:0] palrd_dout,
    input             rmrd,

    input      [10:0] prog_addr,
    input      [ 7:0] prog_data,
    input             prom_pal_we,

    output reg [16:2] lyrf_addr,
    output reg [16:2] lyra_addr,
    output reg [16:2] lyrb_addr,
    output     [20:2] lyro_addr,
    input      [31:0] lyrf_data,
    input      [31:0] lyra_data,
    input      [31:0] lyrb_data,
    input      [31:0] lyro_data,
    output            lyrf_cs,
    output            lyra_cs,
    output            lyrb_cs,
    output            lyro_cs,
    input             lyra_ok,
    input             lyro_ok,

    output     [ 4:0] red,
    output     [ 4:0] green,
    output     [ 4:0] blue,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,

    // Debug
    input      [25:0] ioctl_addr,
    input             ioctl_ram,
    output reg [ 7:0] ioctl_din,

    output     [ 7:0] st_dout
);

wire [ 8:0] hdump, vdump, vrender, vrender1;
wire [15:0] tile_cpu_addr, cpu_saddr;
wire [10:0] cpu_oaddr;
wire [ 7:0] cpu_d8, obj_cpu_d8;
wire [12:0] pre_f, pre_a, pre_b, ocode;
wire [31:0] lyrf_draw_data, lyra_draw_data, lyrb_draw_data;
wire [11:0] lyra_pxl, lyrb_pxl, lyro_pxl;
wire [ 7:0] lyrf_pxl, lyrf_col, lyra_col, lyrb_col, opal;
wire [ 7:0] st_scr, st_obj;
wire [ 7:0] scroll_din, obj_din, scroll_mmr, obj_reg;
wire        rst8, e, q, ormrd, obj_irqn, obj_nmin, shadow, pre_vdtack;
wire        lyrf_blnk_n, lyra_blnk_n, lyrb_blnk_n, lyro_blnk_n;
wire        cpu_weg, obj_cpu_weg, tile_cpu_sel, tilesys_cs;
wire [ 1:0] tile_cpu_dsn;
wire [15:0] tile_cpu_dout;
wire        tile_cpu_we;
reg  [13:0] ocode_eff;
reg  [ 7:0] opal_eff;

// Gradius 3 wires the 16-bit CPU buses to byte-wide Konami video chips through
// the board glue logic. The word address selects the chip offset and the active
// byte lane selects the data byte driven onto the 8-bit device bus.
assign tile_cpu_sel  = s_tilesys_cs;
assign tile_cpu_addr = tile_cpu_sel ? s_cpu_addr : m_cpu_addr;
assign tile_cpu_dsn  = tile_cpu_sel ? s_cpu_dsn  : m_cpu_dsn;
assign tile_cpu_dout = tile_cpu_sel ? s_cpu_dout : m_cpu_dout;
assign tile_cpu_we   = tile_cpu_sel ? s_cpu_we   : m_cpu_we;
assign tilesys_cs    = m_tilesys_cs | s_tilesys_cs;
assign cpu_saddr     = tile_cpu_addr - 16'h6000;  // ??????
assign cpu_oaddr     = s_cpu_addr[11:1];
assign cpu_d8        = tile_cpu_dout[7:0];
assign obj_cpu_d8    = !s_cpu_dsn[0] ? s_cpu_dout[7:0] : s_cpu_dout[15:8];
assign cpu_weg       = tile_cpu_we && tile_cpu_dsn != 2'b11;
assign obj_cpu_weg   = s_cpu_we && s_cpu_dsn != 2'b11;
assign vdtack    = pre_vdtack;
assign lyro_addr = ca;
assign st_dout   = (s_tilesys_cs | objsys_cs) ? st_obj : st_scr;

wire [18:0] ca;
wire [ 1:0] obj_pri;

assign obj_pri = lyro_pxl[10:9];

function [7:0] cgate( input [7:0] c );
    cgate = { 1'b0, c[7:5], 4'd0 };
endfunction

function [31:0] grad3_char_order( input [31:0] data );
    grad3_char_order = {
        data[19:16], data[23:20], data[27:24], data[31:28],
        data[ 3: 0], data[ 7: 4], data[11: 8], data[15:12]
    };
endfunction

function [31:0] grad3_051962_data( input [31:0] data );
    reg [31:0] ordered;
    begin
        ordered = grad3_char_order( data );
        grad3_051962_data = {
            ordered[ 3], ordered[ 7], ordered[11], ordered[15],
            ordered[19], ordered[23], ordered[27], ordered[31],
            ordered[ 2], ordered[ 6], ordered[10], ordered[14],
            ordered[18], ordered[22], ordered[26], ordered[30],
            ordered[ 1], ordered[ 5], ordered[ 9], ordered[13],
            ordered[17], ordered[21], ordered[25], ordered[29],
            ordered[ 0], ordered[ 4], ordered[ 8], ordered[12],
            ordered[16], ordered[20], ordered[24], ordered[28]
        };
    end
endfunction


/*function [31:0] grad3_051962_data( input [31:0] data );
    reg [31:0] ordered;
    begin
        ordered = data; //grad3_char_order( data );
        grad3_051962_data = {
            ordered[16], ordered[20], ordered[24], ordered[28],
            ordered[ 8], ordered[12], ordered[ 0], ordered[ 4],
            ordered[17], ordered[21], ordered[25], ordered[29],
            ordered[ 9], ordered[13], ordered[ 2], ordered[ 5],
            ordered[18], ordered[22], ordered[26], ordered[30],
            ordered[10], ordered[14], ordered[ 3], ordered[ 6],
            ordered[19], ordered[22], ordered[27], ordered[31],
            ordered[11], ordered[15], ordered[ 3], ordered[ 7]
        };
    end
endfunction
*/

function [31:0] obj_order( input [31:0] raw );
    obj_order = {
        raw[15], raw[11], raw[ 7], raw[ 3], raw[31], raw[27], raw[23], raw[19],
        raw[14], raw[10], raw[ 6], raw[ 2], raw[30], raw[26], raw[22], raw[18],
        raw[13], raw[ 9], raw[ 5], raw[ 1], raw[29], raw[25], raw[21], raw[17],
        raw[12], raw[ 8], raw[ 4], raw[ 0], raw[28], raw[24], raw[20], raw[16]
    };
endfunction

assign lyrf_draw_data = grad3_051962_data( lyrf_data );
assign lyra_draw_data = grad3_051962_data( lyra_data );
assign lyrb_draw_data = grad3_051962_data( lyrb_data );

always @* begin
    lyrf_addr = { lyrf_col[4:2], lyrf_col[0], pre_f[10:0] };
    lyra_addr = { lyra_col[4:2], lyra_col[0], pre_a[10:0] };
    lyrb_addr = { lyrb_col[4:2], lyrb_col[0], pre_b[10:0] };
    ocode_eff = { opal[0], ocode };
    opal_eff  = { 1'b0, opal[6:5], 1'b1, opal[4:1] };
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        sub_irq2 <= 0;
    end else begin
        sub_irq2 <= pxl_cen && hdump == 9'h020 && vdump == 9'h120;
    end
end

always @(*) begin
    if( !ioctl_addr[14] )
        ioctl_din = scroll_din;
    else if( !ioctl_addr[10] )
        ioctl_din = obj_din;
    else if( !ioctl_addr[3] )
        ioctl_din = scroll_mmr;
    else if( ioctl_addr[2:0] != 3'h7 )
        ioctl_din = obj_reg;
    else
        ioctl_din = 8'hff;
end

jtgrad3_scroll #(
    .FULLRAM     ( 1 ),
    .COL_PASSTHRU( 1 ),
    .LOGICAL_MAP ( 1 ),
    .FORCE_BANKS( 1 ),
    .BANK0_INIT ( 8'h10 ),
    .BANK1_INIT ( 8'h32 )
) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),

    .cpu_addr   ( cpu_saddr ),
    .cpu_dout   ( cpu_d8    ),
    .cpu_we     ( cpu_weg   ),
    .gfx_cs     ( tilesys_cs),
    .rst8       ( rst8      ),
    .tile_dout  ( tilesys_dout ),
    .cpu_rom_dtack( pre_vdtack ),

    .rmrd       ( 1'b0      ),
    .irq_n      ( tile_irqn ),
    .firq_n     (           ),
    .nmi_n      ( tile_nmin ),
    .flip       (           ),
    .q          ( q         ),
    .e          ( e         ),

    .lyrf_addr  ( pre_f     ),
    .lyra_addr  ( pre_a     ),
    .lyrb_addr  ( pre_b     ),
    .lyrf_cs    ( lyrf_cs   ),
    .lyra_cs    ( lyra_cs   ),
    .lyrb_cs    ( lyrb_cs   ),
    .lyrf_data  ( lyrf_draw_data ),
    .lyra_data  ( lyra_draw_data ),
    .lyrb_data  ( lyrb_draw_data ),
    .lyra_ok    ( lyra_ok   ),

    .lyrf_col   ( lyrf_col  ),
    .lyra_col   ( lyra_col  ),
    .lyrb_col   ( lyrb_col  ),
    .lyrf_extra (           ),
    .lyra_extra (           ),
    .lyrb_extra (           ),
    .lyrf_cg    ( cgate(lyrf_col) ),
    .lyra_cg    ( cgate(lyra_col) ),
    .lyrb_cg    ( cgate(lyrb_col) ),

    .lyrf_blnk_n( lyrf_blnk_n ),
    .lyra_blnk_n( lyra_blnk_n ),
    .lyrb_blnk_n( lyrb_blnk_n ),
    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  ),

    .ioctl_addr ( ioctl_addr[14:0]     ),
    .ioctl_ram  ( ioctl_ram            ),
    .ioctl_din  ( scroll_din           ),
    .mmr_dump   ( scroll_mmr           ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_scr    )
);

jtaliens_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( hs        ),
    .vs         ( vs        ),
    .lvbl       ( lvbl      ),
    .lhbl       ( lhbl      ),
    .hdump      ( hdump     ),
    .vdump      ( vrender   ),

    .cs         ( objsys_cs ),
    .cpu_addr   ( cpu_oaddr ),
    .cpu_dout   ( obj_cpu_d8 ),
    .cpu_we     ( obj_cpu_weg),
    .cpu_din    ( objsys_dout ),

    .irq_n      ( obj_irqn  ),
    .nmi_n      ( obj_nmin  ),
    .code       ( ocode     ),
    .code_eff   ( ocode_eff ),
    .pal        ( opal      ),
    .pal_eff    ( opal_eff  ),

    .rom_addr   ( ca        ),
    .rom_data   ( obj_order(lyro_data) ),
    .rom_ok     ( lyro_ok   ),
    .rom_cs     ( lyro_cs   ),
    .romrd      ( ormrd     ),

    .pxl        ( lyro_pxl  ),
    .blank_n    ( lyro_blnk_n ),
    .shadow     ( shadow    ),

    .ioctl_addr ( ioctl_addr[10:0]     ),
    .ioctl_ram  ( ioctl_ram            ),
    .ioctl_din  ( obj_din              ),
    .dump_reg   ( obj_reg              ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_obj    )
);

jtgrad3_colmix u_colmix(
    .rst         ( rst         ),
    .clk         ( clk         ),
    .pxl_cen     ( pxl_cen     ),
    .prio        ( prio        ),
    .obj_pri     ( obj_pri     ),

    .lhbl        ( lhbl        ),
    .lvbl        ( lvbl        ),

    .pal_rd_addr ( pal_rd_addr ),
    .palrd_dout  ( palrd_dout  ),

    .prog_data   ( prog_data[3:0]),
    .prog_addr   ( prog_addr[7:0]),
    .prom_pal_we ( prom_pal_we ),

    .lyrf_blnk_n ( lyrf_blnk_n ),
    .lyra_blnk_n ( lyra_blnk_n ),
    .lyrb_blnk_n ( lyrb_blnk_n ),
    .lyro_blnk_n ( lyro_blnk_n ),
    .lyrf_pxl    ( lyrf_pxl    ),
    .lyra_pxl    ( lyra_pxl    ),
    .lyrb_pxl    ( lyrb_pxl    ),
    .lyro_pxl    ( lyro_pxl    ),
    .shadow      ( shadow      ),

    .red         ( red         ),
    .green       ( green       ),
    .blue        ( blue        ),

    .debug_bus   ( debug_bus   )
);

endmodule
