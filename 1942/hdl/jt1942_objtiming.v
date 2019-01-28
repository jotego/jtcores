/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-1-2019 */

// 1942 Object Generation
    
module jt1942_objtiming(
    input              rst,
    input              clk,
    input              cen6,    //  6 MHz
    // screen
    input              HINIT,
    output reg [3:0]   pxlcnt,
    output reg         line
);


always @(posedge clk) if(cen6) begin
    if( HINIT ) 
        pxlcnt <= 4'd0;
    else 
        pxlcnt  <=  pxlcnt + 4'd1;
end

always @(posedge clk) 
    if( rst )
        line <= 1'b0;
    else if(cen6) begin
        if( HINIT ) line <= ~line;
    end

endmodule // jt1942_obj