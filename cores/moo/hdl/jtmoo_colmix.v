/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Author: Rafael Eduardo Paiva Feener. Copyright: Jose Tejada Gomez
 * Version: 1.0
 * Date: 17-6-2026 */

module jtmoo_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,

    // Base Video
    input             lhbl,
    input             lvbl,

    // CPU interface
    input             pcu_cs,
    input             reg_cs,
    input             pal_cs,
    input             cpu_we,
    input      [15:0] cpu_dout,
    input      [ 7:0] cpu_d8,
    input      [ 1:0] cpu_dsn,
    input      [12:1] cpu_addr,
    output     [15:0] cpu_din,

    // Final pixels
    input      [ 7:0] lyrf_pxl,
    input      [11:0] lyra_pxl,
    input      [11:0] lyrb_pxl,
    input      [ 8:0] lyro_pxl,
    input      [ 4:0] lyro_pri,
    input             blnk_sel,

    input      [ 1:0] shadow,
    input      [ 2:0] dim,
    input             dimmod,
    input             dimpol,

    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,

    // Debug
    input      [11:0] ioctl_addr,
    input             ioctl_ram,
    output     [ 7:0] ioctl_din,
    output     [ 7:0] dump_mmr,

    input      [ 7:0] debug_bus
);

wire [15:0] pal_dout, pal_cpu_din;
wire [15:0] k338_dout;
wire [ 1:0] cpu_palwe;
reg  [23:0] bgr;
reg  [ 7:0] r8, b8, g8;
wire [10:0] pal_addr;
wire        shad, pcu_we, reg_we, nc, col_n, k338_video_en;
wire signed [9:0] shad_r, shad_g, shad_b;
wire [23:0] k338_bg;
// 053251 inputs
wire [ 5:0] pri0;
wire [ 8:0] ci0, ci1, ci2;
wire [ 7:0] ci3, ci4;
wire [ 3:0] fcolr, ci2_low;
wire        fpal4;
wire [ 1:0] shd_out, shd_in;
reg  [ 1:0] shd_l;
reg         col_n_l;

// 8/16 bit interface
assign cpu_palwe = {2{cpu_we&pal_cs}} & ~cpu_dsn;
assign pcu_we    = pcu_cs & ~cpu_dsn[0] & cpu_we;
assign reg_we    = reg_cs & cpu_we & (cpu_dsn!=2'b11);
assign ioctl_din = ioctl_addr[0] ? pal_dout[7:0] : pal_dout[15:8];
assign cpu_din   = reg_cs ? k338_dout : pal_cpu_din;
assign {blue,green,red} = (lvbl & lhbl ) ? bgr : 24'd0;

// 053251 wiring
assign pri0      = {lyro_pri,1'b1};
assign ci0       = lyro_pxl;  // {lyra_pxl[6:4],lyra_pxl[11:10],lyra_pxl[3:0]};
assign ci1       = 9'b0;      // lyro_pxl;
assign fpal4     = lyrf_pxl[4];
assign fcolr     = lyrf_pxl[3:0];
// blnk_sel comes from N6 pin 7. Together with FPAL4 it blanks FCOLR into CI2.
assign ci2_low   = blnk_sel && fpal4 ? 4'd0 : fcolr;
assign ci2       = { 1'b0, lyrf_pxl[7:4], ci2_low };
assign ci3       = lyra_pxl[7:0]; // lyrf_pxl ;
assign ci4       = lyrb_pxl[7:0];
assign shad      = |shd_out;
assign shd_in    =  shadow;

function [7:0] conv58(input [4:0] cin );
begin
    conv58 = {cin, cin[4-:3]};
end
endfunction

function [7:0] add_clip(input [7:0] cin, input signed [9:0] delta);
    reg signed [10:0] sum;
begin
    sum = {3'd0,cin} + delta;
    add_clip = sum < 0        ? 8'd0  :
               sum > 11'sd255 ? 8'hff : sum[7:0];
end
endfunction

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bgr     <= 0;
        shd_l   <= 0;
        col_n_l <= 0;
    end else begin
        { b8, g8, r8 } <= {conv58(pal_dout[10+:5]),conv58(pal_dout[5+:5]),conv58(pal_dout[0+:5])};
        if( pxl_cen ) begin
            shd_l   <= shd_out;
            col_n_l <= col_n;
            bgr     <= !k338_video_en ? 24'd0 :
                       col_n_l        ? k338_bg :
                       ~|shd_l        ? { b8, g8, r8 } :
                                        { add_clip(b8,shad_b), add_clip(g8,shad_g), add_clip(r8,shad_r) };
        end
    end
end

jt054338 u_k338(
    .rst         ( rst             ),
    .clk         ( clk             ),

    .cs          ( reg_cs          ),
    .we          ( reg_we          ),
    .addr        ( cpu_addr[4:1]   ),
    .din         ( cpu_dout        ),
    .dsn         ( cpu_dsn         ),
    .dout        ( k338_dout       ),

    .pblend      ( 2'd1            ),
    .shadow      ( shd_l           ),

    .bg_rgb      ( k338_bg         ),
    .alpha_level (                 ),
    .alpha_add   (                 ),
    .video_en    ( k338_video_en   ),
    .mixpri      (                 ),
    .shdpri      (                 ),
    .brtpri      (                 ),
    .clipsl      (                 ),
    .dump_mmr    (                 ),

    .shadow_r    ( shad_r          ),
    .shadow_g    ( shad_g          ),
    .shadow_b    ( shad_b          )
);

jtcolmix_053251 u_k251(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    // CPU interface
    .cs         ( pcu_we    ),
    .addr       (cpu_addr[4:1]),
    .din        (cpu_dout[5:0]),
    // explicit priorities
    .sel        ( 1'b0      ),
    .pri0       ( pri0      ),
    .pri1       ( 6'h0      ),
    .pri2       ( 6'h0      ),
    // color inputs
    .ci0        ( ci0       ),
    .ci1        ( ci1       ),
    .ci2        ( ci2       ),
    .ci3        ( ci3       ),
    .ci4        ( ci4       ),
    // shadow
    .shd_in     ( shd_in    ),
    .shd_out    ( shd_out   ),
    // dump to SD card
    .ioctl_addr ( ioctl_ram ? ioctl_addr[3:0] : debug_bus[3:0] ),
    .ioctl_din  ( dump_mmr  ),

    .cout       ( pal_addr  ),
    .brit       (           ),
    .col_n      ( col_n     )
);

// this does not follow the same arrangement of the original
// it's only important if you try to load a dump from MAME
jtframe_dual_nvram #(.AW(11),.SIMFILE("pal_hi.bin")) u_ramlo(
    // Port 0: CPU
    .clk0   ( clk           ),
    .data0  ( cpu_dout[7:0] ),
    .addr0  ( cpu_addr[11:1]),
    .we0    ( cpu_palwe[0]  ),
    .q0     ( pal_cpu_din[7:0]),
    // Port 1
    .clk1   ( clk           ),
    .data1  ( 8'd0          ),
    .addr1a ( pal_addr      ),
    .addr1b (ioctl_addr[11:1]),
    .sel_b  ( ioctl_ram     ),
    .we_b   ( 1'b0          ),
    .q1     ( pal_dout[ 7:0])
);

jtframe_dual_nvram #(.AW(11),.SIMFILE("pal_lo.bin")) u_ramhi(
    // Port 0: CPU
    .clk0   ( clk           ),
    .data0  ( cpu_dout[15:8]),
    .addr0  ( cpu_addr[11:1]),
    .we0    ( cpu_palwe[1]  ),
    .q0     ( pal_cpu_din[15:8] ),
    // Port 1
    .clk1   ( clk           ),
    .data1  ( 8'd0          ),
    .addr1a ( pal_addr      ),
    .addr1b (ioctl_addr[11:1]),
    .sel_b  ( ioctl_ram     ),
    .we_b   ( 1'b0          ),
    .q1     ( pal_dout[15:8] )
);

endmodule
