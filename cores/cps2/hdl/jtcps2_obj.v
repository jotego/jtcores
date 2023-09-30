/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 24-1-2021 */


module jtcps2_obj(
    input              rst,
    input              clk,
    input              clk_cpu,
    input              pxl_cen,
    input              flip,
    input              LVBL,

    // Configuration
    input              objcfg_cs,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dsn,
    input      [ 3:1]  addr,

    // Interface with SDRAM for ORAM data
    output     [12:0]  oram_addr,
    input              oram_ok,
    output             oram_clr,
    output             oram_cs,
    input      [15:0]  oram_data,

    input              obank,

    input              start,
    input      [ 8:0]  vrender1,  // 1 line  ahead of vdump
    input      [ 8:0]  vdump,
    input      [ 8:0]  hdump,

    output     [19:0]  rom_addr,    // up to 1 MB
    output     [ 1:0]  rom_bank,
    output             rom_half,    // selects which half to read
    input      [31:0]  rom_data,
    output             rom_cs,
    input              rom_ok,

    output     [11:0]  pxl
);

wire [15:0] dr_code, dr_attr;
wire [ 8:0] dr_hpos;
wire [ 2:0] dr_prio, buf_prio;
wire [ 1:0] dr_bank;

wire        dr_start, dr_idle;

wire [15:0] line_data;
wire [ 8:0] line_addr;

wire [ 8:0] hdump_dly;

wire [ 8:0] buf_addr, buf_data;
wire [11:0] prio_data;
wire        buf_wr;

wire [ 9:0] off_x, off_y;

wire        obank_frame, oframe_we, line;

// shadow RAM interface
wire [ 9:0] table_attr;
wire [15:0] obj_x, obj_y, obj_code, obj_attr;

assign prio_data = { buf_prio, buf_data };

jtcps2_obj_frame u_frame(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .LVBL       ( LVBL          ),

    .vdump      ( vdump         ),
    .obank      ( obank         ),

    // Interface with SDRAM for ORAM data
    .oram_addr  ( oram_addr     ),
    .oram_ok    ( oram_ok       ),
    .oram_clr   ( oram_clr      ),
    .oram_cs    ( oram_cs       ),

    // Interface with ORAM frame buffer
    .oframe_we  ( oframe_we     ),
    .obank_frame( obank_frame   )
);

jtcps2_objram u_objram(
    .rst        ( rst           ),
    .clk_cpu    ( clk           ),  // use GFX as it is driven by u_frame
    .clk_gfx    ( clk           ),

    .obank      ( obank_frame   ),

    // OBJ config
    .objcfg_cs  ( objcfg_cs     ),
    .cfg_addr   ( addr          ),
    .cpu_dout   ( cpu_dout      ),
    .cfg_dsn    ( dsn           ),

    .off_x      ( off_x         ),
    .off_y      ( off_y         ),

    // Interface with CPU
    .cs         ( oframe_we     ),
    .ok         (               ),
    .dsn        ( 2'd0          ),
    .oram_din   ( oram_data     ),
    .main_addr  ( {1'b0, oram_addr[11:0] } ),

    // Interface with OBJ engine
    .obj_addr   ( table_attr    ),
    .obj_x      ( obj_x         ),
    .obj_y      ( obj_y         ),
    .obj_code   ( obj_code      ),
    .obj_attr   ( obj_attr      )
);

jtcps2_obj_scan u_scan(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .flip       ( flip          ),

    .hdump      ( hdump         ),
    .vrender1   ( vrender1      ),
    .line       ( line          ),

    .off_x      ( off_x         ),
    .off_y      ( off_y         ),

    // interface with frame table
    .table_addr ( table_attr    ),
    .table_x    ( obj_x         ),
    .table_y    ( obj_y         ),
    .table_code ( obj_code      ),
    .table_attr ( obj_attr      ),

    // interface with renderer
    .dr_start   ( dr_start      ),
    .dr_idle    ( dr_idle       ),

    .dr_code    ( dr_code       ),
    .dr_attr    ( dr_attr       ),
    .dr_hpos    ( dr_hpos       ),
    .dr_prio    ( dr_prio       ),
    .dr_bank    ( dr_bank       )
);

jtcps1_obj_draw u_draw(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .start      ( dr_start      ),
    .idle       ( dr_idle       ),

    .obj_code   ( dr_code       ),
    .obj_attr   ( dr_attr       ),
    .obj_hpos   ( dr_hpos       ),
    .obj_bank   ( dr_bank       ),

    .obj_prio   ( dr_prio       ),
    .buf_prio   ( buf_prio      ),

    .buf_addr   ( buf_addr      ),
    .buf_data   ( buf_data      ),
    .buf_wr     ( buf_wr        ),

    .rom_addr   ( rom_addr[19:0]),
    .rom_half   ( rom_half      ),
    .rom_bank   ( rom_bank      ),
    .rom_data   ( rom_data      ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        )
);

jtframe_sh #(.W(9),.L(3)) u_sh(
    .clk    ( clk       ),
    .clk_en ( pxl_cen   ),
    .din    ( hdump     ),
    .drop   ( hdump_dly )
);

jtcps1_obj_line #(.DW(12)) u_line(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .flip       ( flip          ),

    .vdump      ( line          ),
    .hdump      ( hdump_dly     ),

    .buf_addr   ( buf_addr      ),
    .buf_data   ( prio_data     ),
    .buf_wr     ( buf_wr        ),

    .pxl        ( pxl           )
);

endmodule