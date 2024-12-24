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
    Date: 15-4-2023 */

module jtaliens_video(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             pxl2_cen,
    input             gx878,
    input      [ 1:0] cfg,
    input      [ 1:0] cpu_prio,

    // Base Video
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,

    // CPU interface
    input      [15:0] cpu_addr,
    input      [ 7:0] cpu_dout,
    output     [ 7:0] pal_dout,
    output     [ 7:0] tilesys_dout,
    output     [ 7:0] objsys_dout,
    input             pal_we,
    input             cpu_we,
    input             tilesys_cs,
    input             objsys_cs,
    output            rst8,     // reset signal at 8th frame

    // control
    input             rmrd,     // Tile ROM read mode

    output            cpu_irq_n,
    output            cpu_nmi_n,
    output            flip,

    // PROMs
    input      [ 7:0] prog_addr,
    input      [ 2:0] prog_data,
    input             prom_we,

    // Tile ROMs
    output reg [20:2] lyrf_addr,
    output reg [20:2] lyra_addr,
    output reg [20:2] lyrb_addr,
    output     [20:2] lyro_addr,

    output            lyrf_cs,
    output            lyra_cs,
    output            lyrb_cs,
    output            lyro_cs,

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

`include "jtaliens.inc"

wire [ 8:0] hdump, vdump, vrender, vrender1;
wire [ 7:0] lyrf_pxl, st_scr, st_obj,
            dump_scr, dump_obj, dump_pal,
            lyrf_col, lyra_col, lyrb_col,
            opal, opal_eff;
wire [11:0] lyra_pxl, lyrb_pxl;
wire [11:0] lyro_pxl;
wire [12:0] pre_f, pre_a, pre_b, ocode;
wire [13:0] ocode_eff;
wire        lyrf_blnk_n, lyra_blnk_n, lyrb_blnk_n, lyro_blnk_n,
            e, q;
wire        prio_we, tile_irqn, obj_irqn, tile_nmin, obj_nmin, shadow;

assign prio_we = prom_we & (cfg==SCONTRA | ~prog_addr[7]);
// Aliens programs the interrupts on the sprite chip, but
// the other games use the tilemapper chip instead
assign cpu_irq_n = cfg==ALIENS || cfg==CRIMFGHT ? obj_irqn : tile_irqn;
assign cpu_nmi_n = cfg==ALIENS   ? obj_nmin :
                   cfg==CRIMFGHT ? 1'b1 : tile_nmin;

assign opal_eff  = cfg==SCONTRA || cfg==CRIMFGHT ? opal : { 1'b0, opal[6:0] };
assign ocode_eff = cfg==SCONTRA || cfg==CRIMFGHT ? { 1'b0, ocode } : { opal[7], ocode };


// Debug
always @(posedge clk) begin
    st_dout <= debug_bus[5] ? st_obj : st_scr;
    // VRAM dumps - 16+2+3 = 19kB +16 bytes = 19472 bytes
    if( !ioctl_addr[14] )
        ioctl_din <= dump_scr;  // 16 kB 0000~3FFF
    else if( !ioctl_addr[11] )
        ioctl_din <= dump_pal;  // 2kB 4000~47FF
    else if( !ioctl_addr[10] )
        ioctl_din <= dump_obj;  // 1kB 4800~4C00
    else if( !ioctl_addr[3] )
        ioctl_din <= dump_scr;  // 8 bytes, MMR 4C07
    else if (ioctl_addr[2:0]!=7)
        ioctl_din <= dump_obj;  // 7 bytes, MMR 4C0E
    else
        ioctl_din <= { 6'd0, cpu_prio }; // 1 byte, 4C0F
end

always @* begin
    case( cfg )
        THUNDERX: begin
            if( gx878 ) begin // GX878 = Gang Busters
                lyrf_addr = { 2'b0, pre_f[12:11], lyrf_col[3], lyrf_col[2], lyrf_col[4], lyrf_col[0], pre_f[10:0] };
                lyra_addr = { 2'b0, pre_a[12:11], lyra_col[3], lyra_col[2], lyra_col[4], lyra_col[0], pre_a[10:0] };
                lyrb_addr = { 2'b0, pre_b[12:11], lyrb_col[3], lyrb_col[2], lyrb_col[4], lyrb_col[0], pre_b[10:0] };
            end else begin // GX873 = Thunder Force
                lyrf_addr = { 2'b0, pre_f[11], lyrf_col[4:0], pre_f[10:0] };
                lyra_addr = { 2'b0, pre_a[11], lyra_col[4:0], pre_a[10:0] };
                lyrb_addr = { 2'b0, pre_b[11], lyrb_col[4:0], pre_b[10:0] };
            end
        end
        CRIMFGHT: begin
            lyrf_addr = { 2'b0, pre_f[11], lyrf_col[4:0], pre_f[10:0] };
            lyra_addr = { 2'b0, pre_a[11], lyra_col[4:0], pre_a[10:0] };
            lyrb_addr = { 2'b0, pre_b[11], lyrb_col[4:0], pre_b[10:0] };
        end
        SCONTRA: begin
            lyrf_addr = { 1'b0, pre_f[12:11], lyrf_col[4:0], pre_f[10:0] };
            lyra_addr = { 1'b0, pre_a[12:11], lyra_col[4:0], pre_a[10:0] };
            lyrb_addr = { 1'b0, pre_b[12:11], lyrb_col[4:0], pre_b[10:0] };
        end
        default: begin
            lyrf_addr = { pre_f[12:11], lyrf_col[5:0], pre_f[10:0] };
            lyra_addr = { pre_a[12:11], lyra_col[5:0], pre_a[10:0] };
            lyrb_addr = { pre_b[12:11], lyrb_col[5:0], pre_b[10:0] };
        end
    endcase
end

function [7:0] cgate( input [7:0] c);
    cgate = cfg==SCONTRA  || cfg==THUNDERX ? { c[7:5], 5'd0       } :
            cfg==CRIMFGHT ? { c[7:6], 5'd0, c[5] } :
                            { c[7:6], 6'd0       };
endfunction

/* verilator tracing_on */
jtaliens_scroll u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    // unused
    .q          (           ),
    .e          (           ),
    .mmr_dump   (           ),

    // Base Video
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        ),

    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( cpu_we    ),
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

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_scr    )
);

/* verilator tracing_off */
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
    .cpu_addr   (cpu_addr[10:0]),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( cpu_we    ),
    .cpu_din    ( objsys_dout),

    .irq_n      ( obj_irqn  ),
    .nmi_n      ( obj_nmin  ),
    .romrd      (           ),
    // external connection
    .pal        ( opal      ),
    .code       ( ocode     ),
    .code_eff   ( ocode_eff ),
    .pal_eff    ( opal_eff  ),
    // ROM
    .rom_addr   ( lyro_addr ),
    .rom_data   ( lyro_data ),
    .rom_ok     ( lyro_ok   ),
    .rom_cs     ( lyro_cs   ),
    // pixel output
    .pxl        ( lyro_pxl  ),
    .blank_n    (lyro_blnk_n),
    .shadow     ( shadow    ),

    // Debug
    .ioctl_addr ( ioctl_addr[10:0]),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( dump_obj  ),
    .ioctl_mmr  ( 1'b0      ),

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_obj    )
);

/* verilator tracing_on */
jtaliens_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .cfg        ( cfg       ),
    .cpu_prio   ( cpu_prio  ),

    // Base Video
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),

    // CPU interface
    .cpu_addr   (cpu_addr[10:0]),
    .cpu_din    ( pal_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( pal_we    ),

    // PROMs
    .prog_addr  ( prog_addr ),
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
    .ioctl_addr ( ioctl_addr[10:0]),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( dump_pal  ),

    .debug_bus  ( debug_bus )
);

endmodule