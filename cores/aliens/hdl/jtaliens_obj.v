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

    input      [ 1:0] cfg,

    // CPU interface
    input             cs,
    input             cpu_we,
    input      [ 7:0] cpu_dout,
    input      [10:0] cpu_addr,
    output     [ 7:0] cpu_din,

    // ROM addressing
    output reg [18:0] rom_addr,
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
    output            nmi_n,

    output     [11:0] pxl,
    output            blank_n,
    // Debug
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

localparam [1:0]    ALIENS=0,
                    SCONTRA=1,
                    THUNDERX=2;

wire [ 7:0] pal, pal_eff;     // OC pins
wire [ 8:0] xpos;
wire [12:0] code;
wire [13:0] code_eff;
wire [ 3:0] ysub;
wire [ 5:0] hzoom;
wire        dr_start, dr_busy, hflip, vflip, hz_keep;
wire        flip=0;
wire [18:0] pre_addr;

assign blank_n = pxl[3:0]!=0 && gfx_en[3];

assign pal_eff  = cfg==SCONTRA ? pal : { 1'b0, pal[6:0] };
assign code_eff = cfg==SCONTRA ? { 1'b0, code } : { pal[7], code };

always @* begin
    rom_addr = pre_addr;
    rom_addr[4:3] = { pre_addr[3], pre_addr[4] };
end

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
    .hzoom      ( hzoom     ),
    .hz_keep    ( hz_keep   ),

    .irq_n      ( irq_n     ),
    .firq_n     (           ),
    .nmi_n      ( nmi_n     ),
    // Debug
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_dout   )
);

jtframe_objdraw #(.CW(14),.PW(12),.LATCH(1),.SWAPH(1),.ZW(7)) u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( hs        ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),

    .draw       ( dr_start  ),
    .busy       ( dr_busy   ),
    .code       ( code_eff  ),
    .xpos       ( xpos      ),
    .ysub       ( ysub      ),
    .hz_keep    ( hz_keep   ),
    .hzoom      ({1'b0,hzoom}),

    .hflip      ( ~hflip    ),
    .vflip      ( vflip     ),
    .pal        ( pal_eff   ),

    .rom_addr   ( pre_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( rom_data  ),

    .pxl        ( pxl       )
);

endmodule