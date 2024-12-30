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

    Author: Jose Tejada Gomez. https://patreon.com/jotego
    Version: 1.0
    Date: 20-5-2024 */

module jtngpc_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             lcd_neg,

    input             scr_order,
    input      [ 2:0] oowc,
    input             oow,          // outside of window
    input             mode,

    // CPU access
    input      [ 8:1] cpu_addr,
    output     [15:0] cpu_din,
    input      [15:0] cpu_dout,
    input      [ 1:0] we,
    input             pal_cs,
    input             palrgb_cs,

    input             LHBL,
    input             LVBL,

    input       [6:0] scr1_pxl,
    input       [6:0] scr2_pxl,
    input       [8:0] obj_pxl,

    output      [3:0] red,
    output      [3:0] green,
    output      [3:0] blue,

    // Debug
    input       [8:0] ioctl_addr,
    output      [7:0] ioctl_din,
    input             ioctl_dump,
    input       [7:0] debug_bus
    // gfx_en is handled at the scroll and obj modules
);

wire [15:0] mono_dout, cpal_dout;
wire [11:0] rgb;
reg  [ 8:1] pal_addr;
wire [ 3:0] mono, mx_col, nc;
wire [ 2:0] mx_pxl;
wire [ 1:0] lyr, cpal_we;
wire        mx_pal;

// assign {green,blue,red} = rgb;
assign {blue,green,red} = rgb;
assign cpu_din = palrgb_cs ? cpal_dout : mono_dout; // do not register! extra clock cycle breaks 2nd logo screen

always @(posedge clk) if( pxl_cen ) begin
    if( mode ) begin // monochrome
        pal_addr <= { 2'b11, lyr, mx_pal, mx_pxl };
    end else begin // color:
        pal_addr <= {lyr, mx_col, mx_pxl[1:0] };
        if( lyr==3 ) // background / out-of-window (oow)
            pal_addr[6-:4] <= {2'b11, oow, mx_pxl[2]};
    end
end

jtngp_colmix u_monochrome(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .lcd_neg    ( lcd_neg   ),
    .scr_order  ( scr_order ),
    // Window
    .oow        ( oow       ),
    .oowc       ( oowc      ),
    .mode       ( mode      ),

    // CPU access
    .cpu_addr   ( cpu_addr  ),
    .cpu_din    ( mono_dout ),
    .cpu_dout   ( cpu_dout  ),
    .we         ( we        ),
    .pal_cs     ( pal_cs    ),

    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),

    .scr1_pxl   ( scr1_pxl  ),
    .scr2_pxl   ( scr2_pxl  ),
    .obj_pxl    ( obj_pxl   ),

    .lyr        ( lyr       ),
    .pxl        ( mx_pxl    ),
    .col        ( mx_col    ),
    .pal        ( mx_pal    ),

    .red        ( mono      ),
    .green      (           ),
    .blue       (           ),
    .debug_bus  ( debug_bus )
);

// the original design does not accept byte access, but we do
assign cpal_we = we & {2{palrgb_cs}};

wire [ 7:0] pala_mx = ioctl_dump ? ioctl_addr[8:1] : pal_addr;
wire [15:0] palo;
assign rgb = palo[11:0];
assign ioctl_din = ioctl_addr[0] ? palo[8+:8] : palo[0+:8];

jtframe_dual_ram16 #(
    .AW(8),
    .SIMFILE_LO("pal_lo.bin"),
    .SIMFILE_HI("pal_hi.bin")
) u_colpal(
    // Port 0
    .clk0       ( clk       ),
    .data0      ( cpu_dout  ),
    .addr0      ( cpu_addr  ),
    .we0        ( cpal_we   ),
    .q0         ( cpal_dout ),
    // Port 1
    .clk1       ( clk       ),
    .data1      ( 16'd0     ),
    .addr1      ( pal_addr  ),
    .we1        ( 2'b0      ),
    .q1         ( palo      )
);

endmodule