/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 06-11-2026 */

module jtgeebee_snd(
    input                    clk,
    input                    rst,
    input                    pxl_cen,
    input                    audio_cen,
    input                    wr,
    input             [7:0]  din,
    input             [7:0]  v,
    output reg signed [15:0] snd
);

localparam [9:0] PULSE_TICKS = 10'd527; // 5L: ln(3) * R24 * C57 at 48 kHz
localparam [30:0] FULL_CHARGE = {15'h7fff, 16'd0};

reg [3:0] latch;
reg [9:0] pulse;
reg [15:0] noise;
reg [1:0] old_v;
reg [30:0] cap_c33;
reg [22:0] cap_c56;
wire [7:0] sources;

assign sources[0] = v[2];
assign sources[1] = v[3];
assign sources[2] = v[4];
assign sources[3] = v[5];
assign sources[4] = ~(v[0] | v[4]);
assign sources[5] = ~(v[1] | v[5]);
assign sources[6] = ~(v[2] | v[6]);
assign sources[7] = noise[15];
wire tone = ~sources[latch[2:0]]; // 4R pin 6 (W) drives 6N-B
wire charging = pulse != 0;

// C33 discharges through R50 with 6N-C closed, or through R49 and the 10k pot with 6N-B closed.
wire [30:0] r50_loss = (cap_c33 >> 10) - (cap_c33 >> 15);
wire [30:0] r49_loss = (cap_c33 >> 13) + (cap_c33 >> 14);
wire [30:0] envelope_loss = (latch[3] ? r50_loss : 31'd0) + (tone ? r49_loss : 31'd0);

wire [22:0] gated = tone ? cap_c33[30:8] : 23'd0;
wire signed [23:0] ac = $signed({1'b0, gated}) - $signed({1'b0, cap_c56});
wire [22:0] ac_level = ac[23] ? -ac[22:0] : ac[22:0];
wire [22:0] c56_step = (ac_level >> 7) + (ac_level >> 8) + (ac_level >> 9);
wire signed [15:0] amplitude = $signed({1'b0, ac_level[22:8]});

always @(posedge clk or posedge rst) begin
    if (rst) begin
        latch   <= 0;
        pulse   <= 0;
        noise   <= 0;
        old_v   <= 0;
        cap_c33 <= 0;
        cap_c56 <= 0;
        snd     <= 0;
    end else begin
        if (pxl_cen)
            old_v <= v[1:0];
        if (wr) begin
            latch <= din[3:0];
            noise <= 0;
        end else if (pxl_cen && v[1:0] == 2'b10 && old_v != 2'b10) begin
            noise <= {noise[14:0], noise[0] ^ ~noise[14]};
        end

        if (wr && !charging) begin
            pulse   <= PULSE_TICKS;
            cap_c33 <= FULL_CHARGE;
        end else if (audio_cen) begin
            if (charging)
                pulse <= pulse - 1'd1;
            else
                cap_c33 <= cap_c33 - envelope_loss;
        end
        if (audio_cen) begin
            cap_c56 <= ac[23] ? cap_c56 - c56_step : cap_c56 + c56_step;
            snd     <= ac[23] ? -amplitude : amplitude;
        end
    end
end

endmodule
