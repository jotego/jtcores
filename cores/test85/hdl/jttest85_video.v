/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jttest85_video(
    input             rst,
    input             clk,
    output            pxl_cen, pxl2_cen,

    output     [ 9:0] text_vaddr,
    input      [ 7:0] text_vdata,

    output            LHBL,
    output            LVBL,
    output            HS,
    output            VS,
    output reg [ 3:0] red,
    output reg [ 3:0] green,
    output     [ 3:0] blue
);

wire [ 8:0] vdump, hdump;
wire [ 9:0] font_addr;
wire [ 7:0] font_data;
wire [ 6:0] char_code;
wire [ 1:0] text_pxl;
wire        visible, text_on, red_on, white_on, char_pal;

localparam [1:0] WHITE=2'b11,RED=2'b01;

assign char_code = text_vdata[6:0];
assign char-pal  = text_vdata[7];
assign visible   = LHBL & LVBL;
assign red_on    = visible & text_pxl==RED;
assign white_on  = visible & text_pxl==WHITE;
assign blue      = green;

always @(posedge clk) begin
    if(pxl_cen) begin
        red   <= (red_on || white_on) ? 4'hf : 4'h0;
        green <=            white_on  ? 4'hf : 4'h0;
    end
end

jtframe_frac_cen #(.WC(4),.W(2)) u_cen(
    .clk    ( clk       ),    // 48 or 96 MHz
    .n      ( 4'd1      ),
    .m      ( 4'd7      ),
    .cen    ( { pxl_cen, pxl2_cen } ),
    .cenb   (           )
);

jtframe_vtimer #(
    .HB_START ( 9'd255 ),
    .HS_START ( 9'd297 ),
    .HB_END   ( 9'd392 ),
    .V_START  ( 9'd016 ),
    .VS_START ( 9'd254 ),
    .VB_START ( 9'd239 ),
    .VB_END   ( 9'd275 )
) u_timer(
    .clk      ( clk      ),
    .pxl_cen  ( pxl_cen  ),
    .vdump    ( vdump    ),
    .vrender  (          ),
    .vrender1 (          ),
    .H        ( hdump    ),
    .Hinit    (          ),
    .Vinit    (          ),
    .LHBL     ( LHBL     ),
    .LVBL     ( LVBL     ),
    .HS       ( HS       ),
    .VS       ( VS       )
);

jtframe_tilemap #(
    .VA     ( 10 ),
    .CW     (  7 ),
    .PW     (  2 ),
    .BPP    (  1 ),
    .MAP_HW (  8 ),
    .MAP_VW (  8 )
) u_tilemap(
    .rst       ( rst              ),
    .clk       ( clk              ),
    .pxl_cen   ( pxl_cen          ),

    .vdump     ( vdump            ),
    .hdump     ( hdump            ),
    .blankn    ( visible          ),
    .flip      ( 1'b0             ),

    .vram_addr ( text_vaddr       ),

    .code      ( char_code        ),
    .pal       ( char_pal         ),
    .hflip     ( 1'b0             ),
    .vflip     ( 1'b0             ),

    .rom_addr  ( font_addr        ),
    .rom_data  ( font_data        ),
    .rom_cs    (                  ),
    .rom_ok    ( 1'b1             ),

    .pxl       ( text_pxl         )
);

jttest85_font u_font(
    .clk      ( clk       ),
    .rom_addr ( font_addr ),
    .rom_data ( font_data )
);

endmodule
