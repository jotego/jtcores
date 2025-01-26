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
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 03-05-2024 */

// Makes blanking signals shorter
// This is used when the game software draws black frames around the
// image. Shortening the blanking signals will cause MiSTer/Pocket
// platforms to crop the black frames
module jtframe_short_blank #(parameter WIDTH=511, HEIGHT=264) (
    input   clk,
    input   pxl_cen,
    input   LHBL,
    input   LVBL,
    input   HS,

    input   h_en,   // HB shortening enable
    input   v_en,   // VB enable
    input   wide,   // 8 or 16 pixels (per side)

    output  hb_out, // shortened outputs
    output  vb_out
);

reg [5:0] clip;
reg [5:0] max_pxl_count;
reg [7:0] ln_count=0;
reg [8:0] ln_count2=0, max_ln_count2;
reg [8:0] max_pxl_count2;
reg [8:0] pxl_count=0;
reg       lhbs, lvbs;
reg       last_hb=0, last_vb=0, last_hs=0;

assign hb_out = !h_en ? LHBL : lhbs;
assign vb_out = !v_en ? LVBL : lvbs;

always @(*) begin
    clip           = wide ? 6'd16 : 6'd8;
    max_pxl_count  = clip-6'd2;
    max_pxl_count2 = WIDTH[8:0] -{3'b0, clip}-9'd2;
    max_ln_count2  = HEIGHT[8:0]-{3'b0, clip}-9'd2;
end

always @(posedge clk) if(pxl_cen) begin
    last_hb    <= LHBL;
    pxl_count  <= pxl_count  + 1'b1;
    if( LHBL && !last_hb) pxl_count  <= 0;
    if(pxl_count     ==max_pxl_count2)        lhbs <= 0;
    if(pxl_count[5:0]==max_pxl_count && LHBL) lhbs <= 1;
end

always @(posedge clk) begin
    last_hs <= HS;
    if(HS) last_vb <= LVBL;
    if(HS && !last_hs) begin
        ln_count  <= ln_count +  1'b1;
        ln_count2 <= ln_count2 + 1'b1;
        if( LVBL && !last_vb) ln_count  <= 0;
        if(!LVBL &&  last_vb) ln_count2 <= 0; 
        if(ln_count2==max_ln_count2)               lvbs <= 0;
        if(ln_count=={2'b0,max_pxl_count} && LVBL) lvbs <= 1;
    end      
end

endmodule