/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-11-2026 */

module jtwrpwrp_ball(
    input            clk,
    input            rst,
    input            pxl_cen,
    input            hs,
    input            vs,
    input      [8:0] h,
    input      [7:0] v,
    input      [7:0] ball_h,
    input      [7:0] ball_v,
    input            ball_on,
    input            osd_flip,
    output           ball,
    output           irq
);

reg [7:0] h_count;
reg count_en, v_active, v_draw, hs_l;
// 3T feeds 4S/4R, 4P and the two halves of 4N.
wire [7:0] v_sum = ball_v + v;
wire [7:0] draw_sum = osd_flip ? ball_v + ~v : v_sum;
wire v_gate = ball_on && !vs;

// 3U, 4W, 4U/4T and 3S feed the horizontal input of 6N.
assign ball = v_draw && count_en && (&h_count[7:2]);

// 4N pin 5 clocks pin 11; BALL ON drives /CLR at pin 13.
jtframe_edge u_irq(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( ~v_active ),
    .clr    ( ~ball_on  ),
    .q      ( irq       )
);

always @(posedge clk) begin
    if (rst) begin
        h_count  <= 0;
        count_en <= 0;
        v_active <= 0;
        v_draw   <= 0;
        hs_l     <= 0;
    end else begin
        hs_l <= hs;
        if (pxl_cen) begin
            if (h[3:0] == 4'd7) count_en <= ~h[8];
            if (hs) h_count <= osd_flip ? 8'hfc - ball_h : ball_h;
            else if (count_en) h_count <= h_count + 1'd1;
        end
        if (hs_l && !hs) begin
            v_active <= v_gate && (&v_sum[7:2]);
            v_draw   <= v_gate && (&draw_sum[7:2]);
        end
    end
end

endmodule
