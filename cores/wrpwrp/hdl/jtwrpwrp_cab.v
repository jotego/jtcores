/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-11-2026 */

module jtwrpwrp_cab(
    input            clk,
    input            rst,
    input            pxl_cen,
    input      [3:0] h,
    input      [8:0] v,
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
reg [7:0] threshold;
reg cmp_l;
wire cmp = !v[8] && v[7:0] >= threshold;
// Cabinet L/10/M/11/N/12/P/13 feed 6M D7 through D0.
assign switches = {credit, upright, service_n, joystick1[4],
                   cab_1p, joystick2[4], &coin};

always @* begin
    if (!stick[2]) threshold = 8'h00;
    else if (!stick[3]) threshold = 8'h40;
    else if (!stick[1]) threshold = 8'h80;
    else if (!stick[0]) threshold = 8'hc4;
    else threshold = 8'hff;
end

// 8M feeds 4W, then 6K strobes 5C/5D.
always @(posedge clk) begin
    if (rst) begin
        cmp_l <= 0;
        vol   <= 8'hff;
    end else if (pxl_cen && h == 4'd7) begin
        cmp_l <= cmp;
        if (cmp && !cmp_l) vol <= v[7:0];
    end
end

endmodule
