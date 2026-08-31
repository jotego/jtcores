`timescale 1ns/1ps

// FPGA-native Moo boundary for the K054539. The PCB byte bus and shared
// PCM-ROM handshake are retained; the channel engine is implemented by the
// Moo-local full behavioral device.
module jtmoomsa_054539 (
    input             clk,
    input             cen,
    input             rst,
    input             cpu_cs,
    input             cpu_wr,
    input             cpu_rd,
    input      [9:0]  cpu_addr,
    input      [7:0]  cpu_din,
    output     [7:0]  cpu_dout,
    output            cpu_dout_valid,
    output            sample_req,
    input             sample_accept,
    output     [23:0] sample_addr,
    input      [15:0] sample_data,
    input             sample_ack,
    output     signed [15:0] audio_l,
    output     signed [15:0] audio_r,
    output            audio_valid,
    output     [8:0]  sequence_cycle,
    output     [2:0]  active_channel,
    output     [7:0]  active_flags
);

wire [8:0]  full_addr = {cpu_addr[9],cpu_addr[7:0]};
wire [7:0]  full_dout;
wire        full_rom_cs;
wire [23:0] full_rom_addr;
wire        full_rb_wait;
/* Diagnostic status has no physical E4 board-net consumer in Moo. */
/* verilator lint_off UNUSEDSIGNAL */
wire [7:0]  full_st_dout;
wire        cpu_addr8_diag = cpu_addr[8];
wire [7:0]  sample_data_hi_diag = sample_data[15:8];
wire        full_timeout_diag = full_timeout;
/* verilator lint_on UNUSEDSIGNAL */
wire        full_sample_valid;
wire        full_timeout;
wire [8:0]  full_sequence_cycle;
wire [2:0]  full_active_channel;
wire [7:0]  full_active_flags;

jtmoomsa_k054539_full u_full(
    .rst          (rst),
    .clk          (clk),
    .cen          (cen),
    .timeout      (full_timeout),
    .addr         (full_addr),
    .we           (cpu_wr),
    .rd           (cpu_rd),
    .cs           (cpu_cs),
    .din          (cpu_din),
    .dout         (full_dout),
    .rom_cs       (full_rom_cs),
    .rom_addr     (full_rom_addr),
    .rb_wait      (full_rb_wait),
    .rom_data     (sample_data[7:0]),
    .rom_ok       (sample_ack),
    .left         (audio_l),
    .right        (audio_r),
    .sample_valid (full_sample_valid),
    .sequence_cycle(full_sequence_cycle),
    .active_channel(full_active_channel),
    .active_flags (full_active_flags),
    .debug_bus    (8'd0),
    .st_dout      (full_st_dout)
);

assign cpu_dout       = full_dout;
assign cpu_dout_valid = cpu_cs && cpu_rd && !full_rb_wait;
assign sample_req     = full_rom_cs;
assign sample_addr    = full_rom_addr;
assign audio_valid    = full_sample_valid;
assign sequence_cycle = full_sequence_cycle;
assign active_channel = full_active_channel;
assign active_flags   = full_active_flags;

// Retained for the established Moo SDRAM wrapper contract. The device holds
// one request until sample_ack; the current wrapper does not need this input.
wire unused_sample_accept = sample_accept;

endmodule
