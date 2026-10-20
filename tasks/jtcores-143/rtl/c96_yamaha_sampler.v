/* SPDX-License-Identifier: GPL-3.0-or-later */
// Oversample SO using the measured separation of alternating SH falling edges.
// Input pins have already passed the capture block's common synchronizers.
// bits 0/1: SH strobes; bit 2: SO. All polarities are corrected by invert.
// A 16-bit word starts at one SH falling edge and ends at the other.
// Preserve all bits: [2:0] unspecified, [12:3] offset mantissa, [15:13] exponent.
module c96_yamaha_sampler(
    input             clk,
    input             rst,
    input             clear,
    input      [3:0]  pins,
    input      [3:0]  invert,
    output reg [15:0] word,
    output reg        word_valid,
    output reg        word_channel,
    output     [11:0] half_period,
    output reg        bad_frame
);

reg  [15:0] shift;
reg  [12:0] phase;
reg  [11:0] elapsed, span;
reg  [ 4:0] bit_count;
reg  [ 1:0] sh_l;
reg         tracking, locked, active, channel;
wire [ 3:0] corrected;
wire [ 1:0] falling;
wire [12:0] nx_phase;
wire [11:0] interval;
wire        edge_seen, valid_interval;

assign corrected = pins ^ invert;
assign falling = sh_l & ~corrected[1:0];
assign edge_seen = |falling;
assign interval = elapsed + 12'd1;
assign nx_phase = phase + 13'd16;
assign valid_interval = elapsed >= 12'd511 && elapsed < 12'd2048;
assign half_period = span;

always @(posedge clk) begin
    sh_l <= corrected[1:0];
end

always @(posedge clk) begin
    word_valid <= 0;
    bad_frame <= 0;
    if (rst || clear) begin
        shift <= 0;
        phase <= 0;
        elapsed <= 0;
        span <= 0;
        bit_count <= 0;
        tracking <= 0;
        locked <= 0;
        active <= 0;
        channel <= 0;
        word <= 0;
        word_channel <= 0;
    end else begin
        if (elapsed != 12'hfff) elapsed <= interval;
        if (tracking && elapsed == 12'd2048) begin
            bad_frame <= 1;
            tracking <= 0;
            locked <= 0;
            active <= 0;
        end
        if (edge_seen) begin
            elapsed <= 0;
            channel <= falling[1];
            tracking <= 1;
            active <= 0;
            locked <= 0;
            if (tracking) begin
                if (falling == 2'b11 || channel == falling[1] || !valid_interval) begin
                    bad_frame <= 1;
                end else begin
                    if (locked && bit_count != 16) bad_frame <= 1;
                    span <= interval;
                    phase <= {2'b0,interval[11:1]};
                    bit_count <= 0;
                    shift <= 0;
                    active <= 1;
                    locked <= 1;
                end
            end
        end else if (active) begin
            phase <= nx_phase;
            if (nx_phase >= {1'b0,span}) begin
                phase <= nx_phase - {1'b0,span};
                shift <= {corrected[2],shift[15:1]};
                bit_count <= bit_count + 5'd1;
                if (bit_count == 15) begin
                    word <= {corrected[2],shift[15:1]};
                    // Name channels by the SH edge that latches the word.
                    word_channel <= !channel;
                    word_valid <= 1;
                    active <= 0;
                end
            end
        end
    end
end

endmodule
