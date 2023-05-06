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

module jtaliens_obj(
    input             rst,
    input             clk,
    input             pxl_cen,

    // CPU interface
    input             cs,
    input             cpu_we,
    input      [ 7:0] cpu_dout,
    input      [10:0] cpu_addr,
    output     [ 7:0] cpu_din,

    // ROM addressing
    output     [17:0] rom_addr,
    input      [31:0] rom_data,
    output            rom_cs,
    input             rom_ok,
    // control
    input      [ 8:0] hdump,    // Not inputs in the original, but
    input      [ 8:0] vdump,    // generated internally.
                                // Hdump goes from 20 to 19F, 384 pixels
                                // Vdump goes from F8 to 1FF, 264 lines
    input             hs,
    input             vs,
    input             lvbl,
    input             lhbl,

    output            irq_n,

    output     [11:0] pxl,
    // Debug
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

wire [ 7:0] pal;     // OC pins
wire        hflip, vflip;
wire [ 8:0] xpos;
wire [12:0] code;
wire [ 3:0] ysub;
wire        dr_start, dr_busy, hflip, vflip;
wire        flip=0;

jt051960 u_scan(    // sprite logic
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    // Base Video (inputs)
    .vs         ( vs        ),
    .lvbl       ( lvbl      ),
    .lhbl       ( lhbl      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    // CPU interface
    .cs         ( cs        ),
    .cpu_addr   (cpu_addr[10:0]),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( cpu_we    ),
    .cpu_din    ( cpu_din   ),

    // drawing interface
    .dr_start   ( dr_start  ),
    .dr_busy    ( dr_busy   ),
    // tile details
    .hpos       ( xpos      ),
    .vflip      ( vflip     ),
    .hflip      ( hflip     ),
    .attr       ( pal       ),
    .code       ( code      ),
    .ysub       ( ysub      ),

    .irq_n      ( irq_n     ),
    .firq_n     (           ),
    .nmi_n      (           ),
    // Debug
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_dout   )
);

jtframe_objdraw #(.CW(13),.PW(12),.LATCH(1)) u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( hs        ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),

    .draw       ( dr_start  ),
    .busy       ( dr_busy   ),
    .code       ( code      ),
    .xpos       ( xpos      ),
    .ysub       ( ysub      ),

    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( pal       ),

    .rom_addr   ( rom_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( rom_data  ),

    .pxl        ( pxl       )
);

endmodule