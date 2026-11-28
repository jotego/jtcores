// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
`default_nettype none

// MiSTer-compatible 48 kHz, 16-bit stereo I2S transmitter.
//
// clk_audio is nominally 24.576 MHz. BCLK is clk_audio/16 (1.536 MHz), and
// LRCLK is BCLK/32 (48 kHz). Core samples may originate in another domain, so
// they are accepted only after two consecutive synchronized observations
// agree. Data changes on BCLK falling edges and is stable at rising edges.
module de25_mister_audio_v2 (
    input  wire        clk_audio,
    input  wire        reset,
    input  wire [15:0] core_left,
    input  wire [15:0] core_right,
    input  wire        core_signed,
    output logic       bit_clock,
    output logic       word_clock,
    output logic       serial_data
);
    logic [15:0] left_meta = '0;
    logic [15:0] left_sync = '0;
    logic [15:0] left_stable = '0;
    logic [15:0] right_meta = '0;
    logic [15:0] right_sync = '0;
    logic [15:0] right_stable = '0;
    logic signed_meta = 1'b1;
    logic signed_sync = 1'b1;
    logic signed_stable = 1'b1;

    logic [2:0] clock_divider = '0;
    logic [7:0] bit_count = 8'd1;
    logic [15:0] left_latched = '0;
    logic [15:0] right_latched = '0;

    wire [15:0] converted_left = signed_stable ? left_stable :
        {~left_stable[15], left_stable[14:0]};
    wire [15:0] converted_right = signed_stable ? right_stable :
        {~right_stable[15], right_stable[14:0]};

    always_ff @(posedge clk_audio) begin
        left_meta <= core_left;
        left_sync <= left_meta;
        if (left_meta == left_sync)
            left_stable <= left_sync;

        right_meta <= core_right;
        right_sync <= right_meta;
        if (right_meta == right_sync)
            right_stable <= right_sync;

        signed_meta <= core_signed;
        signed_sync <= signed_meta;
        if (signed_meta == signed_sync)
            signed_stable <= signed_sync;

        if (reset) begin
            clock_divider <= '0;
            bit_count <= 8'd1;
            left_latched <= '0;
            right_latched <= '0;
            bit_clock <= 1'b1;
            word_clock <= 1'b1;
            serial_data <= 1'b0;
        end else begin
            clock_divider <= clock_divider + 1'b1;
            if (&clock_divider) begin
                bit_clock <= ~bit_clock;
                // The old high level identifies the high-to-low transition.
                if (bit_clock) begin
                    if (bit_count >= 8'd16) begin
                        bit_count <= 8'd1;
                        word_clock <= ~word_clock;
                        if (word_clock) begin
                            left_latched <= converted_left;
                            right_latched <= converted_right;
                        end
                    end else begin
                        bit_count <= bit_count + 1'b1;
                    end

                    // Standard I2S changes LRCLK with the final bit of the
                    // preceding channel. The next falling edge presents the
                    // new channel's MSB for capture on the following rise.
                    serial_data <= word_clock ?
                        right_latched[16 - bit_count] :
                        left_latched[16 - bit_count];
                end
            end
        end
    end
endmodule

`default_nettype wire
