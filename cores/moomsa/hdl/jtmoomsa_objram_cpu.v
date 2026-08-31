/* SPDX-License-Identifier: GPL-3.0-or-later */

// FPGA-native owner for the proven two-lane 8Kx8 object SRAM pair.
// The two lanes form 8K 16-bit words; DMA and P6 phase controls are separate.
module jtmoomsa_objram_cpu(
    input             clk,
    input             rst,
    input             cs,
    input             cpu_read,
    input       [1:0] ram_we,
    input      [12:0] cpu_addr,
    input      [15:0] cpu_din,
    input      [12:0] dma_addr,
    input             prot_req,
    input      [12:0] prot_addr,
    output     [15:0] cpu_dout,
    output            cpu_dout_valid,
    output     [15:0] prot_dout,
    output     [15:0] dma_dout
);

reg        read_valid;
wire [12:0] owner_addr = prot_req ? prot_addr : cpu_addr;
wire [15:0] owner_dout;
wire  [1:0] owner_we = prot_req ? 2'b00 : ram_we;

always @(posedge clk) begin
    if (rst)
        read_valid <= 1'b0;
    else
        read_valid <= cs && cpu_read && !prot_req;
end

assign cpu_dout_valid = read_valid;
assign cpu_dout = owner_dout;
assign prot_dout = owner_dout;

jtframe_dual_ram16 #(.AW(13)) u_ram(
    .clk0(clk), .data0(cpu_din), .addr0(owner_addr), .we0(owner_we), .q0(owner_dout),
    .clk1(clk), .data1(16'd0), .addr1(dma_addr), .we1(2'b00), .q1(dma_dout)
);

endmodule
