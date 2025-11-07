/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME. If not, see <http://www.gnu.org/licenses/>.

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 10-6-2024 */

// This module is used for sending an analogic video signal through the cartdrige pins for use with CRT
module jtframe_pocket_anavideo #(parameter
    COLORW = 4,
    VGA_DW = 6
)(
    input             rst,
    input             clk,
    input             pxl_cen, pxl2_cen,
    input      [11:0] crt_cfg,   // From config file. bits [31:20]
    // Base video
    input [COLORW-1:0] game_r, game_g, game_b,
    input             LHBL, LVBL,
    input             hs,vs,
    // Final video
    output     [ 1:0] anv_en, // enable analogic video output
    output            yc_en,  // enable composite video output
    output     [23:0] yc_vid,
    output reg [ 7:0] cart3_vid, cart2_vid,
    output reg [ 4:0] cart1_vid,
    output reg        cart1_vdir, cart2_vdir, cart3_vdir
);

`ifndef JTFRAME_NO_ANALOGIZER
// CRT Configuration
wire [1:0]  scanlines;
wire        bypass, bw_en,  no_csync,  blend_en,
            sog,    ypbpr,  scan2x_en, pal_en;

assign anv_en    = {crt_cfg[11], crt_cfg[0]};
assign bypass    =  crt_cfg[10];
assign ypbpr     =  crt_cfg[9];
assign yc_en     =  crt_cfg[8];
assign pal_en    =  crt_cfg[7];
assign no_csync  = ~crt_cfg[5];
assign bw_en     =  crt_cfg[4];
assign sog       =  crt_cfg[3];
assign scanlines =  crt_cfg[2:1];
assign scan2x_en =  crt_cfg[0];
assign blend_en  =  0;

// Video
wire [3*COLORW-1:0] game_rgb = {game_r, game_g, game_b};
reg  [  VGA_DW-1:0] an_r,    an_g,    an_b;
wire [  VGA_DW-1:0] an_rout, an_gout, an_bout;
reg                 hs_out,  vs_out,  blank_n,
                    hs_voutl,vs_voutl;
wire                hs_vout, vs_vout, de_vout;

function [5:0] extend6;
    input [COLORW-1:0] a;
    if( COLORW <= 6) extend6[5-:COLORW] = a; // this also covers COLORW==6
    else extend6 = a[COLORW-1 -: 6];
    case( COLORW )
        2: extend6 = {3{a[1:0]}};
        3: extend6 = {2{a[2:0]}};
        4: extend6 = { a, a[COLORW-1-:2] };
        5: extend6[0] = a[COLORW-1];
        default: ;
    endcase
endfunction

always @(posedge clk) begin
    if( rst ) begin
        {cart1_vdir, cart2_vdir, cart3_vdir} <= 3'b0;
         cart1_vid  <= 5'h0;     cart2_vid   <= 8'h0;
         cart3_vid  <= 8'h0;
    end else begin
        {cart1_vdir, cart2_vdir, cart3_vdir} <= 3'b111;
        cart1_vid  <=  an_b[5:1];
        cart2_vid  <= {an_b[0], blank_n , an_g};
        cart3_vid  <= {an_r   , hs_out, vs_out};
    end
end

always @(posedge clk) begin
    {hs_voutl,vs_voutl} <= {hs_vout, vs_vout};
    hs_out  <=  hs_vout; vs_out <= vs_vout;
    blank_n <=  de_vout;
    an_r    <=  an_rout; an_g   <= an_gout;
    an_b    <=  an_bout;

    if( yc_en ) begin
        {hs_out,vs_out} <= {hs_voutl, vs_voutl};
         blank_n <= 1'b1;
    end

    if( ypbpr ) blank_n <= 1'b1;
    if( bypass) begin
        an_r    <=  extend6(game_r);
        an_g    <=  extend6(game_g);
        an_b    <=  extend6(game_b);
        hs_out  <=  hs             ;
        vs_out  <=  vs             ;
        blank_n <=  LHBL&LVBL      ;
    end
end

jtframe_mist_video #(
    .COLORW(COLORW),
    .VGA_DW(VGA_DW),
    .OSD   (     0)
    //.VIDEO_WIDTH(256)
) u_videotype (
    .rst        ( rst       ),
    .clk        ( clk       ),
    // base video
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .game_hs    ( hs        ),
    .game_vs    ( vs        ),
    .game_lvbl  ( LVBL      ),
    .game_lhbl  ( LHBL      ),
    .game_rgb   ( game_rgb  ),
    // SPI for OSD contents
    .osd_di     ( 1'b0      ),
    .osd_sck    ( 1'b0      ),
    .osd_ss3    ( 1'b0      ),
    .osd_rotate ( 2'b0      ),
    .osd_shown  (           ),
    // low pass filter for video
    .bw_en      ( bw_en     ),
    .blend_en   ( blend_en  ),
    .scanlines  ( scanlines ),
    // video signal type
    .ypbpr      ( ypbpr     ),
    .no_csync   ( no_csync  ),
    .scan2x_en  ( scan2x_en ), // scan doubler enable bar
    .sog        ( sog       ),
    .cvideo_en  ( yc_en     ),
    .pal_en     ( pal_en    ),
    // Scan-doubler video
    .scan2x_r   (           ),
    .scan2x_g   (           ),
    .scan2x_b   (           ),
    .scan2x_hs  (           ),
    .scan2x_vs  (           ),
    .scan2x_de  (           ),
    .scan2x_HB  (           ),
    .scan2x_VB  (           ),
    // crt video
    .video_hs   ( hs_vout    ),
    .video_vs   ( vs_vout    ),
    .video_r    ( an_rout    ),
    .video_g    ( an_gout    ),
    .video_b    ( an_bout    ),
    .video_de   ( de_vout    ),
    // Composite video output
    .yc_vid     ( yc_vid     )
);
`else
initial begin
    {cart3_vid,  cart2_vid,  cart1_vid } = 0;
    {cart1_vdir, cart2_vdir, cart3_vdir} = 0;
end
assign anv_en = 0;
assign yc_en  = 0;
assign yc_vid = 0;
`endif

endmodule
