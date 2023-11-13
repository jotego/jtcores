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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 11-8-2022 */

module jtframe_logo #(parameter
    COLORW  = 4,
    SHOWHEX = 1
) (
    input        rst,
    input        clk,
    input        pxl_cen,
    input        show_en,
    // input  [1:0] rotate, //[0] - rotate [1] - left or right

    // VGA signals coming from core
    input  [3*COLORW-1:0] rgb_in,
    input        hs,
    input        vs,
    input        lhbl,
    input        lvbl,

    // VGA signals going to video connector
    output reg [3*COLORW-1:0] rgb_out,

    input [63:0] chipid,

    output reg   hs_out,
    output reg   vs_out,
    output reg   lhbl_out,
    output reg   lvbl_out
);

reg  [ 8:0] hcnt=0,vcnt=0,
            htot=9'd256, vtot=9'd256,
            hover=0, vover=9'd100;
reg  [ 9:0] hdiff, vdiff;
reg         lhbl_l, lvbl_l;
wire [15:0] tile_data;
wire [ 7:0] tile_id;
wire        idpxl;
reg         inzone;
wire [10:1] tile_addr;
wire [ 8:0] vaddr;
wire [ 2:0] logopxl;
reg  [COLORW*3-1:0] logorgb;

jtframe_prom #(.synhex("logodata.hex"),.AW(10),.DW(16)) u_tiles(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .rd_addr( tile_addr ),
    .data   ( 16'd0     ),
    .wr_addr( 10'd0     ),
    .we     ( 1'b0      ),
    .q      ( tile_data )
);

jtframe_prom #(.synhex("logomap.hex"),.AW(9)) u_map(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .rd_addr( vaddr     ),
    .data   ( 8'd0      ),
    .wr_addr( 9'd0      ),
    .we     ( 1'b0      ),
    .q      ( tile_id   )
);

always @* begin
    case( logopxl[1:0] )
        0: logorgb = {3*COLORW{1'b0}}; // Black
        1: logorgb = {3*COLORW{1'b1}}; // White
        default: logorgb = { {COLORW{1'b1}}, {2*COLORW{1'b0}} }; // Red
    endcase
end

jtframe_tilemap #(
    .VA    (9),
    .CW    (7),
    .PW    (3),
    .BPP   (2),
    .MAP_HW(8),
    .MAP_VW(7)
)u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vdump      ( vdiff[8:0]),
    .hdump      ( hdiff[8:0]),
    .blankn     ( 1'b1      ),
    .flip       ( 1'b0      ),

    .vram_addr  ( vaddr     ),

    .code       (tile_id[6:0]),
    .pal        (tile_id[7] ),
    .hflip      ( 1'b0      ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( tile_addr ),
    .rom_data   ( tile_data ),
    .rom_cs     (           ),
    .rom_ok     ( 1'b1      ),

    .pxl        ( logopxl   )
);


always @(posedge clk) if( pxl_cen ) begin
    { hs_out, vs_out     } <= { hs, vs };
    { lhbl_out, lvbl_out } <= { lhbl, lvbl };
    rgb_out <= !show_en ? rgb_in :                                    // regular video
              inzone ? logorgb : {3*COLORW{idpxl & SHOWHEX[0] }};     // logo or chip ID
end

always @* begin
    hdiff = {1'b0,hcnt} - {1'b0,hover};
    vdiff = {1'b0,vcnt} - {1'b0,vover};
    inzone = hdiff < 256 && !hdiff[9] && hdiff>8 &&
             vdiff < 128 && !vdiff[9];
end

// screen counter
always @(posedge clk) if( pxl_cen ) begin
    lhbl_l <= lhbl;
    lvbl_l <= lvbl;
    hcnt <= lhbl ? hcnt + 9'd1 : 9'd0;
    if( !lhbl && lhbl_l ) begin
        htot <= hcnt;
        vcnt <= lvbl ? vcnt+9'd1 : 9'd0;
    end
    if( !lvbl && lvbl_l ) begin
        vtot  <= vcnt;
        hover <= htot<9'd256 ? 9'd0 : (htot-9'd256)>>1;
        vover <= vtot<9'd128 ? 9'd0 : (vtot-9'd128)>>1;
    end
end

jtframe_hexdisplay #(.H0(64),.V0(192)) u_hexdisplay(
    .clk     ( clk       ),
    .pxl_cen ( pxl_cen   ),
    .hcnt    ( hcnt      ),
    .vcnt    ( vcnt      ),
    .data    ( chipid    ),
    .pxl     ( idpxl     )
);

endmodule
