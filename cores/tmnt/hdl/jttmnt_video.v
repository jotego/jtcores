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
    Date: 13-8-2023 */

module jttmnt_video(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             pxl2_cen,
    input      [ 2:0] game_id,

    input      [ 1:0] cpu_prio,

    // Base Video
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,

    output            tile_irqn,
    output            tile_nmin,

    // CPU interface
    input      [16:1] cpu_addr,
    input      [ 1:0] cpu_dsn,
    input      [15:0] cpu_dout,
    output     [15:0] pal_dout,
    output     [ 7:0] tilesys_dout,
    output     [ 7:0] objsys_dout,
    output reg        odtac,
    output reg        vdtac,
    input             pcu_cs,
    input             pal_cs,
    input             cpu_we,
    input             tilesys_cs,
    input             objsys_cs,
    output            rst8,     // reset signal at 8th frame

    // control
    input             rmrd,     // Tile ROM read mode

    output            flip,

    // PROMs
    input      [ 8:0] prog_addr,
    input      [ 2:0] prog_data,
    input             prom_we,

    // Tile ROMs
    output reg [19:2] lyrf_addr,
    output reg [19:2] lyra_addr,
    output reg [19:2] lyrb_addr,
    output reg [20:2] lyro_addr,

    output            lyrf_cs,
    output            lyra_cs,
    output            lyrb_cs,
    output            lyro_cs,

    input             lyra_ok,
    input             lyro_ok,

    input      [31:0] lyrf_data,
    input      [31:0] lyra_data,
    input      [31:0] lyrb_data,
    input      [31:0] lyro_data,

    // Color
    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,

    // Debug
    input      [14:0] ioctl_addr,
    input             ioctl_ram,
    output reg [ 7:0] ioctl_din,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

`include "game_id.inc"

wire [ 8:0] hdump, vdump, vrender, vrender1;
wire [ 7:0] lyrf_pxl, st_scr, st_obj,
            dump_scr, dump_obj, dump_pal,
            lyrf_col, lyra_col, lyrb_col,
            opal,     cpu_d8,   mmr_pal,
            scr_mmr;
wire [15:0] cpu_saddr;
wire [11:0] lyra_pxl, lyrb_pxl, lyro_pxl;
wire [10:0] cpu_oaddr;
wire [12:0] pre_f, pre_a, pre_b, ocode;
reg  [13:0] ocode_eff;
reg  [ 7:0] opal_eff;
wire [18:0] ca;
wire        lyrf_blnk_n, lyra_blnk_n, lyrb_blnk_n, lyro_blnk_n,
            e, q, ormrd;
wire        obj_irqn, obj_nmin, shadow, prio_we, gfx_we;
reg         pre_odtac, pre_vdtac, sort_en, ioctl_mmr;
wire        cpu_weg;

assign cpu_saddr = { cpu_addr[16:15], cpu_dsn[1], cpu_addr[14:13], cpu_addr[11:1] };
assign cpu_oaddr = { cpu_addr[10: 1], cpu_dsn[1] };
assign gfx_we    = prom_we & ~prog_addr[8];
assign prio_we   = prom_we &  prog_addr[8];
assign cpu_weg   = cpu_we && cpu_dsn!=3;
assign cpu_d8    = ~cpu_dsn[1] ? cpu_dout[15:8] : cpu_dout[7:0];

// Debug
always @* begin
    st_dout = debug_bus[5] ? st_obj : st_scr;
    // VRAM dumps - 16+4+1 = 21kB +17 bytes = 22544 bytes
    ioctl_mmr = 0;
    if( ioctl_addr<'h4000 )
        ioctl_din = dump_scr;  // 16 kB 0000~3FFF
    else if( ioctl_addr<'h5000 )
        ioctl_din = dump_pal;  // 4kB 4000~4FFF
    else if( ioctl_addr<'h5800 )
        ioctl_din = dump_obj;  // 2kB 5000~5800 (second half equal for 051960)
    else if( ioctl_addr<'h5808 )
        ioctl_din = scr_mmr;  // 8 bytes, MMR 5807
    else if (ioctl_addr<'h5810) begin
        ioctl_mmr = 1;
        ioctl_din = dump_obj;  // 7 bytes, MMR 580F
    end else
        ioctl_din = { 6'd0, cpu_prio }; // 1 byte, 5810
end

wire [2:0] gfx_de;
reg  [9:1] oa; // see sch object page (A column)

always @(posedge clk) begin
    if( pxl2_cen ) begin
        if( q ) begin
            pre_odtac <= 0;
            pre_vdtac <= 0;
        end
        odtac <= pre_odtac;
        vdtac <= pre_vdtac;
    end
    if( !objsys_cs /* || (ormrd && !lyro_ok) */ ) { pre_odtac, odtac } <= 1;
    if( !tilesys_cs || (rmrd  && !lyra_ok) ) { pre_vdtac, vdtac } <= 1;
end

function [31:0] sort( input [31:0] x, input sort_en );
    sort= sort_en ? {
        x[31], x[27], x[23], x[19],
        x[15], x[11], x[ 7], x[ 3],
        x[30], x[26], x[22], x[18],
        x[14], x[10], x[ 6], x[ 2],
        x[29], x[25], x[21], x[17],
        x[13], x[ 9], x[ 5], x[ 1],
        x[28], x[24], x[20], x[16],
        x[12], x[ 8], x[ 4], x[ 0]
    } : x;
endfunction

function [31:0] sorto( input [31:0] x );
    sorto= {
        x[12], x[ 8], x[ 4], x[ 0],
        x[28], x[24], x[20], x[16],
        x[13], x[ 9], x[ 5], x[ 1],
        x[29], x[25], x[21], x[17],
        x[14], x[10], x[ 6], x[ 2],
        x[30], x[26], x[22], x[18],
        x[15], x[11], x[ 7], x[ 3],
        x[31], x[27], x[23], x[19] };
endfunction

wire [31:0] odata = sort_en ? sorto(
    { lyro_data[23:16],lyro_data[31:24], lyro_data[7:0], lyro_data[15:8] } ) :
      lyro_data;
// wire [3:0] opxls;

// jtframe_sort i_jtframe_sort (.debug_bus(debug_bus), .busin(lyro_pxl[3:0]), .busout(opxls));

// object encoding is different from what 051960 expects
jtframe_prom #(.DW(3), .AW(8)) u_gfx (
    .clk    ( clk        ),
    .cen    ( 1'b1       ),
    .data   ( prog_data  ),
    .rd_addr( ca[11+:8]  ),
    .wr_addr(prog_addr[7:0]),
    .we     ( gfx_we     ),
    .q      ( gfx_de     )
);

always @* begin
    // the game seems to use different encondigs depending on the ROM region
    case( gfx_de )
        7:   oa = { ca[8], ca[6], ca[4], ca[2:0], ca[9], ca[7], ca[5] }; // 9
        5,6: oa = { ca[9:8], ca[6], ca[4], ca[2:0], ca[7], ca[5] }; // 9
        4:   oa = { ca[9], ca[7], ca[8], ca[6], ca[4], ca[2:0], ca[5] }; // 9
        2,3: oa = { ca[9:6], ca[4], ca[2:0], ca[5] }; // 4+1+3+1=9
        1:   oa = { ca[9:7], ca[5], ca[6], ca[4], ca[2:0] }; // 3+3+3=9
        0:   oa = { ca[9:4], ca[2:0] }; // 6+3=9
    endcase
end

always @(posedge clk) begin
    sort_en <= game_id!=PUNKSHOT;
end

always @* begin
    case(game_id)
        MIA: begin
        lyrf_addr = { 6'd0,                              lyrf_col[0], pre_f[10:0] };
        lyra_addr = { 2'd0, pre_a[12:11], lyra_col[4:3], lyra_col[0], pre_a[10:0] };
        lyrb_addr = { 2'd0, pre_b[12:11], lyrb_col[4:3], lyrb_col[0], pre_b[10:0] };
        opal_eff  = opal;
        ocode_eff = { 1'b0, ocode };
        lyro_addr = { ca[18:8],  &ca[17:14] ? {ca[7:6],ca[4],ca[2],ca[1:0] } :
                                              {ca[6],  ca[4],ca[2:0],ca[7] },ca[5],ca[3] };
        end

        PUNKSHOT: begin
        lyrf_addr = { pre_f[12:11], lyrf_col[3:2], lyrf_col[4], lyrf_col[1:0], pre_f[10:0] };
        lyra_addr = { pre_a[12:11], lyra_col[3:2], lyra_col[4], lyra_col[1:0], pre_a[10:0] };
        lyrb_addr = { pre_b[12:11], lyrb_col[3:2], lyrb_col[4], lyrb_col[1:0], pre_b[10:0] };
        opal_eff  = { opal[7:5], 1'b0, opal[3:0] };
        ocode_eff = { opal[4], ocode };
        lyro_addr = ca;
        end

        default: begin // TMNT
        lyrf_addr = { pre_f[12:11], lyrf_col[3:2], lyrf_col[4], lyrf_col[1:0], pre_f[10:0] };
        lyra_addr = { pre_a[12:11], lyra_col[3:2], lyra_col[4], lyra_col[1:0], pre_a[10:0] };
        lyrb_addr = { pre_b[12:11], lyrb_col[3:2], lyrb_col[4], lyrb_col[1:0], pre_b[10:0] };
        opal_eff  = { opal[7:5], 1'b0, opal[3:0] };
        ocode_eff = { opal[4], ocode };
        lyro_addr = { ca[18:10], oa, ca[3] };
        end
    endcase
end

function [7:0] cgate( input [7:0] c);
    case(game_id)
        MIA:     cgate = { c[7:4], 3'd0, c[2] };
        default: cgate = { c[7:5], 5'd0 }; // TMNT, PUNKSHOT
    endcase
endfunction

/* verilator tracing_on */
// extra blanking added to help MiSTer output
// on real hardware, it would've been manually
// adjusted on the CRT.
// This is needed to prevent sprites over the left border
// and it also prevents a bad column of background at
// the end of stage 2
// It also makes the grid look squared, wihtout nothing hanging off the sides
jtaliens_scroll #(
    .HB_EXTRAL( 9'd8 ),
    .HB_EXTRAR( 9'd8 )
) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    // Base Video
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        ),

    // CPU interface
    .cpu_addr   ( cpu_saddr ),
    .cpu_dout   ( cpu_d8    ),
    .cpu_we     ( cpu_weg   ),
    .gfx_cs     ( tilesys_cs),
    .rst8       ( rst8      ),
    .tile_dout  ( tilesys_dout ),

    // control
    .rmrd       ( rmrd      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),

    .irq_n      ( tile_irqn ),
    .firq_n     (           ),
    .nmi_n      ( tile_nmin ),
    .flip       ( flip      ),
    .q          ( q         ),
    .e          ( e         ),

    // color byte connection
    .lyrf_col   ( lyrf_col  ),
    .lyra_col   ( lyra_col  ),
    .lyrb_col   ( lyrb_col  ),

    .lyrf_cg    (cgate(lyrf_col)),
    .lyra_cg    (cgate(lyra_col)),
    .lyrb_cg    (cgate(lyrb_col)),

    // Tile ROMs
    .lyrf_addr  ( pre_f     ),
    .lyra_addr  ( pre_a     ),
    .lyrb_addr  ( pre_b     ),

    .lyrf_cs    ( lyrf_cs   ),
    .lyra_cs    ( lyra_cs   ),
    .lyrb_cs    ( lyrb_cs   ),

    .lyrf_data  ( sort(lyrf_data, sort_en) ),
    .lyra_data  ( sort(lyra_data, sort_en) ),
    .lyrb_data  ( sort(lyrb_data, sort_en) ),

    // Final pixels
    .lyrf_blnk_n(lyrf_blnk_n),
    .lyra_blnk_n(lyra_blnk_n),
    .lyrb_blnk_n(lyrb_blnk_n),
    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  ),

    // Debug
    .ioctl_addr ( ioctl_addr[14:0]),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( dump_scr  ),
    .mmr_dump   ( scr_mmr   ),

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_scr    )
);

/* verilator tracing_on */
jtaliens_obj u_obj(    // sprite logic
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    // Base Video (inputs)
    .hs         ( hs        ),
    .vs         ( vs        ),
    .lvbl       ( lvbl      ),
    .lhbl       ( lhbl      ),
    .hdump      ( hdump     ),
    .vdump      ( vrender   ),
    // CPU interface
    .cs         ( objsys_cs ),
    .cpu_addr   ( cpu_oaddr ),
    .cpu_dout   ( cpu_d8    ),
    .cpu_we     ( cpu_weg   ),
    .cpu_din    ( objsys_dout),

    .irq_n      ( obj_irqn  ),
    .nmi_n      ( obj_nmin  ),
    // external connection
    .code       ( ocode     ),
    .code_eff   ( ocode_eff ),
    .pal        ( opal      ),
    .pal_eff    ( opal_eff  ),
    // ROM
    .rom_addr   ( ca        ),
    .rom_data   ( odata     ),
    .rom_ok     ( lyro_ok   ),
    .rom_cs     ( lyro_cs   ),
    .romrd      ( ormrd     ),
    // pixel output
    .pxl        ( { lyro_pxl[11:4], lyro_pxl[0], lyro_pxl[1], lyro_pxl[2], lyro_pxl[3] } ),
    .blank_n    (lyro_blnk_n),
    .shadow     ( shadow    ),

    // Debug
    .ioctl_addr ( ioctl_addr[10:0]),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_mmr  ( ioctl_mmr ),
    .ioctl_din  ( dump_obj  ),

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_obj    )
);

/* verilator tracing_on */
jttmnt_colmix #(.IOCTL_A0(1)) u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .game_id    ( game_id   ),
    .cpu_prio   ( cpu_prio  ),

    // Base Video
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),

    // CPU interface
    .cpu_addr   (cpu_addr[12:1]),
    .cpu_we     ( cpu_weg   ),
    .cpu_din    ( pal_dout  ),
    .cpu_d8     ( cpu_d8    ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_dsn    ( cpu_dsn   ),
    .pal_cs     ( pal_cs    ),
    .pcu_cs     ( pcu_cs    ),

    // PROMs
    .prog_addr  (prog_addr[7:0]),
    .prog_data  ( prog_data ),
    .prom_we    ( prio_we   ),

    // Final pixels
    .lyrf_blnk_n(lyrf_blnk_n),
    .lyra_blnk_n(lyra_blnk_n),
    .lyrb_blnk_n(lyrb_blnk_n),
    .lyro_blnk_n(lyro_blnk_n),
    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  ),
    .lyro_pxl   ( lyro_pxl  ),
    .shadow     ( shadow    ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    // Debug
    .ioctl_addr ( ioctl_addr[11:0]),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( dump_pal  ),
    .dump_mmr   ( mmr_pal   ),

    .debug_bus  ( debug_bus )
);

endmodule