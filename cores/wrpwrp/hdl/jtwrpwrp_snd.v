/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-11-2026 */

module jtwrpwrp_snd(
    input            clk,
    input            rst,
    input            pxl_cen,
    input            audio_cen,
    input            effects_wr,
    input            music1_wr,
    input            music2_wr,
    input      [5:0] din,
    input      [4:0] h,
    input      [6:0] v,
    output    [15:0] effects,
    output    [15:0] music
);

localparam [9:0] PULSE_TICKS = 10'd527;
localparam [30:0] FULL_CHARGE = {15'h7fff, 16'd0};

reg [3:0] effects_latch, music_phase;
reg [5:0] music1, music2;
reg [7:0] divider;
reg [15:0] noise;
reg old_2v;
reg [9:0] effects_pulse, music_pulse;
reg [30:0] cap_c90, cap_c95;

// 5W/5V and 4M feed 5T and 6J.
wire [7:0] tones = {noise[15], v[6] & v[2], v[5] & v[1], v[4] & v[0], v[5:2]};
wire effects_gate = ~tones[effects_latch[2:0]];

// 5A, 7B/7A and 4K clock 7C; 5B and 7C feed 7D.
wire [3:0] music_gates = music_phase & ~music2[3:0];
wire [2:0] music_slots = music2[5] && noise[15] ? 3'd4 :
    {2'd0, music_gates[0]} + {2'd0, music_gates[1]} +
    {2'd0, music_gates[2]} + {2'd0, music_gates[3]};

// 5U/5T, 7R and 7P drive C90 and R93.
wire [30:0] effects_r87 = (cap_c90 >> 10) - (cap_c90 >> 15);
wire [30:0] effects_r93 = (cap_c90 >> 13) + (cap_c90 >> 14);
wire [30:0] effects_loss = (effects_latch[3] ? effects_r87 : 31'd0) +
    (effects_gate ? effects_r93 : 31'd0);

// 5B/7D, 6J, 7R and 7E drive C95 and R92.
wire [30:0] music_r14 = (cap_c95 >> 15) + (cap_c95 >> 17) +
    (cap_c95 >> 18) + (cap_c95 >> 19);
wire [30:0] music_r92 = (cap_c95 >> 15) + (cap_c95 >> 18) + (cap_c95 >> 19);
wire [30:0] music_held = (music_r92 * music_slots) >> 2;
wire [30:0] music_loss = music_r14 + music_held + (music2[4] ? rc22k10u(cap_c95) : 31'd0);
wire [30:0] music_charge = music_pulse != 0 ? rc22k10u(FULL_CHARGE - cap_c95) : 31'd0;

assign effects = effects_gate ? {1'b0, cap_c90[30:16]} : 16'd0;
assign music   = cap_c95[30:18] * music_slots;

function [30:0] rc22k10u(input [30:0] level);
    rc22k10u = (level >> 14) + (level >> 15) + (level >> 18) - (level >> 20);
endfunction

always @(posedge clk) begin
    if (rst) begin
        effects_latch <= 0;
        music1        <= 0;
        music2        <= 0;
        divider       <= 0;
        music_phase   <= 0;
        noise         <= 0;
        old_2v        <= 0;
        effects_pulse <= 0;
        music_pulse   <= 0;
        cap_c90       <= 0;
        cap_c95       <= 0;
    end else begin
        if (effects_wr) effects_latch <= din[3:0];
        if (music1_wr)  music1 <= din;
        if (music2_wr)  music2 <= din;

        old_2v <= v[1];
        if (effects_wr) noise <= 0;
        else if (v[1] && !old_2v) noise <= {noise[14:0], noise[0] ^ ~noise[14]};

        if (pxl_cen && h == 5'd15) begin
            divider <= (&divider) ? {music1, 2'b00} : divider + 1'd1;
            if (divider == 8'hfe) music_phase <= music_phase + 1'd1;
        end

        if (effects_wr && effects_pulse == 0) begin
            effects_pulse <= PULSE_TICKS;
            cap_c90       <= FULL_CHARGE;
        end else if (audio_cen) begin
            if (effects_pulse != 0) effects_pulse <= effects_pulse - 1'd1;
            else cap_c90 <= cap_c90 - effects_loss;
        end

        if (music2_wr && music_pulse == 0) music_pulse <= PULSE_TICKS;
        else if (audio_cen && music_pulse != 0) music_pulse <= music_pulse - 1'd1;
        if (audio_cen) cap_c95 <= cap_c95 + music_charge - music_loss;
    end
end

endmodule
