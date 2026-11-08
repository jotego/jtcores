// SPDX-License-Identifier: GPL-3.0-or-later
// 180-degree flip of the picture, for monitors turned the other way from the
// cabinet's (OSD Flip screen, JTFRAME_OSD_FLIP). NOT original circuitry: the
// board draws its picture from counters that run with the scan, so it cannot
// draw it the other way round; the flip stores whole frames instead.
// - flip low: the colour passes through, no delay;
// - flip high: the previous frame is read in reverse while the current frame
//   is stored behind it. The picture is one frame late.
// The visible area is 360 x 240 (x = 0..359, y = 0..239 while active).
module jtmonacogp_flip(
    input             clk, rst,
    input             pxl_cen,
    input             flip,
    input             active,           // x, y in the visible area
    input       [8:0] x, y,
    input             vb,               // vertical blanking: the frame ends
    input      [11:0] rgb_in,
    output     [11:0] rgb_out,
    output     [14:0] ram_wr_addr,
    output     [14:0] ram_rd_addr,
    output     [47:0] ram_data,
    output      [1:0] ram_we,
    input      [47:0] ram_q
);
    localparam integer W = 360, H = 240;
    reg         reverse, vb_l, started, valid;
    reg  [16:0] wa;
    wire        wr = pxl_cen && active && flip;
    reg         wr_d;
    reg  [11:0] rgb_l;
    reg  [47:0] pixels, pending_data;
    reg  [14:0] pending_addr;
    reg   [3:0] delay_count;
    reg         pending;
    reg   [1:0] read_pixel;

    always @(posedge clk) begin
        wa <= reverse ? (H-1-y)*W + (W-1-x) : y*W + x;
        wr_d <= wr;
        if (pxl_cen) rgb_l <= rgb_in;
        if (wr_d) begin
            pixels[wa[1:0]*12+:12] <= rgb_l;
            if (wa[1:0] == (reverse ? 2'd0 : 2'd3)) begin
                pending_data <= pixels;
                pending_data[wa[1:0]*12+:12] <= rgb_l;
                pending_addr <= wa[16:2];
                pending <= 1'b1;
                delay_count <= 4'd8;
            end
        end
        if (pending && delay_count != 0) delay_count <= delay_count - 4'd1;
        if (pending && delay_count == 0) pending <= 1'b0;
        if (rst || !flip) pending <= 1'b0;
        read_pixel <= wa[1:0];
    end

    assign ram_wr_addr = pending_addr;
    assign ram_rd_addr = wa[16:2];
    assign ram_data = pending_data;
    assign ram_we = {2{pending && delay_count == 0 && flip && !rst}};

    always @(posedge clk) begin
        if (rst) begin
            reverse <= 0; vb_l <= 0; started <= 0; valid <= 0;
        end else begin
            if (!flip) begin
                started <= 0;
                valid <= 0;
            end
            if (pxl_cen) begin
                vb_l <= vb;
                if (flip) begin
                    if (!vb && vb_l) started <= 1;
                    if (vb && !vb_l) begin
                        reverse <= ~reverse;
                        valid <= started;
                        started <= 0;
                    end
                end
            end
        end
    end
    wire [11:0] pix = ram_q[read_pixel*12+:12];
    assign rgb_out = flip ? (active && valid ? pix : 12'd0) : rgb_in;
endmodule
