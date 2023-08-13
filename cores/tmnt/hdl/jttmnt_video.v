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
    // input      [ 1:0] cfg,
    input      [ 1:0] cpu_prio,

    // Base Video
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,

    // CPU interface
    input      [16:1] cpu_addr,
    input      [ 1:0] cpu_dsn,
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

    output            flip,

    // PROMs
    input      [ 7:0] prog_addr,
    input      [ 2:0] prog_data,
    input             prom_we,

    // Tile ROMs
    output reg [19:2] lyrf_addr,
    output reg [19:2] lyra_addr,
    output reg [19:2] lyrb_addr,
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
    output     [ 7:0] ioctl_din,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

wire [ 8:0] hdump, vdump, vrender, vrender1;
wire [ 7:0] lyrf_pxl, st_scr, st_obj,
            dump_scr, dump_obj, dump_pal,
            lyrf_col, lyra_col, lyrb_col,
            opal, opal_eff;
wire [15:0] cpu_saddr;
wire [11:0] lyra_pxl, lyrb_pxl;
wire [11:0] lyro_pxl;
wire [10:0] cpu_oaddr;
wire [12:0] pre_f, pre_a, pre_b, ocode;
wire [13:0] ocode_eff;
wire        lyrf_blnk_n, lyra_blnk_n, lyrb_blnk_n, lyro_blnk_n;
wire        tile_irqn, obj_irqn, tile_nmin, obj_nmin, shadow;

assign cpu_saddr = { cpu_addr[16:15], cpu_dsn[1], cpu_addr[14:13], cpu_addr[11:1] };
assign cpu_oaddr = { cpu_addr[10: 1], cpu_dsn[1] };
assign ioctl_din = 0;
// Debug
always @(posedge clk) begin
    st_dout <= debug_bus[5] ? st_obj : st_scr;
    // remember to drive ioctl_ram from game module:
    // VRAM dumps - 16+2+3 = 19kB +16 bytes = 19472 bytes
    // if( !ioctl_addr[14] )
    //     ioctl_din <= dump_scr;  // 16 kB 0000~3FFF
    // else if( !ioctl_addr[11] )
    //     ioctl_din <= dump_pal;  // 2kB 4000~47FF
    // else if( !ioctl_addr[10] )
    //     ioctl_din <= dump_obj;  // 1kB 4800~4C00
    // else if( !ioctl_addr[3] )
    //     ioctl_din <= dump_scr;  // 8 bytes, MMR 4C07
    // else if (ioctl_addr[2:0]!=7)
    //     ioctl_din <= dump_obj;  // 7 bytes, MMR 4C0E
    // else
    //     ioctl_din <= { 6'd0, cpu_prio }; // 1 byte, 4C0F
end

always @* begin
    lyrf_addr = { pre_f[12:11], lyrf_col[3:2], lyrf_col[4], lyrf_col[1:0], pre_f[10:0] };
    lyra_addr = { pre_a[12:11], lyra_col[3:2], lyra_col[4], lyra_col[1:0], pre_a[10:0] };
    lyrb_addr = { pre_b[12:11], lyrb_col[3:2], lyrb_col[4], lyrb_col[1:0], pre_b[10:0] };
end

function [7:0] cgate( input [7:0] c);
    cgate = { c[7:5], 5'd0 };
endfunction

assign opal_eff  = { opal[7:5], 1'b0, opal[3:0] };
assign ocode_eff = { opal[4], ocode };

/* verilator tracing_on */
jtaliens_scroll u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    // Base Video
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        ),

    // CPU interface
    .cpu_addr   ( cpu_saddr ),
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
    .cpu_addr   ( cpu_oaddr ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( cpu_we    ),
    .cpu_din    ( objsys_dout),

    .irq_n      ( obj_irqn  ),
    .nmi_n      ( obj_nmin  ),
    // external connection
    .code       ( ocode     ),
    .code_eff   ( ocode_eff ),
    .pal        ( opal      ),
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

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_obj    )
);

/* verilator tracing_off */
jttmnt_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    // .cfg        ( cfg       ),
    .cpu_prio   ( cpu_prio  ),

    // Base Video
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),

    // CPU interface
    .cpu_addr   (cpu_addr[12:1]),
    .cpu_din    ( pal_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( pal_we    ),

    // PROMs
    .prog_addr  ( prog_addr ),
    .prog_data  ( prog_data ),
    .prom_we    ( prom_we   ),

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

    .debug_bus  ( debug_bus )
);

endmodule