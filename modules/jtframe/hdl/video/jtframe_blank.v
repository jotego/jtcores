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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 17-05-2020 */

module jtframe_blank #(parameter DLY=4,DW=12)(
    input               clk,
    input               pxl_cen,
    input               preLHBL,
    input               preLVBL,
    output reg          LHBL,
    output reg          LVBL,
    output              preLBL,
    input      [DW-1:0] rgb_in,
    output reg [DW-1:0] rgb_out
);

wire [1:0] predly;

assign preLBL = predly==2'b11;

generate
    if( DLY>1 )
        jtframe_sh #(.W(2),.L(DLY-1)) u_dly(
            .clk    ( clk          ),
            .clk_en ( pxl_cen      ),
            .din    ( {preLHBL, preLVBL} ),
            .drop   ( predly       )
        );
    else
        assign predly = {preLHBL, preLVBL};
endgenerate

generate
    if( DLY > 0 ) begin : latch
        always @(posedge clk) if(pxl_cen) begin
            rgb_out <= predly==2'b11 ? rgb_in : {DW{1'b0}};
            {LHBL, LVBL} <= predly;
        end
    end else begin : comb // DLY==0
        always @(*) begin
            rgb_out = predly==2'b11 ? rgb_in : {DW{1'b0}};
            {LHBL, LVBL} = predly;
        end
    end
endgenerate

endmodule