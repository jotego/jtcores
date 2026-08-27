/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 13-7-2025 */

module jtrungun_psac(
    input              rst, clk, pxl_cen, hs, vs, dtackn,
                       cs, // cs always writes

    input       [15:0] din,        // from CPU
    input       [ 4:1] addr,
    input       [ 1:0] dsn,
    input              blankn,
    output             dma_n,
    // Lines RAM
    output      [10:1] line_addr,
    input       [15:0] line_dout,
    // Tile map
    output      [13:0] vram_addr, // 14
    input       [23:0] vram_dout,

    // Tiles
    output reg  [20:0] rom_addr,
    input       [ 7:0] rom_data,
    output             rom_cs,
    input              rom_ok,

    output      [ 7:0] pxl,

    input      [3:0] gfx_en,
    // IOCTL dump
    input      [4:0] ioctl_addr,
    output     [7:0] ioctl_din
);

wire [ 8:0] la;
wire [ 2:1] lh;
wire [12:0] x, y;
wire        xh,yh,ob;
wire [13:0] code;
wire        hflip, vflip;
wire [ 7:0] pre_pxl;
wire [ 3:0] pal, vf, hf, dmux;

assign line_addr = {la[7:0],lh};
assign vram_addr = {y[10:4], x[10:4]};
assign code      = vram_dout[13:0];
assign hflip     = vram_dout[14];
assign vflip     = vram_dout[15];
assign pal       = vram_dout[19:16];
assign vf        = {4{vflip}} ^ {y[3:0]};
assign hf        = {4{hflip}} ^ {x[3:0]};
assign pre_pxl   = gfx_en[1] ? {pal,dmux} : 8'b0;

assign rom_cs    = ~ob & blankn;
assign dmux      = hf[0] ? rom_data[3:0] : rom_data[7:4];
assign pxl       = ob ? 8'd0 : pre_pxl;

always @(posedge clk) begin
    rom_addr <= {code,vf,hf[3:1]}; // 13+4+4=21
end

jt053936 u_xy(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( pxl_cen   ),

    .din        ( din       ),        // from CPU
    .addr       ( addr      ),

    .hs         ( hs        ),
    .vs         ( vs        ),
    .cs         ( cs        ),
    .dtackn     ( dtackn    ),
    .dsn        ( dsn       ),
    .dma_n      ( dma_n     ),

    .ldout      ( line_dout ),  // shared with CPU data pins on original
    .lh         ( lh        ),  // lh[0] always zero for 16-bit memories
    .la         ( la        ),

    .x          ( x         ),
    .xh         ( xh        ),
    .y          ( y         ),
    .yh         ( yh        ),
    .ob         ( ob        ), // out of bonds, original pin: NOB

    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din )
);

endmodule
