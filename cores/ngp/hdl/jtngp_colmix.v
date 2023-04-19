/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. https://patreon.com/jotego
    Version: 1.0
    Date: 23-3-2022 */

module jtngp_colmix(
    input             clk,
    input             pxl_cen,

    input             scr_order,

    input             LHBL,
    input             LVBL,
    output reg        LHBL_dly,
    output reg        LVBL_dly,

    input       [2:0] scr1_pxl,
    input       [2:0] scr2_pxl,
    input       [4:0] obj_pxl,

    output      [3:0] red,
    output      [3:0] green,
    output      [3:0] blue,

    input       [3:0] gfx_en
);

reg  [2:0] pxl;
wire [4:0] pxldly;
wire [1:0] prio = obj_pxl[4:3];
reg  [1:0] lyr;
wire [3:0] raw;
wire scr1_blank = scr1_pxl[1:0]==0 || !gfx_en[0];
wire scr2_blank = scr2_pxl[1:0]==0 || !gfx_en[1];
wire obj_blank  = obj_pxl[1:0]==0 || prio==0 || !gfx_en[3];

wire [3:0] scr_eff = scr_order ? 
    ( !scr2_blank ? {1'b0,scr2_pxl} : {1'b1,scr1_pxl} ) :
    ( !scr1_blank ? {1'b0,scr1_pxl} : {1'b1,scr2_pxl} );

assign raw   = {pxldly[2:0],pxldly[2]};
assign red   = pxldly[4] ? raw : 4'd0; // obj
assign blue  = pxldly[4:3]==1 ? raw : 4'd0; // scr2
assign green = pxldly[4:3]==0 ? raw : 4'd0; // scr1

always @(posedge clk) begin
    // layer mixing
    pxl <= scr_eff[2:0];
    lyr[1] <= 0;
    lyr[0] <= scr_eff[3] ^ scr_order;
    if( !obj_blank ) begin
        lyr[1] <= 1;
        case( prio )
            3: pxl <= obj_pxl[2:0];
            2: if( scr_eff[3] ) pxl <= obj_pxl[2:0];
            1: if( scr_eff[1:0]==0) pxl <= obj_pxl[2:0];
            default: lyr[1] <= 0;
        endcase
    end
end

jtframe_blank #(.DLY(18),.DW(5)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .LHBL_dly   ( LHBL_dly  ),
    .LVBL_dly   ( LVBL_dly  ),
    .preLBL     (           ),
    .rgb_in     ({lyr,pxl}),
    .rgb_out    ( pxldly    )
);


endmodule