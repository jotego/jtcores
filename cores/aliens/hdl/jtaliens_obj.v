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
    output reg [ 7:0] cpu_din,

    // ROM addressing
    output reg [18:0] rom_addr, // code_eff + 5 bits (V-HVVV)
    input      [31:0] rom_data,
    output            rom_cs,
    input             rom_ok,

    output            romrd,
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

    // external connection
    output     [12:0] code,
    input      [13:0] code_eff,
    output     [ 7:0] pal,       // OC pins
    input      [ 7:0] pal_eff,

    output     [11:0] pxl,
    output            shadow,
    output            blank_n,

    // Debug
    input      [10:0] ioctl_addr,
    input             ioctl_ram,
    input             ioctl_mmr,
    output     [ 7:0] ioctl_din,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [ 8:0] xpos;
wire [ 3:0] ysub;
wire [ 7:0] ram_dout;
wire [ 5:0] hzoom;
wire        dr_start, dr_busy, hflip, vflip, hz_keep;
wire        flip, buf_sha;
wire [18:0] pre_addr;
wire [17:0] romrd_addr;
wire [11:0] buf_pred, buf_din;

assign blank_n = pxl[3:0]!=0 && gfx_en[3];
assign buf_din = { buf_sha, buf_pred[10:4], buf_sha ? 4'h0 : buf_pred[3:0] };
assign shadow  = pxl[11];

// jtframe_draw outputs H[3],V[3:0]
// swap bits 3 and 4 to comply with Konami ROM order
always @* begin
    rom_addr      = pre_addr;
    rom_addr[4:3] = { pre_addr[3], pre_addr[4] };
    cpu_din       = ram_dout;
    if( romrd ) begin
        rom_addr = { code_eff[13], romrd_addr };
        case(cpu_addr[1:0])
            0: cpu_din = rom_data[  0 +: 8];
            1: cpu_din = rom_data[  8 +: 8];
            2: cpu_din = rom_data[ 16 +: 8];
            3: cpu_din = rom_data[ 24 +: 8];
        endcase
    end
end

jt051960 u_scan(    // sprite logic
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    // Base Video (inputs)
    .vs         ( vs        ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .flip       ( flip      ), // output
    // CPU interface
    .cs         ( cs        ),
    .cpu_addr   (cpu_addr[10:0]),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( cpu_we    ),
    .cpu_din    ( ram_dout  ),

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

    // Shadow
    .pxl        ( buf_pred  ),
    .shadow     ( buf_sha   ),

    // ROM check
    .romrd      ( romrd     ),
    .romrd_addr ( romrd_addr),

    // Debug
    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din ),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_mmr  ( ioctl_mmr ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_dout   )
);

jtframe_objdraw_gate #(
    .CW(14),.PW(12),.LATCH(1),.SWAPH(1),.ZW(7),.FLIP_OFFSET(9'h12),.SHADOW(1)
) u_draw(
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

    .buf_pred   ( buf_pred  ),
    .buf_din    ( buf_din   ),

    .pxl        ( pxl       )
);

endmodule