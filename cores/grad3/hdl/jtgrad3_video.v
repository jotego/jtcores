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
    input             pal_cs,
    output            vdtack,
    output     [ 7:0] tilesys_dout,
    output     [ 7:0] objsys_dout,
    output     [15:0] pal_dout,
    input             rmrd,

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

    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,

    input      [15:0] ioctl_addr,
    input             ioctl_ram,
    output     [ 7:0] ioctl_din,
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [ 8:0] hdump, vdump, vrender, vrender1;
wire [15:0] tile_cpu_addr, cpu_saddr;
wire [10:0] cpu_oaddr;
wire [ 7:0] cpu_d8, obj_cpu_d8;
wire [12:0] pre_f, pre_a, pre_b, ocode;
wire [11:0] lyra_pxl, lyrb_pxl, lyro_pxl;
wire [ 7:0] lyrf_pxl, lyrf_col, lyra_col, lyrb_col, opal;
wire [ 7:0] dump_scr, dump_obj, dump_pal, st_scr, st_obj;
wire        rst8, e, q, ormrd, obj_irqn, obj_nmin, shadow, pre_vdtack;
wire        lyrf_blnk_n, lyra_blnk_n, lyrb_blnk_n, lyro_blnk_n;
wire        cpu_weg, obj_cpu_weg, line16, tile_cpu_sel, tilesys_cs;
wire [ 1:0] tile_cpu_dsn;
wire [15:0] tile_cpu_dout;
wire        tile_cpu_we;
reg         line16_l;
reg  [13:0] ocode_eff;
reg  [ 7:0] opal_eff;

// Gradius 3 uses 16-bit CPU bus wrappers around byte-wide Konami video chips.
// MAME's halfword handlers pass the word offset to K052109/K051960 and select
// one byte from the 68000 data bus, rather than folding the byte lane into A0
// as TMNT does.
assign tile_cpu_sel  = s_tilesys_cs;
assign tile_cpu_addr = tile_cpu_sel ? s_cpu_addr : m_cpu_addr;
assign tile_cpu_dsn  = tile_cpu_sel ? s_cpu_dsn  : m_cpu_dsn;
assign tile_cpu_dout = tile_cpu_sel ? s_cpu_dout : m_cpu_dout;
assign tile_cpu_we   = tile_cpu_sel ? s_cpu_we   : m_cpu_we;
assign tilesys_cs    = m_tilesys_cs | s_tilesys_cs;
assign cpu_saddr     = tile_cpu_addr - 16'h6000;
assign cpu_oaddr     = s_cpu_addr[11:1];
assign cpu_d8        = !tile_cpu_dsn[0] ? tile_cpu_dout[7:0] : tile_cpu_dout[15:8];
assign obj_cpu_d8    = !s_cpu_dsn[0] ? s_cpu_dout[7:0] : s_cpu_dout[15:8];
assign cpu_weg       = tile_cpu_we && tile_cpu_dsn != 2'b11;
assign obj_cpu_weg   = s_cpu_we && s_cpu_dsn != 2'b11;
assign vdtack    = pre_vdtack;
assign lyro_addr = ca;
assign line16    = hdump == 9'h020 && vdump == 9'h120;
assign st_dout   = (s_tilesys_cs | objsys_cs) ? st_obj : st_scr;

wire [18:0] ca;
wire [1:0] obj_pri = lyro_pxl[10:9];

function [7:0] cgate( input [7:0] c );
    cgate = { c[7:5], 5'd0 };
endfunction

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
        line16_l <= 0;
    end else if( pxl_cen ) begin
        line16_l <= line16;
        sub_irq2 <= line16 & ~line16_l;
    end else begin
        sub_irq2 <= 0;
    end
end

`ifdef JTGRAD3_TRACE_VIDEO
reg        trace_lvbl_l;
reg [15:0] trace_frame;
reg [31:0] trace_tile_writes, trace_tile_nonzero, trace_tile_reg;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        trace_lvbl_l      <= 0;
        trace_frame       <= 0;
        trace_tile_writes <= 0;
        trace_tile_nonzero<= 0;
        trace_tile_reg    <= 0;
    end else begin
        trace_lvbl_l <= lvbl;
        if( trace_lvbl_l & ~lvbl ) begin
            if( trace_frame[3:0] == 4'd0 || trace_tile_writes != 0 )
                $display("G3VID frame=%0d tile_wr=%0d tile_nz=%0d tile_reg=%0d",
                    trace_frame, trace_tile_writes, trace_tile_nonzero, trace_tile_reg);
            trace_frame        <= trace_frame + 1'd1;
            trace_tile_writes  <= 0;
            trace_tile_nonzero <= 0;
            trace_tile_reg     <= 0;
        end
        if( tilesys_cs && cpu_weg ) begin
            trace_tile_writes <= trace_tile_writes + 1'd1;
            if( cpu_d8 != 8'd0 ) trace_tile_nonzero <= trace_tile_nonzero + 1'd1;
            if( cpu_saddr[12:10] == 3'b111 ) trace_tile_reg <= trace_tile_reg + 1'd1;
        end
    end
end
`endif

`ifdef JTGRAD3_TRACE_FIX_FETCH
always @(posedge clk) begin
    if( pxl_cen && hdump[2:0] == 3'd0 &&
        ((vdump >= 9'h180 && vdump <= 9'h187 && hdump >= 9'h0d0 && hdump <= 9'h138) ||
         pre_f[10:3] == 8'h22) )
        $display("G3FETCH hd=%03x vd=%03x pre=%04x col=%02x addr=%05x data=%08x",
            hdump, vdump, pre_f, lyrf_col, {lyrf_addr,1'b0}, lyrf_data);
end
`endif

`ifdef JTGRAD3_TRACE_CODEF_WRITE
reg        trace_codef_lvbl_l;
reg [15:0] trace_codef_frame;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        trace_codef_lvbl_l <= 0;
        trace_codef_frame  <= 0;
    end else begin
        trace_codef_lvbl_l <= lvbl;
        if( trace_codef_lvbl_l & ~lvbl )
            trace_codef_frame <= trace_codef_frame + 1'd1;
        if( tilesys_cs && cpu_weg && cpu_saddr >= 16'h2400 && cpu_saddr < 16'h2500 )
            $display("G3CODEF frame=%0d sel=%b saddr=%04x dsn=%b d16=%04x d8=%02x",
                trace_codef_frame, tile_cpu_sel, cpu_saddr, tile_cpu_dsn, tile_cpu_dout, cpu_d8);
    end
end
`endif

jtaliens_scroll #(
    .FULLRAM     ( 1 ),
    .COL_PASSTHRU( 1 ),
    .CHAR_RAM_LAYOUT( 1 ),
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

    .rmrd       ( rmrd      ),
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
    .lyrf_data  ( lyrf_data ),
    .lyra_data  ( lyra_data ),
    .lyrb_data  ( lyrb_data ),
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

    .ioctl_addr ( ioctl_addr[14:0] ),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( dump_scr  ),
    .mmr_dump   (           ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_scr    )
);

jtaliens_obj #(
    .GRADIUS3_LAYOUT( 1 )
) u_obj(
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
    .rom_data   ( lyro_data ),
    .rom_ok     ( lyro_ok   ),
    .rom_cs     ( lyro_cs   ),
    .romrd      ( ormrd     ),

    .pxl        ( lyro_pxl  ),
    .blank_n    ( lyro_blnk_n ),
    .shadow     ( shadow    ),

    .ioctl_addr ( ioctl_addr[10:0] ),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( dump_obj  ),
    .dump_reg   (           ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_obj    )
);

jtgrad3_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .prio       ( prio      ),
    .obj_pri    ( obj_pri   ),

    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),

    .cpu_addr   ( m_cpu_addr[12:1] ),
    .cpu_dout   ( m_cpu_dout ),
    .cpu_dsn    ( m_cpu_dsn  ),
    .cpu_we     ( m_cpu_we   ),
    .pal_cs     ( pal_cs   ),
    .cpu_din    ( pal_dout ),

    .lyrf_blnk_n( lyrf_blnk_n ),
    .lyra_blnk_n( lyra_blnk_n ),
    .lyrb_blnk_n( lyrb_blnk_n ),
    .lyro_blnk_n( lyro_blnk_n ),
    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  ),
    .lyro_pxl   ( lyro_pxl  ),
    .shadow     ( shadow    ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    .ioctl_addr ( ioctl_addr[11:0] ),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( dump_pal  ),
    .debug_bus  ( debug_bus )
);

assign ioctl_din = debug_bus[5] ? dump_obj : debug_bus[4] ? dump_pal : dump_scr;

endmodule
