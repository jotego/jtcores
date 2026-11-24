// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// SPDX-License-Identifier: GPL-3.0-only
// Date: 2026-11-08

// GX400 palette output transfer, blanking, and JTFRAME layer visibility.
`default_nettype none

module jtnemsis_colmix(
    input         rst,
    input         clk,
    input         pxl_cen,
    input  [ 1:0]  source,
    input  [ 4:0]  red5,
    input  [ 4:0]  green5,
    input  [ 4:0]  blue5,
    input         preLHBL,
    input         preLVBL,
    output        LHBL,
    output        LVBL,
    output [ 7:0]  red,
    output [ 7:0]  green,
    output [ 7:0]  blue,
    input  [ 3:0]  gfx_en
);

wire [14:0] rgb_in, rgb_blank;
wire [ 7:0] red_lut, green_lut, blue_lut;
wire        visible;
reg  [ 1:0] source_lut;

assign rgb_in = { red5, green5, blue5 };
// Bit 0 is the framework fixed layer, which the GX400 does not implement.
// Opacity is gated before the priority chip and again for forced winners.
assign visible = source_lut == 2'd1 ? gfx_en[1] :
                 source_lut == 2'd2 ? gfx_en[2] : gfx_en[3];

assign red   = visible ? red_lut   : 8'd0;
assign green = visible ? green_lut : 8'd0;
assign blue  = visible ? blue_lut  : 8'd0;

// The RGB input is the main board's registered palette output. Blanking is
// applied here without changing that register or the LUT latency. The source
// tag passed the same pixel register in game and is delayed to match the LUT.
always @(posedge clk or posedge rst) begin
    if( rst ) source_lut <= 2'd0;
    else      source_lut <= source;
end

jtframe_blank #(.DLY(0), .DW(15)) u_blank(
	.clk      ( clk       ),
	.pxl_cen  ( pxl_cen   ),
	.preLHBL  ( preLHBL   ),
	.preLVBL  ( preLVBL   ),
	.LHBL     ( LHBL      ),
	.LVBL     ( LVBL      ),
	.preLBL   (           ),
	.rgb_in   ( rgb_in    ),
	.rgb_out  ( rgb_blank )
);

// Lookup table generated from the GX400 resistor network measurement.
jtnemsis_colour_lut #(.SYNFILE("colmix.hex")) u_colour_lut(
    .clk       ( clk       ),
    .in_red    ( rgb_blank[14:10] ),
    .in_green  ( rgb_blank[ 9: 5] ),
    .in_blue   ( rgb_blank[ 4: 0] ),
    .out_red   ( red_lut  ),
    .out_green ( green_lut),
    .out_blue  ( blue_lut )
);

endmodule

`default_nettype wire
