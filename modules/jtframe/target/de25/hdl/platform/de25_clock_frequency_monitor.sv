// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
`default_nettype none

// Count asynchronous input-clock edges during a fixed reference-clock window.
// With the default 50,000-cycle window and a 50 MHz reference, count_khz is
// the measured input frequency in kHz. The Gray-code crossing keeps the
// diagnostic non-intrusive when the two board-clock outputs have unrelated
// phase or stop altogether.
module de25_clock_frequency_monitor #(
    parameter integer REF_WINDOW = 50_000,
    parameter integer COUNT_WIDTH = 24
) (
    input  wire                         ref_clk,
    input  wire                         reset_n,
    input  wire                         measured_clk,
    output logic [COUNT_WIDTH-1:0]       count_khz,
    output logic                        sample_toggle
);
    localparam integer WINDOW_WIDTH = $clog2(REF_WINDOW);

    logic [COUNT_WIDTH-1:0] measured_binary = '0;
    logic [COUNT_WIDTH-1:0] measured_gray = '0;

    (* ASYNC_REG = "TRUE" *) logic [COUNT_WIDTH-1:0] gray_meta = '0;
    (* ASYNC_REG = "TRUE" *) logic [COUNT_WIDTH-1:0] gray_sync = '0;
    logic [COUNT_WIDTH-1:0] gray_stable = '0;
    logic [COUNT_WIDTH-1:0] measured_ref;
    logic [COUNT_WIDTH-1:0] previous_count = '0;
    logic [WINDOW_WIDTH-1:0] window_count = '0;
    integer bit_index;

    always_ff @(posedge measured_clk or negedge reset_n) begin
        if (!reset_n) begin
            measured_binary <= '0;
            measured_gray <= '0;
        end else begin
            measured_binary <= measured_binary + 1'b1;
            measured_gray <= measured_binary ^ (measured_binary >> 1);
        end
    end

    always_ff @(posedge ref_clk or negedge reset_n) begin
        if (!reset_n) begin
            gray_meta   <= '0;
            gray_sync   <= '0;
            gray_stable <= '0;
        end else begin
            gray_meta   <= measured_gray;
            gray_sync   <= gray_meta;
            gray_stable <= gray_sync;
        end
    end

    always_comb begin
        measured_ref[COUNT_WIDTH-1] = gray_stable[COUNT_WIDTH-1];
        for (bit_index = COUNT_WIDTH - 2; bit_index >= 0;
             bit_index = bit_index - 1)
            measured_ref[bit_index] =
                measured_ref[bit_index + 1] ^ gray_stable[bit_index];
    end

    always_ff @(posedge ref_clk or negedge reset_n) begin
        if (!reset_n) begin
            count_khz      <= '0;
            previous_count <= '0;
            window_count   <= '0;
            sample_toggle  <= 1'b0;
        end else if (window_count == REF_WINDOW - 1) begin
            count_khz      <= measured_ref - previous_count;
            previous_count <= measured_ref;
            window_count   <= '0;
            sample_toggle  <= ~sample_toggle;
        end else begin
            window_count <= window_count + 1'b1;
        end
    end
endmodule

`default_nettype wire
