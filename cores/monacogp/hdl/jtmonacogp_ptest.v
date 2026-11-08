// SPDX-License-Identifier: GPL-3.0-or-later
// Test stimulus for the sheet G player-car path. NOT original circuitry.
// It stands in for sheets A, D, F and H, which are not implemented yet:
// fixed PL-H-ST/PL-V-ST positions, a VS-driven frame counter for the Vs/n
// taps, and four selectable input states. Every value here is a test choice.
module jtmonacogp_ptest(
    input            clk, rst, pxl_cen,
    input      [8:0] h, v,
    input            vs,
    input            next_n, prev_n,    // buttons, active low
    output reg [1:0] state,             // 0 normal, 1 slide, 2 accident, 3 explosion
    output reg [4:0] frame,             // stands in for the sheet H IC79/IC78 counter
    output           pl_h_st, pl_v_st,
    output           coin_in_n, explo_st, explo_st_n, acc1_n, home_pos_n,
    output           extend_n, gravel_n, slide_n,
    output           vs4, vs8, vs16, vs32,
    output           ic51_3
);
    // One-pixel pulses: PL-H-ST at x=35 on every line, PL-V-ST at x=0, y=56.
    // With the traced counters the car window is x=164..195, y=104..135.
    localparam [8:0] PLH_H = 9'h0bb, PLV_H = 9'h098, PLV_V = 9'd72;
    // Slide state: an oil-slick patch (/SLIDE low) at x=166..171, y=116..121,
    // across the left of the straight car's body.
    localparam [8:0] SLICK_H0 = 9'h13e, SLICK_H1 = 9'h143, SLICK_V0 = 9'd132, SLICK_V1 = 9'd137;
    localparam [1:0] NORMAL = 2'd0, SLIDE = 2'd1, ACCIDENT = 2'd2, EXPLOSION = 2'd3;

    reg       next_l, prev_l, vs_l;
    reg [1:0] request;

    assign pl_h_st    = h == PLH_H;
    assign pl_v_st    = v == PLV_V && h == PLV_H;
    // Frame-counter taps: Vs/2 = frame[0], Vs/4 = frame[1] ... Vs/32 = frame[4].
    assign vs4        = frame[1];
    assign vs8        = frame[2];
    assign vs16       = frame[3];
    assign vs32       = frame[4];
    assign coin_in_n  = 0;                       // game in progress
    assign home_pos_n = 1;
    assign extend_n   = 1;
    assign gravel_n   = 1;
    assign ic51_3     = 1;                       // undrawn TTL input floats high
    assign acc1_n     = state != ACCIDENT;
    assign explo_st   = state == EXPLOSION;
    assign explo_st_n = ~explo_st;
    assign slide_n    = !(state == SLIDE && v >= SLICK_V0 && v <= SLICK_V1 &&
                          h >= SLICK_H0 && h <= SLICK_H1);

    always @(posedge clk) begin
        if (rst) begin
            state   <= NORMAL;
            request <= NORMAL;
            frame   <= 0;
            next_l  <= 1;
            prev_l  <= 1;
            vs_l    <= 0;
        end else begin
            next_l <= next_n;
            prev_l <= prev_n;
            if (next_l && !next_n) request <= request + 2'd1;
            else if (prev_l && !prev_n) request <= request - 2'd1;
            if (pxl_cen) begin
                vs_l <= vs;
                // The state changes only at the end of VS, between frames.
                if (vs_l && !vs) begin
                    frame <= frame + 5'd1;
                    state <= request;
                end
            end
        end
    end
endmodule
