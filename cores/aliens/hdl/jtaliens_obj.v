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
    output     [ 7:0] ioctl_din,
    output     [ 7:0] dump_reg,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

parameter GRADIUS3_LAYOUT = 0;

wire [ 8:0] xpos;
wire [ 3:0] ysub;
wire [ 7:0] ram_dout;
wire [ 5:0] hzoom;
wire        dr_start, dr_busy, hflip, vflip, hz_keep;
wire        flip, buf_sha;
wire [18:0] pre_addr;
wire [17:0] romrd_addr;
wire [11:0] buf_pred, buf_din;
wire        rom_cs_draw;
wire [31:0] draw_data;

assign rom_cs = rom_cs_draw | romrd;
assign blank_n = pxl[3:0]!=0 && gfx_en[3];
assign buf_din = { buf_sha, buf_pred[10:4], buf_sha ? 4'h0 : buf_pred[3:0] };
assign shadow  = pxl[11];
assign draw_data = GRADIUS3_LAYOUT ? grad3_obj_order( rom_data ) : rom_data;

function [31:0] grad3_obj_order( input [31:0] raw );
    // Gradius III connects the object ROM data differently to the CPU and
    // to the K051937/K051960 pixel path. Convert MAME's Gradius III packed
    // nibble layout into the plane-per-byte order expected by jtframe_draw.
    // SDRAM presents the first byte in raw[31:24], matching the ROM-read path.
    grad3_obj_order = {
        raw[15], raw[11], raw[ 7], raw[ 3], raw[31], raw[27], raw[23], raw[19],
        raw[14], raw[10], raw[ 6], raw[ 2], raw[30], raw[26], raw[22], raw[18],
        raw[13], raw[ 9], raw[ 5], raw[ 1], raw[29], raw[25], raw[21], raw[17],
        raw[12], raw[ 8], raw[ 4], raw[ 0], raw[28], raw[24], raw[20], raw[16]
    };
endfunction

// jtframe_draw outputs H[3],V[3:0]
// swap bits 3 and 4 to comply with Konami ROM order
always @* begin
    rom_addr      = pre_addr;
    rom_addr[4:3] = { pre_addr[3], pre_addr[4] };
    cpu_din       = ram_dout;
    if( romrd ) begin
        rom_addr = { code_eff[13], romrd_addr };
        if( GRADIUS3_LAYOUT ) begin
            case(cpu_addr[1:0])
                0: cpu_din = rom_data[  0 +: 8];
                1: cpu_din = rom_data[  8 +: 8];
                2: cpu_din = rom_data[ 16 +: 8];
                3: cpu_din = rom_data[ 24 +: 8];
            endcase
        end else begin
            case(cpu_addr[1:0])
                3: cpu_din = rom_data[  0 +: 8];
                2: cpu_din = rom_data[  8 +: 8];
                1: cpu_din = rom_data[ 16 +: 8];
                0: cpu_din = rom_data[ 24 +: 8];
            endcase
        end
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
    .dump_reg   ( dump_reg  ),
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
    .trunc      ( 2'd0      ),

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
    .rom_cs     ( rom_cs_draw ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( draw_data ),

    .buf_pred   ( buf_pred  ),
    .buf_din    ( buf_din   ),

    .pxl        ( pxl       )
);

endmodule
