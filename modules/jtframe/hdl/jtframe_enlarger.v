/* This file is part of JTFRAME.


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
    Date: 13-1-2021

*/

module jtframe_enlarger(
    input      rst,
    input      clk,
    input      cen,
    input      pulse_in,
    output reg pulse_out
);

parameter W=14;

localparam [W-1:0] ZERO={W{1'b0}};

reg  [W-1:0] cnt;
reg  [1:0] pin_s;
wire       psync;

assign psync = pin_s[1];

// synchronizer as pulse_in may come from
// a different domain
always @(posedge clk) begin
    pin_s <= { pin_s[0], pulse_in };
end

always @(posedge clk, posedge rst) begin
    if(rst) begin
        cnt       <= ~ZERO;
        pulse_out <= 0;
    end else begin
        pulse_out <= cnt != ZERO || psync;
        if( psync )
            cnt <= ~ZERO;
        else if( cnt!=ZERO && cen )
            cnt <= cnt - 1'd1;
    end
end


endmodule