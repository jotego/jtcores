/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-6-2022 */

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
    localparam [7:0] PADDLE_MAX = 255;
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

always @(posedge clk) begin
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
