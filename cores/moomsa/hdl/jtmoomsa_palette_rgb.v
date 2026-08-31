/* SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps

// Behavioral boundary for the three RGB HM6116 devices behind J3/K054338.
// The FPGA keeps the externally observable 3-bank behavior, not the PCB
// tri-state wiring.  The 68000-visible window follows MAME's xRGB_888
// palette format: four byte positions per entry, with the unused X byte
// retained as zero and R/G/B stored in the three physical SRAM banks.

module jtmoomsa_palette_rgb(
    input             clk,
    input             cpu_cs,
    input             cpu_we,
    input      [1:0]  cpu_dsn,
    input      [12:1] cpu_addr,
    input      [15:0] cpu_din,
    output     [15:0] cpu_dout,
    input             prot_req,
    input      [12:1] prot_addr,
    output     [15:0] prot_dout,
    input      [10:0] video_addr,
    output     [23:0] video_rgb
);

wire [10:0] cpu_entry = prot_req ? prot_addr[12:2] : cpu_addr[12:2];
wire        cpu_word1 = cpu_addr[1];
wire        red_we = cpu_cs && cpu_we && !prot_req && !cpu_word1 && !cpu_dsn[0];
wire        green_we = cpu_cs && cpu_we && !prot_req && cpu_word1 && !cpu_dsn[1];
wire        blue_we = cpu_cs && cpu_we && !prot_req && cpu_word1 && !cpu_dsn[0];

wire [7:0] red_cpu, green_cpu, blue_cpu;
wire [7:0] red_video, green_video, blue_video;

jtframe_dual_ram #(.DW(8),.AW(11)) u_red(
    .clk0(clk), .data0(cpu_din[7:0]), .addr0(cpu_entry), .we0(red_we),
    .q0(red_cpu),
    .clk1(clk), .data1(8'd0), .addr1(video_addr), .we1(1'b0),
    .q1(red_video)
);

jtframe_dual_ram #(.DW(8),.AW(11)) u_green(
    .clk0(clk), .data0(cpu_din[15:8]), .addr0(cpu_entry), .we0(green_we),
    .q0(green_cpu),
    .clk1(clk), .data1(8'd0), .addr1(video_addr), .we1(1'b0),
    .q1(green_video)
);

jtframe_dual_ram #(.DW(8),.AW(11)) u_blue(
    .clk0(clk), .data0(cpu_din[7:0]), .addr0(cpu_entry), .we0(blue_we),
    .q0(blue_cpu),
    .clk1(clk), .data1(8'd0), .addr1(video_addr), .we1(1'b0),
    .q1(blue_video)
);

assign cpu_dout = cpu_word1 ? {green_cpu,blue_cpu} : {8'h00,red_cpu};
assign prot_dout = prot_addr[1] ? {green_cpu,blue_cpu} : {8'h00,red_cpu};
assign video_rgb = {red_video,green_video,blue_video};

endmodule
