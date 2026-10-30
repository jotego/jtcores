/* SPDX-License-Identifier: GPL-3.0-or-later */
// Input-only observation: bits {WDCK,FRDT,DTCK,LRCK}.
// format[0]: sample falling corrected DTCK; format[1]: delay LRCK one bit.
module c96_pcm_sampler(
    input             clk,
    input             rst,
    input             clear,
    input      [3:0]  pins,
    input      [3:0]  invert,
    input      [1:0]  format,
    output     [3:0]  pins_raw,
    output reg [15:0] word,
    output reg        word_valid,
    output reg        word_channel,
    output reg        bad_frame
);

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [3:0] pins_meta, pins_sync;
reg [15:0] shift;
reg [4:0] bit_count;
reg clock_l, lrck_l, phase, tracking, aligned;
wire [3:0] corrected;
wire bit_edge, effective_phase;

assign pins_raw        = pins_sync;
assign corrected       = pins_sync ^ invert;
assign bit_edge        = format[0] ? clock_l && !corrected[1] : !clock_l && corrected[1];
assign effective_phase = format[1] ? lrck_l : corrected[0];

always @(posedge clk) begin
    pins_meta <= pins;
    pins_sync <= pins_meta;
    clock_l <= corrected[1];
end

always @(posedge clk) begin
    word_valid <= 0;
    bad_frame <= 0;
    if (rst || clear) begin
        shift <= 0;
        bit_count <= 0;
        lrck_l <= 0;
        phase <= 0;
        tracking <= 0;
        aligned <= 0;
        word <= 0;
        word_channel <= 0;
    end else if (bit_edge) begin
        lrck_l <= corrected[0];
        if (!tracking) begin
            // An ARM can occur in the middle of a word. Wait for a boundary.
            phase <= effective_phase;
            tracking <= 1;
        end else if (effective_phase != phase) begin
            if (aligned && bit_count != 16) bad_frame <= 1;
            phase <= effective_phase;
            aligned <= 1;
            shift <= {15'd0,corrected[2]};
            bit_count <= 1;
        end else if (aligned) begin
            if (bit_count < 16) begin
                shift <= {shift[14:0],corrected[2]};
                bit_count <= bit_count+5'd1;
                if (bit_count == 15) begin
                    word <= {shift[14:0],corrected[2]};
                    word_channel <= phase;
                    word_valid <= 1;
                end
            end else if (bit_count < 31) bit_count <= bit_count+5'd1;
        end
    end
end

endmodule
