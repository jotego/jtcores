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
    Date: 7-7-2024 */

module jtssriders_video(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             pxl2_cen,

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
    input             cpu_we,

    input             pcu_cs,
    input             pal_cs,
    output     [15:0] pal_dout,
    output     [ 7:0] tilesys_dout,

    output            dma_bsy,
    output     [ 7:0] objsys_dout,
    input             objsys_cs,
    input             objreg_cs,

    output reg        vdtac,
    input             tilesys_cs,
    output            rst8,     // reset signal at 8th frame

    // control
    input             rmrd,     // Tile ROM read mode
    input             objcha_n, // object ROM read mode
    output            flip,

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
    input      [ 2:0] dim,
    input             dimmod,
    input             dimpol,

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

wire [18:0] ca;
wire [15:0] cpu_saddr;
reg  [13:0] ocode_eff;
wire [12:0] pre_f, pre_a, pre_b, ocode;
wire [11:0] lyra_pxl, lyrb_pxl, lyro_pxl, lyro_sort;
wire [10:0] cpu_oaddr;
wire [ 8:0] hdump, vdump, vrender, vrender1;
wire [ 7:0] lyrf_pxl, st_scr, st_obj,
            dump_scr, dump_obj, dump_pal,
            lyrf_col, lyra_col, lyrb_col,
            opal,     cpu_d8,   mmr_pal,
            scr_mmr;
reg  [ 7:0] opal_eff;
wire        lyrf_blnk_n, lyra_blnk_n, lyrb_blnk_n, lyro_blnk_n, ormrd;
wire        obj_irqn, obj_nmin, shadow, prio_we, gfx_we, pre_vdtac;
reg         ioctl_mmr;
wire        cpu_weg;

assign cpu_saddr = { cpu_addr[16:15], cpu_dsn[1], cpu_addr[13:12], cpu_addr[11:1] };
assign cpu_oaddr = { cpu_addr[10: 1], cpu_dsn[1] };
assign gfx_we    = prom_we & ~prog_addr[8];
assign prio_we   = prom_we &  prog_addr[8];
assign cpu_weg   = cpu_we &&  cpu_dsn!=3;
assign cpu_d8    = ~cpu_dsn[1] ? cpu_dout[15:8] : cpu_dout[7:0];
assign lyro_sort = { lyro_pxl[11:4],
    sort_en ? lyro_pxl[3:0] : {lyro_pxl[0],lyro_pxl[1],lyro_pxl[2],lyro_pxl[3]} };

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

always @(posedge clk) vdtac <= pre_vdtac; // delay, since cpu_din also delayed

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

always @* begin
    lyrf_addr = { pre_f[12:11], lyrf_col[3:2], lyrf_col[4], lyrf_col[1:0], pre_f[10:0] };
    lyra_addr = { pre_a[12:11], lyra_col[3:2], lyra_col[4], lyra_col[1:0], pre_a[10:0] };
    lyrb_addr = { pre_b[12:11], lyrb_col[3:2], lyrb_col[4], lyrb_col[1:0], pre_b[10:0] };

    case(game_id)
        MIA: begin
        opal_eff  = opal;
        ocode_eff = { 1'b0, ocode };
        lyro_addr = { ca[18:8],  &ca[17:14] ? {ca[7:6],ca[4],ca[2],ca[1:0] } :
                                              {ca[6],  ca[4],ca[2:0],ca[7] },ca[5],ca[3] };
        end

        PUNKSHOT: begin
        opal_eff  = { opal[7:5], 1'b0, opal[3:0] };
        ocode_eff = { opal[4], ocode };
        lyro_addr = ca;
        end

        default: begin // TMNT
        opal_eff  = { opal[7:5], 1'b0, opal[3:0] };
        ocode_eff = { opal[4], ocode };
        lyro_addr = { ca[18:10], oa, ca[3] };
        end
    endcase
end

function [7:0] cgate( input [7:0] c);
    cgate = { c[7:5], 5'd0 };
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
    .cpu_rom_dtack( pre_vdtac ),
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
    .q          (           ),
    .e          (           ),

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

    .lyrf_data  ( lyrf_data ),
    .lyra_data  ( lyra_data ),
    .lyrb_data  ( lyrb_data ),

    .lyra_ok    ( lyra_ok ),

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

localparam ORAMW=14;
wire [ORAMW-1:1] oram_a;
wire [15:0] obj16_dout;

assign oram_a={cpu_addr[13:8],cpu_addr[6:5],cpu_addr[4:1]};
assign objsys_dout = ~cpu_dsn[0] ? obj16_dout[15:8] : obj16_dout[7:0]; // big endian

/* verilator tracing_on */
jtsimson_obj #(.RAMW(ORAMW)) u_obj(    // sprite logic
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    .paroda     ( 1'b1      ),
    .simson     ( 1'b0      ),
    // Base Video (inputs)
    .hs         ( hs        ),
    .vs         ( vs        ),
    .lvbl       ( lvbl      ),
    .lhbl       ( lhbl      ),
    .hdump      ( hdump     ),
    .vdump      ( vrender   ),
    // CPU interface
    .ram_cs     ( objsys_cs ),
    .reg_cs     ( objreg_cs ),
    .ram_a      ( oram_a    ),
    .cpu_addr   ( cpu_addr[4:2] ),
    .cpu_dout   ({2{cpu_dout}}),
    .cpu_dsn    ( cpu_dsn   ),
    .cpu_we     ( cpu_we    ),
    .cpu_din    ( obj16_dout),

    .dma_bsy    ( dma_bsy   ),
    // ROM
    .rom_addr   ( lyro_addr ),
    .rom_data   ( lyro_data ),
    .rom_ok     ( lyro_ok   ),
    .rom_cs     ( lyro_cs   ),
    .objcha_n   ( objcha_n  ),
    // pixel output
    .pxl        ( lyro_pxl  ),
    .shd        ( obj_shd   ),
    .prio       ( obj_prio  ),
    // Debug
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_addr ( ioctl_addr[13:0]-14'h1000 ),
    .dump_ram   ( dump_obj  ),
    .dump_reg   ( obj_mmr   ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);

/* verilator tracing_on */
jtssriders_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

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

    // Final pixels
    .lyrf_blnk_n(lyrf_blnk_n),
    .lyra_blnk_n(lyra_blnk_n),
    .lyrb_blnk_n(lyrb_blnk_n),
    .lyro_blnk_n(lyro_blnk_n),
    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  ),
    .lyro_pxl   ( lyro_sort ),

    // shadow
    .dimmod     ( dimmod    ),
    .dimpol     ( dimpol    ),
    .dim        ( dim       ),
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