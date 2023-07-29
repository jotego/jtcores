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
    Date: 23-7-2023 */

module jtsimson_video(
    input             rst,
    output            rst8,     // reset signal at 8th frame
    input             clk,

    // Base Video
    input             pxl_cen,
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,
    output            flip,

    // CPU interface
    input      [15:0] cpu_addr,
    input      [ 7:0] cpu_dout,
    input             cpu_we,

    output     [ 7:0] pal_dout,
    output     [ 7:0] tilesys_dout,
    output     [ 7:0] objsys_dout,

    input             pal_we,
    input             pcu_cs,   // priority control unit
    input             tilesys_cs,
    input             objsys_cs,
    input             objreg_cs,

    // control
    input             rmrd,     // Tile ROM read mode
    input             objcha_n, // object ROM read mode
    output            cpu_irqn,
    output            cpu_firqn,

    // Tile ROMs
    output     [19:2] lyrf_addr,
    output     [19:2] lyra_addr,
    output     [19:2] lyrb_addr,
    output     [21:2] lyro_addr,

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
            dump_scr, dump_obj, dump_pal;
wire [11:0] lyra_pxl, lyrb_pxl;
wire [ 8:0] lyro_pxl;
wire [ 1:0] obj_shd;
wire [ 4:0] obj_prio;
wire [15:0] obj16_dout;

assign objsys_dout = cpu_addr[0] ? obj16_dout[15:8] : obj16_dout[7:0];
assign ioctl_din   = 0;

// Debug
always @(posedge clk) begin
    st_dout <= debug_bus[5] ? st_obj : st_scr;
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
end

/* verilator tracing_on */
jtsimson_scroll u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

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

    .irq_n      ( cpu_irqn  ),
    .firq_n     (           ),
    .nmi_n      (           ),
    .flip       ( flip      ),


    // Tile ROMs
    .lyrf_addr  ( lyrf_addr ),
    .lyra_addr  ( lyra_addr ),
    .lyrb_addr  ( lyrb_addr ),

    .lyrf_cs    ( lyrf_cs   ),
    .lyra_cs    ( lyra_cs   ),
    .lyrb_cs    ( lyrb_cs   ),

    .lyrf_data  ( lyrf_data ),
    .lyra_data  ( lyra_data ),
    .lyrb_data  ( lyrb_data ),

    // Final pixels
    .lyrf_blnk_n(           ),
    .lyra_blnk_n(           ),
    .lyrb_blnk_n(           ),
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

/* verilator tracing_on  */
jtsimson_obj u_obj(    // sprite logic
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    // Base Video (inputs)
    .hs         ( hs        ),
    .vs         ( vs        ),
    .lvbl       ( lvbl      ),
    .lhbl       ( lhbl      ),
    // .hdump      ( hdump     ),
    // .vdump      ( vrender   ),
    // CPU interface
    .ram_cs     ( objsys_cs ),
    .reg_cs     ( objreg_cs ),
    .cpu_addr   (cpu_addr[13:1]),
    .cpu_dout   ({2{cpu_dout}}),
    .cpu_dsn    ({~cpu_addr[0],cpu_addr[0]}),
    .cpu_we     ( cpu_we    ),
    .cpu_din    ( obj16_dout),

    .irqn       ( cpu_firqn ),
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
    // .ioctl_addr ( ioctl_addr[10:0]),
    // .ioctl_ram  ( ioctl_ram ),
    // .ioctl_din  ( dump_obj  ),

    // .gfx_en     ( gfx_en    ),
    // .debug_bus  ( debug_bus ),
    .st_dout    ( st_obj    )
);

/* verilator tracing_on */
jtsimson_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),

    // Base Video
    .pxl_cen    ( pxl_cen   ),
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),

    // CPU interface
    .cpu_addr   (cpu_addr[11:0]),
    .cpu_din    ( pal_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( pal_we    ),
    .pcu_cs     ( pcu_cs    ),

    // Final pixels
    .lyrf_pxl   ( { 1'b0, lyrf_pxl[7:6], lyrf_pxl[3:0] } ),
    .lyra_pxl   ( { 1'b0, lyra_pxl[7:6], lyra_pxl[3:0] } ),
    .lyrb_pxl   ( { 1'b0, lyrb_pxl[7:6], lyrb_pxl[3:0] } ),
    .lyro_pxl   ( lyro_pxl  ),

    .obj_prio   ( obj_prio  ),
    .obj_shd    ( obj_shd   ),

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