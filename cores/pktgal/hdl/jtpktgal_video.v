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
    Date: 12-7-2026 */

module jtpktgal_video(
    input             rst,
    input             clk,
    input             pxl_cen,

    output     [10:1] pf_addr,
    input      [15:0] pf_data,
    output     [ 8:0] objram_addr,
    input      [ 7:0] objram_data,

    input      [ 4:0] bac06_addr,
    input      [ 7:0] bac06_din,
    output     [ 7:0] bac06_dout,
    input             bac06_cs,
    input             bac06_rnw,
    input      [ 4:0] ioctl_addr,
    output     [ 7:0] ioctl_din,
    input      [ 7:0] debug_bus,
    input             char_orig,
    input             char_bootleg,

    output     [16:2] char_addr,
    input      [31:0] char_data,
    input             char_ok,
    output            char_cs,

    output     [15:0] obj_addr,
    input      [ 7:0] obj_data,
    input             obj_ok,
    output            obj_cs,

    output     [ 8:0] promrg_addr,
    input      [ 7:0] promrg_data,
    output     [ 8:0] promb_addr,
    input      [ 7:0] promb_data,

    output            HS,
    output            VS,
    output            LHBL,
    output            LVBL,
    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,
    input      [ 3:0] gfx_en
);

wire [8:0] hdump, vdump, vrender;
wire [ 7:0] pf_pxl;
wire [ 4:0] obj_pxl;
wire        flip;

jtframe_vtimer #(
    .HB_END   ( 9'd0   ),
    .HB_START ( 9'd256 ),
    .HCNT_END ( 9'd383 ),
    .HS_START ( 9'd280 ),
    .HS_END   ( 9'd312 ),
    .VB_END   ( 9'd15  ),
    .VB_START ( 9'd239 ),
    .VCNT_END ( 9'd259 ),
    .VS_START ( 9'd248 ),
    .VS_END   ( 9'd251 )
) u_vtimer(
    .clk      ( clk     ),
    .pxl_cen  ( pxl_cen ),
    .vdump    ( vdump   ),
    .vrender  ( vrender ),
    .vrender1 (         ),
    .H        ( hdump   ),
    .Hinit    (         ),
    .Vinit    (         ),
    .LHBL     ( LHBL    ),
    .LVBL     ( LVBL    ),
    .HS       ( HS      ),
    .VS       ( VS      )
);

jtpktgal_bac06 u_bac06(
    .rst          ( rst          ),
    .clk          ( clk          ),
    .pxl_cen      ( pxl_cen      ),
    .HS           ( HS           ),
    .LVBL         ( LVBL         ),
    .hdump        ( hdump        ),
    .vdump        ( vdump        ),
    .vram_addr    ( pf_addr      ),
    .vram_dout    ( pf_data      ),
    .mmr_addr     ( bac06_addr   ),
    .mmr_din      ( bac06_din    ),
    .mmr_dout     ( bac06_dout   ),
    .mmr_cs       ( bac06_cs     ),
    .mmr_rnw      ( bac06_rnw    ),
    .ioctl_addr   ( ioctl_addr   ),
    .ioctl_din    ( ioctl_din    ),
    .debug_bus    ( debug_bus    ),
    .flip         ( flip         ),
    .char_orig    ( char_orig    ),
    .char_bootleg ( char_bootleg ),
    .rom_addr     ( char_addr    ),
    .rom_data     ( char_data    ),
    .rom_ok       ( char_ok      ),
    .rom_cs       ( char_cs      ),
    .pxl          ( pf_pxl       )
);

jtpktgal_obj u_obj(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .pxl_cen    ( pxl_cen      ),
    .bootleg    ( char_bootleg ),
    .flip       ( flip         ),
    .hdump      ( hdump        ),
    .vrender    ( vrender      ),
    .LHBL       ( LHBL         ),
    .obj_vaddr  ( objram_addr  ),
    .obj_vdata  ( objram_data  ),
    .rom_addr   ( obj_addr     ),
    .rom_data   ( obj_data     ),
    .rom_ok     ( obj_ok       ),
    .rom_cs     ( obj_cs       ),
    .pxl        ( obj_pxl      )
);

jtpktgal_colmix u_colmix(
    .LHBL        ( LHBL        ),
    .LVBL        ( LVBL        ),
    .tile_pxl    ( pf_pxl      ),
    .obj_pxl     ( obj_pxl     ),
    .promrg_addr ( promrg_addr ),
    .promrg_data ( promrg_data ),
    .promb_addr  ( promb_addr  ),
    .promb_data  ( promb_data  ),
    .red         ( red         ),
    .green       ( green       ),
    .blue        ( blue        ),
    .gfx_en      ( gfx_en      )
);

endmodule
