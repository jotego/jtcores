/*  This file is part of JT_FRAME.
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
    Date: 10-5-2021 */

module jtframe_volume(
    input            rst,
    input            clk,
    input            vs,
    input            up,
    input            down,
    output reg [7:0] vol
);

reg lock, vs_l;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        vol  <= 8'h40;
        vs_l <= 0;
        lock <= 0;
    end else begin      
        vs_l <= vs;  
        if( !lock ) begin
            if( ~&vol && up   ) vol <= vol+8'd1;
            if(  |vol && down ) vol <= vol-8'd1;
            lock <= 1;
        end
        if( vs && !vs_l ) lock <= 0;
    end
end

endmodule