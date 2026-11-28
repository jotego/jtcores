// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
`default_nettype none

// Main normally brackets every FPGA load with an explicit reset command.
// A freshly JTAG-loaded core must also be able to start when the HPS has not
// booted yet, for example while commissioning a board with a blank SD card.
module de25_mister_reset_control #(
    parameter integer STANDALONE_RELEASE_CYCLES = 1_000_000,
    parameter bit     ALLOW_STANDALONE_RELEASE = 1'b1
) (
    input  wire       clk_sys,
    input  wire       fabric_reset_request,
    input  wire       hps_reset_request,
    input  wire [1:0] core_reset_state,
    output logic      reset_request = 1'b1
);
    localparam integer RELEASE_COUNT_WIDTH =
        (STANDALONE_RELEASE_CYCLES < 2) ? 1 :
        $clog2(STANDALONE_RELEASE_CYCLES);

    logic [RELEASE_COUNT_WIDTH-1:0] release_count = '0;
    logic main_reset_command_seen = 1'b0;
    (* ASYNC_REG = "TRUE" *) logic [1:0] hps_reset_pipe = 2'b11;

    always_ff @(posedge clk_sys or posedge fabric_reset_request) begin
        if (fabric_reset_request)
            hps_reset_pipe <= 2'b11;
        else
            hps_reset_pipe <= {hps_reset_pipe[0], hps_reset_request};
    end

    always_ff @(posedge clk_sys or posedge fabric_reset_request) begin
        if (fabric_reset_request) begin
            reset_request          <= 1'b1;
            release_count          <= '0;
            main_reset_command_seen <= 1'b0;
        end else if (hps_reset_pipe[1] && main_reset_command_seen) begin
            // Once Main owns reset sequencing, an HPS reset holds the core
            // until the restarted service sends another release command.
            reset_request <= 1'b1;
        end else if (core_reset_state == 2'd1) begin
            // Main command 01 asserts reset.
            reset_request          <= 1'b1;
            main_reset_command_seen <= 1'b1;
        end else if (core_reset_state == 2'd2) begin
            // Main command 10 releases reset.
            reset_request          <= 1'b0;
            main_reset_command_seen <= 1'b1;
        end else if (ALLOW_STANDALONE_RELEASE &&
                     !main_reset_command_seen && reset_request) begin
            if (release_count == STANDALONE_RELEASE_CYCLES - 1)
                reset_request <= 1'b0;
            else
                release_count <= release_count + 1'b1;
        end
    end
endmodule

`default_nettype wire
