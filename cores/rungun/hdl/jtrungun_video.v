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
    Date: 4-7-2025 */

module jtrungun_video(
    input              rst, clk,
    input              pxl_cen,
                       ghflip, gvflip, pri,
    input              lrsw,
    output             disp,
    // Base Video
    output             lhbl,
    output             lvbl,
    output             hs,
    output             vs,
    // CPU interface
    input              ccu_cs,   // timer
    input       [ 3:0] addr,
    input              rnw,
    input       [15:0] cpu_dout,
    output      [ 7:0] vtimer_mmr,
    // fixed layer
    output      [12:1] vram_addr,
    input       [15:0] vram_dout,
    // PSAC (scroll)
    output      [20:2] scr_addr,
    input       [31:0] scr_data,
    output             scr_cs,
    input              scr_ok,
    // Objects
    output      [22:2] obj_addr,
    input       [31:0] obj_data,
    output             obj_cs,
    input              obj_ok,
    // palette
    output      [11:1] pal_addr,
    input       [15:0] pal_dout,

    output      [16:2] fix_addr,
    input       [31:0] fix_data,
    output             fix_cs,
    input              fix_ok,
    // final pixel
    output      [ 7:0] red,
    output      [ 7:0] green,
    output      [ 7:0] blue,
    // Debug
    input       [ 7:0] debug_bus,
    // IOCTL dump
    input      [3:0] ioctl_addr,
    output     [7:0] ioctl_din
);

wire [11:0] fix_code;
wire [ 8:0] hdump, hdumpf;
wire [ 7:0] vdump, vdumpf;
wire [ 7:0] fix_pxl;
wire [ 3:0] fix_pal;

assign scr_addr=0, scr_cs=0, obj_addr=0, obj_cs=0;

assign vram_addr[12] = lrsw;
assign fix_pal  = vram_dout[15:12];
assign fix_code = vram_dout[11: 0];

jtrungun_vtimer u_vtimer(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .vs         ( vs            ),

    .hflip      ( ghflip        ),
    .vflip      ( gvflip        ),
    .hdump      ( hdump         ),
    .hdumpf     ( hdumpf        ),
    .vdump      ( vdump         ),
    .vdumpf     ( vdumpf        )
);

jtk053252 u_k053252(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),


    .cs         ( ccu_cs        ),
    .addr       ( addr          ),
    .rnw        ( rnw           ),
    .din        ( cpu_dout[7:0] ),
    .dout       ( vtimer_mmr    ),

    .hs         ( hs            ),
    .vs         ( vs            ),
    .lhbl       ( lhbl          ),
    .lvbl       ( lvbl          ),
    // IOCTL dump
    .ioctl_addr ( ioctl_addr    ),
    .ioctl_din  ( ioctl_din     )
);

jtframe_toggle #(.W(1)) u_disp(rst,clk,vs,disp);

jtframe_tilemap #(
    .VA(11),
    .MAP_HW(9),
    .VDUMPW(8),
    .FLIP_HDUMP(0),
    .FLIP_VDUMP(0)
)u_fix(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .vdump      ( vdumpf        ),
    .hdump      ( hdumpf        ),
    .blankn     ( 1'b1          ),
    .flip       ( 1'b0          ),    // Screen flip

    .vram_addr  (vram_addr[11:1]),

    .code       ( fix_code      ),
    .pal        ( fix_pal       ),
    .hflip      ( 1'b0          ),
    .vflip      ( 1'b0          ),

    .rom_addr   ( fix_addr      ),
    .rom_data   ( fix_data      ),    // expects data packed as plane3,plane2,plane1,plane0, each of 8 bits
    .rom_cs     ( fix_cs        ),
    .rom_ok     ( fix_ok        ), // zeros used if rom_ok is not high in time

    .pxl        ( fix_pxl       )
);

jtrungun_colmix u_colmix(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .lrsw       ( lrsw          ),

    // Base Video
    .lhbl       ( lhbl          ),
    .lvbl       ( lvbl          ),

    .pal_addr   ( pal_addr      ),
    .pal_dout   ( pal_dout      ),
    // Final pixels
    .fix_pxl    ( fix_pxl       ),

    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),

    // Debug
    // input      [11:0] ioctl_addr,
    // input             ioctl_ram,
    // output     [ 7:0] ioctl_din,
    // output     [ 7:0] dump_mmr,

    .debug_bus  ( debug_bus     )
);

endmodule
