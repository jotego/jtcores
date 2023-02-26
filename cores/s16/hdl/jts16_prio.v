/*  This file is part of JTS16.
    JTS16 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTS16 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTS16.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-7-2022 */

module jts16_prio(
    input              rst,
    input              clk,
    input              pxl2_cen,  // pixel clock enable (2x)
    input              pxl_cen,   // pixel clock enable

    input      [ 6:0]  char_pxl,
    input      [10:0]  scr1_pxl,
    input      [10:0]  scr2_pxl,
    input      [11:0]   obj_pxl,

    // Set top priority
    input              set_fix,   // I think this is what some of the input pins do, but I need to check on the board
    // Selected layer
    output reg         sa,        // active high
    output reg         sb,
    output reg         fix,

    output reg [10:0]  pal_addr,
    output reg         shadow,
    input      [ 3:0]  gfx_en
);

wire [ 1:0] we;
reg  [11:0] lyr0, lyr1, lyr2, lyr3;
wire [15:0] pal;
wire [ 1:0] obj_prio;


assign obj_prio = obj_pxl[11:10];

// bit 11 = shadow bit
// bit 10 = 0/tile 1/obj
//    9:4 = palette
//    3:0 = colour index
function [11:0] tile_or_obj( input [9:0] obj, input [9:0] tile, input tile_prio, input oprio );
// bit 11 = shadow
// bit 10 = obj selected
    tile_or_obj = obj[3:0]!=0 && oprio && (!tile_prio || tile[2:0]==0) ?
                   ( &obj[9:4] ? { 2'b10, tile } : { 2'b1, obj  } ): // shadow or object
                   { 2'b0, tile };
endfunction

// Layer gating
reg  [ 6:0] char_g;
reg  [10:0] scr1_g, scr2_g;
reg  [11:0] obj_g;
reg  [ 3:0] active;

always @(*) begin
    char_g = char_pxl;
    scr1_g = scr1_pxl;
    scr2_g = scr2_pxl;
    obj_g  = obj_pxl;
    if( !gfx_en[0] ) char_g[3:0]=0;
    if( !gfx_en[1] ) scr1_g[3:0]=0;
    if( !gfx_en[2] ) scr2_g[3:0]=0;
    if( !gfx_en[3] )  obj_g[3:0]=0;
end

always @(posedge clk) if( pxl_cen ) begin
    lyr0 <= tile_or_obj( obj_g[9:0], {4'd0, char_g[5:0] }, char_g[ 6], !set_fix && obj_prio==2'd3 );    // set_fix will prevent the objects from overlaying the text layer
    lyr1 <= tile_or_obj( obj_g[9:0],        scr1_g[9:0]  , scr1_g[10], obj_prio>=2'd2 );
    lyr2 <= tile_or_obj( obj_g[9:0],        scr2_g[9:0]  , scr2_g[10], obj_prio>=2'd1 );
    lyr3 <= tile_or_obj( obj_g[9:0], {scr2_g[9:3], 3'd0 },       1'b0, 1'b1           );
end

always @(*) begin
    { shadow, pal_addr } =
               (lyr0[10] ? lyr0[3:0]!=0 : lyr0[2:0]!=0) ? lyr0 : (
               (lyr1[10] ? lyr1[3:0]!=0 : lyr1[2:0]!=0) ? lyr1 : (
               (lyr2[10] ? lyr2[3:0]!=0 : lyr2[2:0]!=0) ? lyr2 : (
                lyr3 )));
    active   = (lyr0[10] ? lyr0[3:0]!=0 : lyr0[2:0]!=0) ? 4'b001 : (
               (lyr1[10] ? lyr1[3:0]!=0 : lyr1[2:0]!=0) ? 4'b010 : (
               (lyr2[10] ? lyr2[3:0]!=0 : lyr2[2:0]!=0) ? 4'b100 : (
                4'b0 )));
    if( pal_addr[10] ) active=4'b1000; // OBJ
    { sb, sa, fix } = active[2:0];
end

endmodule