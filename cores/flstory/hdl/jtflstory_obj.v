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
    Date: 22-11-2024 */

// 0x100 RAM
// 00~0x7F -> 32 objects, 4 bytes per object
// 80~9F   -> 4:0 drawing order
//            7   priority bit

module jtflstory_obj(
    input             rst,
                      clk, pxl_cen,
                      lhbl, lvbl, hs,
                      gvflip, ghflip,
                      layout,

    input       [8:0] vdump,
    input       [8:0] hdump,
    // RAM shared with CPU
    output     [ 7:0] ram_addr,
    input      [ 7:0] ram_dout,
    output     [ 7:0] ram_din,
    output            ram_we,
    // ROM
    output     [16:2] rom_addr,
    input      [31:0] rom_data,
    output            rom_cs,
    input             rom_ok,
    output     [ 2:0] prio,
    output     [ 7:0] pxl
);

wire [ 8:0] hvdump = {hdump[8], hdump[7:0] ^ {8{ghflip}}};
wire [31:0] sorted;
wire [16:2] raw_addr;
wire  [7:0] buf_addr;
wire        buf_we;
wire [10:0] buf_din;
wire [10:0] pxl_raw;
wire [ 9:0] code;
wire [ 7:0] xpos; // object to check
wire [ 6:0] pal;               // priority at top 3 bits
wire [ 3:0] ysub;
wire        hflip, vflip;
wire        blink, dr_busy, draw;

assign rom_addr = { raw_addr[16:7], raw_addr[5], raw_addr[6], raw_addr[4:2] };

assign sorted = ~{
    rom_data[12],rom_data[13],rom_data[14],rom_data[15],rom_data[28],rom_data[29],rom_data[30],rom_data[31],
    rom_data[ 8],rom_data[ 9],rom_data[10],rom_data[11],rom_data[24],rom_data[25],rom_data[26],rom_data[27],
    rom_data[ 4],rom_data[ 5],rom_data[ 6],rom_data[ 7],rom_data[20],rom_data[21],rom_data[22],rom_data[23],
    rom_data[ 0],rom_data[ 1],rom_data[ 2],rom_data[ 3],rom_data[16],rom_data[17],rom_data[18],rom_data[19]
};

jtframe_blink u_blink(
    .clk   ( clk    ),
    .en    ( 1'b1   ),
    .vs    (~lvbl   ),
    .blink ( blink  )
);

jtflstory_obj_scan u_scan(
    .clk        ( clk       ),
    .lhbl       ( lhbl      ),
    .blink      ( blink     ),
    .ghflip     ( ghflip    ),
    .gvflip     ( gvflip    ),
    .layout     ( layout    ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    // RAM shared with CPU
    .ram_addr   ( ram_addr  ),
    .ram_dout   ( ram_dout  ),
    .ram_din    ( ram_din   ),
    .ram_we     ( ram_we    ),
    // draw requests
    .dr_busy    ( dr_busy   ),
    .draw       ( draw      ),
    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .code       ( code      ),
    .xpos       ( xpos      ),
    .ysub       ( ysub      ),
    .pal        ( pal       )
);

jtframe_draw #(
    .AW      ( 8        ),
    .CW      ( 10       ),
    .PW      ( 11       ),
    .SWAPH   ( 1        )
)u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .draw       ( draw      ),
    .busy       ( dr_busy   ),
    .code       ( code      ),
    .xpos       ( xpos      ),
    .ysub       ( ysub      ),
    .trunc      ( 2'd0      ),
    .hz_keep    ( 1'b0      ),
    .hzoom      ( 6'd0      ),
    .hflip      ( ~hflip    ),
    .vflip      ( vflip     ),
    .pal        ( pal       ),
    .rom_addr   ( raw_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( sorted    ),

    .buf_addr   ( buf_addr  ),
    .buf_we     ( buf_we    ),
    .buf_din    ( buf_din   )
);

jtflstory_single_line_buffer u_linebuf(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .we         ( buf_we    ),
    .din        ( buf_din   ),
    .addr       ( buf_addr  ),
    .hvdump     ( hvdump    ),
    .pxl        ( pxl_raw   )
);

jtframe_sh #(.W(11),.L(9)) u_sh(
    .clk    ( clk       ),
    .clk_en ( pxl_cen   ),
    .din    ( pxl_raw   ),
    .drop   ({prio,pxl} )
);

endmodule