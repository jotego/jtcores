// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
`default_nettype none

// Platform-v2 clock boundary. Infrastructure clocks always come from the
// fixed CLOCK0_50 route, so HPS access and recovery survive a missing or
// misconfigured external clock. The Si5332 outputs are measured and exposed
// to personas only after the read-only I2C identification pass succeeds.
module de25_platform_v2_clock_service (
    input  wire         clock0_50,
    input  wire         clock1_si5332,
    input  wire         clock2_si5332,
    input  wire         reset,
    inout  wire         si5332_scl,
    inout  wire         si5332_sda,
    output wire         clk_hps,
    output wire         clk_audio,
    output wire         clk_video,
    output wire         platform_locked,
    output wire         external_clocks_ready,
    output wire [23:0]  clock1_frequency_khz,
    output wire [23:0]  clock2_frequency_khz,
    output wire [31:0]  si5332_probe_status,
    output wire [95:0]  si5332_identity,
    output wire         si5332_identity_valid,
    output wire [6:0]   si5332_address,
    output wire         si5332_fault
);
    wire clock1_sample_toggle;
    wire clock2_sample_toggle;
    wire si5332_present;
    wire [2:0] si5332_fault_code;
    wire profile_valid, profile_write;
    wire [7:0] profile_register, profile_data, profile_read_data;
    wire profile_ready;
    wire profile_done;
    wire profile_error;

    mister_pll infrastructure_pll (
        .refclk_clk(clock0_50),
        .reset_reset(reset),
        .locked_export(platform_locked),
        .outclk0_clk(clk_hps),
        .outclk1_clk(clk_audio),
        .outclk2_clk(clk_video)
    );

    de25_clock_frequency_monitor clock1_monitor (
        .ref_clk(clock0_50),
        .reset_n(~reset),
        .measured_clk(clock1_si5332),
        .count_khz(clock1_frequency_khz),
        .sample_toggle(clock1_sample_toggle)
    );

    de25_clock_frequency_monitor clock2_monitor (
        .ref_clk(clock0_50),
        .reset_n(~reset),
        .measured_clk(clock2_si5332),
        .count_khz(clock2_frequency_khz),
        .sample_toggle(clock2_sample_toggle)
    );

    de25_si5332_service si5332 (
        .clk(clock0_50),
        .reset_n(~reset),
        .scl(si5332_scl),
        .sda(si5332_sda),
        .present(si5332_present),
        .detected_address(si5332_address),
        .identity_valid(si5332_identity_valid),
        .identity(si5332_identity),
        .fault(si5332_fault),
        .fault_code(si5332_fault_code),
        .probe_status(si5332_probe_status),
        .profile_enable(si5332_identity_valid),
        .profile_valid(profile_valid),
        .profile_ready(profile_ready),
        .profile_register(profile_register),
        .profile_data(profile_data),
        .profile_write(profile_write),
        .profile_read_data(profile_read_data),
        .profile_done(profile_done),
        .profile_error(profile_error)
    );

`ifdef DE25_GAME_REF_HZ
    de25_si5332_out0 #(.TARGET_HZ(`DE25_GAME_REF_HZ)) game_clock (
        .clk(clock0_50), .reset(reset),
        .start(si5332_identity_valid && si5332_identity[95:88] == 8'h02 &&
               si5332_identity[78:72] == si5332_address),
        .fault(si5332_fault), .count_khz(clock1_frequency_khz),
        .sample_toggle(clock1_sample_toggle), .clock_ready(external_clocks_ready),
        .valid(profile_valid), .ready(profile_ready), .done(profile_done),
        .write(profile_write), .addr(profile_register), .wdata(profile_data),
        .rdata(profile_read_data)
    );
`else
    assign profile_valid = 1'b0;
    assign profile_write = 1'b0;
    assign profile_register = 0;
    assign profile_data = 0;
    // The counters update once per CLOCK0 reference window. Requiring both a
    // completed identity read and plausible non-zero clocks keeps personas
    // from treating an unconfigured or disconnected source as usable.
    assign external_clocks_ready = si5332_present && si5332_identity_valid &&
        !si5332_fault && (clock1_frequency_khz > 24'd1_000) &&
        (clock2_frequency_khz > 24'd1_000);

`endif

    wire unused = &{1'b0, clock1_sample_toggle, clock2_sample_toggle,
                    si5332_fault_code, profile_ready, profile_done,
                    profile_error};
endmodule

`default_nettype wire
