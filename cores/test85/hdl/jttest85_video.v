/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jttest85_video(
    input             rst,
    input             clk,
    input             pxl_cen,

    output     [ 9:0] text_vaddr,
    input      [ 7:0] text_vdata,

    output            LHBL,
    output            LVBL,
    output            HS,
    output            VS,
    output reg [ 3:0] red,
    output reg [ 3:0] green,
    output reg [ 3:0] blue
);

wire [ 8:0] vdump, hdump;
wire [ 9:0] font_addr;
wire [ 7:0] font_data;
wire [ 6:0] char_code;
wire [ 1:0] text_pxl;
wire        visible, text_on, white_on;

assign char_code = text_vdata[6:0];
assign visible   = LHBL & LVBL;
assign text_on   = visible & text_pxl[0];
assign white_on  = text_on & ~text_pxl[1];

always @(posedge clk) begin
    if(pxl_cen) begin
        red   <= text_on  ? 4'hf : 4'h0;
        green <= white_on ? 4'hf : 4'h0;
        blue  <= white_on ? 4'hf : 4'h0;
    end
end

jtframe_vtimer #(
    .HB_START ( 9'd255 ),
    .HS_START ( 9'd297 ),
    .HB_END   ( 9'd383 ),
    .V_START  ( 9'd016 ),
    .VS_START ( 9'd254 ),
    .VB_START ( 9'd239 ),
    .VB_END   ( 9'd279 )
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
    .pal       ( text_vdata[7]    ),
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

module jttest85_font(
    input             clk,
    input      [ 9:0] rom_addr,
    output     [ 7:0] rom_data
);

wire [ 6:0] ascii     = rom_addr[9:3];
wire [ 6:0] font_code = ascii < 7'h20 ? 7'd0 : ascii - 7'h20;
wire [ 9:0] font_addr = { font_code, rom_addr[2:0] };

jtframe_ram #(
    .AW      ( 10          ),
    .DW      (  8          ),
    .SYNFILE ( "font0.hex" )
) u_font(
    .clk     ( clk       ),
    .cen     ( 1'b1      ),
    .data    ( 8'd0      ),
    .addr    ( font_addr ),
    .we      ( 1'b0      ),
    .q       ( rom_data  )
);

endmodule
