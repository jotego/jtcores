/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-11-2026 */

module jtwrpwrp_cab(
    input            clk,
    input            rst,
    input            pxl_cen,
    input      [3:0] h,
    input      [8:0] v,
    input            paddle_board,
    input      [7:0] joyana_l1,
    input      [7:0] joyana_l2,
    input      [1:0] dial_x,
    input      [1:0] dial_y,
    input      [4:0] joystick1,
    input      [4:0] joystick2,
    input      [1:0] cab_1p,
    input      [1:0] coin,
    input            credit,
    input            upright,
    input            service_n,
    input            flip,
    output     [7:0] switches,
    output reg [7:0] vol
);

wire [4:0] stick = flip ? joystick2 : joystick1;
localparam [7:0] PADDLE_LOW = 8'h14, PADDLE_CENTER = 8'h60, PADDLE_HIGH = 8'hac;
wire [7:0] dial_pos_1p, dial_pos_2p;
wire [7:0] axis = flip ? joyana_l2 : joyana_l1;
wire [7:0] absolute = {~axis[7], axis[6:0]};
wire [15:0] paddle_scaled = {8'd0, ~absolute} * 16'd153 + 16'd128;
wire [7:0] dial_pos = flip ? dial_pos_2p : dial_pos_1p;
wire [7:0] paddle_threshold = |axis ? PADDLE_LOW + paddle_scaled[15:8] : dial_pos;
wire coin1_n = paddle_board ? coin[0] : &coin;
wire in1 = paddle_board ? coin[1] : joystick2[4];
wire serve_n = joystick1[4] & (!paddle_board || joystick2[4]);
reg [7:0] threshold;
reg cmp_l;
wire cmp = !v[8] && v[7:0] >= threshold;
// Cabinet L/10/M/11/N/12/P/13 feed 6M D7 through D0.
assign switches = {credit, upright, service_n, serve_n, cab_1p, in1, coin1_n};

jtgeebee_dial #(
    .LOW    ( PADDLE_LOW    ),
    .CENTER ( PADDLE_CENTER ),
    .HIGH   ( PADDLE_HIGH   )
) u_dial_1p(
    .clk      ( clk         ),
    .rst      ( rst         ),
    .recenter ( |joyana_l1  ),
    .dial     ( dial_x      ),
    .pos      ( dial_pos_1p )
);

jtgeebee_dial #(
    .LOW    ( PADDLE_LOW    ),
    .CENTER ( PADDLE_CENTER ),
    .HIGH   ( PADDLE_HIGH   )
) u_dial_2p(
    .clk      ( clk         ),
    .rst      ( rst         ),
    .recenter ( |joyana_l2  ),
    .dial     ( dial_y      ),
    .pos      ( dial_pos_2p )
);

always @* begin
    if (paddle_board) threshold = paddle_threshold;
    else if (!stick[2]) threshold = 8'h0f;
    else if (!stick[3]) threshold = 8'h3f;
    else if (!stick[1]) threshold = 8'h6f;
    else if (!stick[0]) threshold = 8'h9f;
    else threshold = 8'hff;
end

// 8M feeds 4W, then 6K strobes 5C/5D.
always @(posedge clk) begin
    if (rst) begin
        cmp_l <= 0;
        vol   <= paddle_board ? PADDLE_CENTER : 8'hff;
    end else if (pxl_cen && h == 4'd7) begin
        cmp_l <= cmp;
        if (cmp && !cmp_l) vol <= v[7:0];
    end
end

endmodule
