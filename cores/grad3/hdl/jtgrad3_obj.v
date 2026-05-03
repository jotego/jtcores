/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jtgrad3_obj(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             cs,
    input             cpu_we,
    input      [ 7:0] cpu_dout,
    input      [10:0] cpu_addr,
    output reg [ 7:0] cpu_din,

    output reg [18:0] rom_addr,
    input      [31:0] rom_data,
    output            rom_cs,
    input             rom_ok,

    output            romrd,
    input      [ 8:0] hdump,
    input      [ 8:0] vdump,
    input             hs,
    input             vs,
    input             lvbl,
    input             lhbl,

    output            irq_n,
    output            nmi_n,

    output     [12:0] code,
    input      [13:0] code_eff,
    output     [ 7:0] pal,
    input      [ 7:0] pal_eff,

    output     [11:0] pxl,
    output            shadow,
    output            blank_n,

    input      [10:0] ioctl_addr,
    input             ioctl_ram,
    output     [ 7:0] ioctl_din,
    output     [ 7:0] dump_reg,

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
wire        rom_cs_draw;
wire [31:0] draw_data;

assign rom_cs    = rom_cs_draw | romrd;
assign blank_n   = pxl[3:0] != 0 && gfx_en[3];
assign buf_din   = { buf_sha, buf_pred[10:4], buf_sha ? 4'h0 : buf_pred[3:0] };
assign shadow    = pxl[11];
assign draw_data = grad3_obj_order( rom_data );

function [31:0] grad3_obj_order( input [31:0] raw );
    grad3_obj_order = {
        raw[15], raw[11], raw[ 7], raw[ 3], raw[31], raw[27], raw[23], raw[19],
        raw[14], raw[10], raw[ 6], raw[ 2], raw[30], raw[26], raw[22], raw[18],
        raw[13], raw[ 9], raw[ 5], raw[ 1], raw[29], raw[25], raw[21], raw[17],
        raw[12], raw[ 8], raw[ 4], raw[ 0], raw[28], raw[24], raw[20], raw[16]
    };
endfunction

always @* begin
    rom_addr      = pre_addr;
    rom_addr[4:3] = { pre_addr[3], pre_addr[4] };
    cpu_din       = ram_dout;
    if( romrd ) begin
        rom_addr = { code_eff[13], romrd_addr };
        case( cpu_addr[1:0] )
            0: cpu_din = rom_data[  0 +: 8];
            1: cpu_din = rom_data[  8 +: 8];
            2: cpu_din = rom_data[ 16 +: 8];
            3: cpu_din = rom_data[ 24 +: 8];
        endcase
    end
end

jt051960 u_scan(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vs         ( vs        ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .flip       ( flip      ),

    .cs         ( cs        ),
    .cpu_addr   ( cpu_addr[10:0] ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( cpu_we    ),
    .cpu_din    ( ram_dout  ),

    .dr_start   ( dr_start  ),
    .dr_busy    ( dr_busy   ),
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

    .pxl        ( buf_pred  ),
    .shadow     ( buf_sha   ),

    .romrd      ( romrd     ),
    .romrd_addr ( romrd_addr),

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
