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
    Date: 10-5-2021 */

module jtframe_volume(
    input            rst,
    input            clk,
    input            vs,
    input            peak,
    input            up,
    input            down,
    output reg [7:0] vol
);

reg lock, vs_l, peaked;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        vol    <= 8'h80; // matching value in game_test.v
        vs_l   <= 0;
        lock   <= 0;
        peaked <= 0;
    end else begin      
        vs_l <= vs;  
        if(  peak ) peaked <= 1;
        if( !lock ) begin
            if( ~&vol && up && !peaked ) begin
                vol <= vol+8'd1;
            end
            if(  |vol && down ) begin
                vol <= vol-8'd1;
                peaked <= 0;
            end
            lock <= 1;
        end
        if( vs && !vs_l ) lock <= 0;
    end
end

endmodule