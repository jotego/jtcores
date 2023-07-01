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
    Date: 22-6-2022 */

module jtframe_paddle(
    input              rst,
    input              clk,
    input signed [8:0] mouse_dx,
    input              mouse_st,
    input        [7:0] hw_paddle,   // hardware paddle that might be connected
    output reg   [7:0] paddle
);
`ifdef JTFRAME_PADDLE_MAX
    localparam [7:0] PADDLE_MAX = `JTFRAME_PADDLE_MAX;
`else
    localparam [7:0] PADDLE_MAX = 0;
`endif

`ifdef JTFRAME_PADDLE_SENS
    localparam PADDLE_SENS = `JTFRAME_PADDLE_SENS;
`else
    localparam PADDLE_SENS = 0;
`endif

reg  [8:0] nx_x;
reg  [7:0] hwpadl;

always @* begin
    nx_x = paddle + mouse_dx;
    // check overflow
    if( nx_x[8] ) begin
        nx_x = mouse_dx[8] ? 9'd0 : {1'b0,PADDLE_MAX};
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        paddle <= 0;
        hwpadl <= 0;
    end else begin
        hwpadl <= hw_paddle;
        if( hwpadl != hw_paddle )   // if the hardware paddle is used, follow it
            paddle <= hw_paddle;
        else if( mouse_st )         // but the mouse can be used too
            paddle <= nx_x[7:0] >= PADDLE_MAX ? PADDLE_MAX : nx_x[7:0];
    end
end
endmodule
