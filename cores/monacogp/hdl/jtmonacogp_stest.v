// SPDX-License-Identifier: GPL-3.0-or-later
// Test stimulus for the road and scenery view (sheets B and D). NOT original
// circuitry. It stands in for sheets A, C, H and I, which are not implemented
// yet: a VS-driven frame counter for the Vs/n taps, SP, /IN RESET, the coin
// and game lines, EXTEND and the S-100 code. Every value here is a test choice.
module jtmonacogp_stest(
    input            clk, rst, pxl_cen,
    input            vs,
    input            enable,            // the view is on screen; buttons act only then
    input      [5:0] joy_n,             // {B2, B1, up, down, left, right}, active low
    output reg [3:0] s100,              // S-100-D..A (sheet I)
    output reg [3:0] sp,                // SP.D..A (sheet H)
    output reg       in_reset_n,        // /IN RESET (sheet A)
    output reg [4:0] frame,             // stands in for the sheet H frame counter
    output           vs2, vs4, vs16,
    output           coin_in_n,         // /COIN IN, both pads (sheet A)
    output           ex_signal_n,       // /EX. SIGNAL (sheet A)
    output           game_n,            // /GAME (sheet A)
    output           extend             // EXTEND (sheet C)
);
    reg [5:0] joy_l;
    reg       vs_l;
    reg [3:0] code;                     // index into the S-100 values below
    wire [5:0] press = joy_l & ~joy_n & {6{enable}};

    // Frame-counter taps: Vs/2 = frame[0], Vs/4 = frame[1], Vs/16 = frame[3].
    assign vs2 = frame[0];
    assign vs4 = frame[1];
    assign vs16 = frame[3];
    // A game in progress, with extended play available: the state flip-flops
    // are not held clear and take EXTEND = 1. Sheet B shows EXTENDED PLAY.
    assign coin_in_n   = 0;
    assign ex_signal_n = 1;
    assign game_n      = 0;
    assign extend      = 1;

    always @(posedge clk) begin
        if (rst) begin
            joy_l <= 6'h3f;
            vs_l <= 0;
            frame <= 0;
            code <= 4'd10;
            s100 <= 4'hf;
            sp <= 4'd0;
            in_reset_n <= 1;
        end else begin
            joy_l <= joy_n;
            // B1 and B2 step through S-100 codes 0..9 and 15 (no output).
            if (press[4]) code <= code == 4'd10 ? 4'd0 : code + 4'd1;
            else if (press[5]) code <= code == 4'd0 ? 4'd10 : code - 4'd1;
            // Up and down change SP; right and left move the road counters
            // every frame (/IN RESET low) or leave them to VSEL.
            if (press[3] && sp != 4'd15) sp <= sp + 4'd1;
            else if (press[2] && sp != 4'd0) sp <= sp - 4'd1;
            if (press[0]) in_reset_n <= 0;
            else if (press[1]) in_reset_n <= 1;
            if (pxl_cen) begin
                vs_l <= vs;
                // The code changes only at the end of VS, between frames.
                if (vs_l && !vs) begin
                    frame <= frame + 5'd1;
                    s100 <= code == 4'd10 ? 4'hf : code;
                end
            end
        end
    end
endmodule
