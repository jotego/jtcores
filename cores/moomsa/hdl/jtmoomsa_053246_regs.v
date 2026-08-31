/* SPDX-License-Identifier: GPL-3.0-or-later */

// CPU-visible K053246/K053247 register boundary.  The sprite producer is
// deliberately outside this module until its Moo-specific DMA and ROM phase
// are proven from the board.
module jtmoomsa_053246_regs(
    input             clk,
    input             rst,
    input             cpu_cs,
    input             cpu_wr,
    input             cpu_rd,
    input      [3:0]  cpu_addr,
    input      [15:0] cpu_din,
    input      [1:0]  cpu_dsn,
    output reg [15:0] cpu_dout,
    output reg [7:0]  cfg,
    output reg [9:0]  xoffset,
    output reg [9:0]  yoffset,
    output reg [22:1] rmrd_addr
);

// The top-level address input is already A[4:1], so its low two bits select
// the four 16-bit register pairs in the 8-byte K053246 window.
wire [1:0] reg_addr = cpu_addr[1:0];

// The chip-select-qualified register window does not consume these bits.
/* verilator lint_off UNUSEDSIGNAL */
wire [1:0] cpu_addr_hi_diag = cpu_addr[3:2];
/* verilator lint_on UNUSEDSIGNAL */

always @(*) begin
    cpu_dout = 16'hffff;
    if (cpu_cs && cpu_rd) begin
        case (reg_addr)
            2'd0: cpu_dout = {6'd0,xoffset[9:8],xoffset[7:0]};
            2'd1: cpu_dout = {6'd0,yoffset[9:8],yoffset[7:0]};
            2'd2: cpu_dout = {rmrd_addr[8:1],cfg};
            2'd3: cpu_dout = {2'd0,rmrd_addr[22:17],rmrd_addr[16:9]};
        endcase
    end
end

always @(posedge clk) begin
    if (rst) begin
        cfg       <= 8'h00;
        xoffset   <= 10'h000;
        yoffset   <= 10'h000;
        rmrd_addr <= 22'h000000;
    end else if (cpu_cs && cpu_wr) begin
        case (reg_addr)
            2'd0: begin
                if (!cpu_dsn[1]) xoffset[9:8] <= cpu_din[9:8];
                if (!cpu_dsn[0]) xoffset[7:0] <= cpu_din[7:0];
            end
            2'd1: begin
                if (!cpu_dsn[1]) yoffset[9:8] <= cpu_din[9:8];
                if (!cpu_dsn[0]) yoffset[7:0] <= cpu_din[7:0];
            end
            2'd2: begin
                if (!cpu_dsn[1]) rmrd_addr[8:1] <= cpu_din[15:8];
                if (!cpu_dsn[0]) cfg <= cpu_din[7:0];
            end
            2'd3: begin
                if (!cpu_dsn[1]) rmrd_addr[22:17] <= cpu_din[13:8];
                if (!cpu_dsn[0]) rmrd_addr[16:9] <= cpu_din[7:0];
            end
        endcase
    end
end

endmodule
