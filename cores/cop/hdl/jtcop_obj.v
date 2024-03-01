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
    Date: 4-10-2021 */

module jtcop_obj(
    input              rst,
    input              clk,
    input              clk_cpu,
    input              pxl_cen,

    input              HS,
    input              LVBL,
    input              LHBL,
    input              flip,
    input              hinit,
    input              vload,
    input      [ 8:0]  vrender,
    input      [ 8:0]  hdump,

    // SD dump
    input              ioctl_ram,
    input      [10:0]  ioctl_addr,
    output     [ 7:0]  ioctl_din,
    // CPU interface
    input      [10:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    output     [15:0]  obj_dout,
    input      [ 1:0]  cpu_dsn,
    input              cpu_rnw,
    input              objram_cs,

    // ROM interface
    output             rom_cs,
    output     [17:1]  rom_addr,
    input      [31:0]  rom_data,
    input              rom_ok,

    // DMA trigger
    input              obj_copy,
    input              mixpsel,

    output     [7:0]   pxl
);

wire [ 9:0]   tbl_addr;
wire [15:0]   tbl_dout;

jtcop_obj_buffer u_buffer(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_cpu    ( clk_cpu   ),
    .pxl_cen    ( pxl_cen   ),

    // SD dump
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din ),

    .LVBL       ( LVBL      ),
    .hinit      ( hinit     ),
    .vload      ( vload     ),
    .hdump      ( hdump[7:0]),

    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .obj_dout   ( obj_dout  ),
    .cpu_dsn    ( cpu_dsn   ),
    .cpu_rnw    ( cpu_rnw   ),
    .objram_cs  ( objram_cs ),

    // Object engine
    .tbl_addr   ( tbl_addr  ),
    .tbl_dout   ( tbl_dout  ),

    // DMA trigger
    .obj_copy   ( obj_copy  ),
    .mixpsel    ( mixpsel   )
);

jtcop_obj_draw u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .HS         ( HS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .flip       ( flip      ),

    .hdump      ( hdump     ),
    .vrender    ( vrender   ),

    // Object engine
    .tbl_addr   ( tbl_addr  ),
    .tbl_dout   ( tbl_dout  ),

    // ROM interface
    .rom_cs     ( rom_cs    ),
    .rom_addr   ( rom_addr  ),
    .rom_data   ( rom_data  ),
    .rom_ok     ( rom_ok    ),

    .pxl        ( pxl       )
);

endmodule