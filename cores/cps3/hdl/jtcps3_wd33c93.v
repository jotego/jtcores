/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-4-2026 */

// Stub WD33C93 SCSI controller
module jtcps3_wd33c93(
    input             rst,
    input             clk,
    input             cs,
    input             wr,
    input      [1:0]  addr,
    input      [7:0]  din,
    input      [3:0]  we_n,
    output     [31:0] dout
);

reg  [ 4:0] sel;
reg  [ 7:0] regs[0:31];
reg         wr_seen;

wire        byte_we   = cs && wr && !we_n[0];
wire        addr_lane = addr == 2'b01;
wire        data_lane = addr == 2'b11;
wire [ 7:0] addr_data = regs[5'h1f];
wire [ 7:0] data_data = regs[sel];
wire [ 7:0] read_data = addr_lane ? addr_data :
                         data_lane ? data_data : 8'd0;

assign dout = { 24'd0, read_data };

always @(posedge clk) begin
    integer i;

    if (rst) begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] <= 8'd0;
        regs[5'h1f] <= 8'h80;
        sel         <= 5'h1f;
        wr_seen     <= 1'b0;
    end else begin
        if (!cs || !wr) wr_seen <= 1'b0;

        if (byte_we && !wr_seen) begin
            wr_seen <= 1'b1;
            if (addr_lane) sel       <= din[4:0];
            if (data_lane) regs[sel] <= din;
        end
    end
end

endmodule
