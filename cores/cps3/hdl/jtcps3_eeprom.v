/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-2-2026 */

module jtcps3_eeprom(
    input              rst,
    input              clk,
    input              cs,
    input              rd,
    input              wr,
    input      [11:0]  addr,
    input      [31:0]  din,
    input      [ 3:0]  we_n,
    output     [ 6:2]  mem_addr,
    output     [31:0]  mem_din,
    output     [ 3:0]  mem_we,
    input      [31:0]  mem_dout,
    output     [31:0]  dout
);

reg  [15:0] latch;
reg         wr_seen;
reg         rd_seen;
reg         latch_pending;
reg         latch_half;

wire        store_cs   = addr[11:7] == 5'b00001; // 0x080-0x0ff
wire        latch_cs   = addr[11:7] == 5'b00010; // 0x100-0x17f
wire        data_cs    = addr[11:2] == 10'h080;  // 0x200-0x203
wire [ 4:0] word_index = addr[6:2];
wire [15:0] latch_data = latch_half ? mem_dout[15:0] : mem_dout[31:16];
wire [15:0] dout16     = data_cs && addr[1] ? latch : 16'd0;
wire [ 3:0] store_we_hi = { ~we_n[1], ~we_n[0], 2'b00 };
wire [ 3:0] store_we_lo = { 2'b00, ~we_n[1], ~we_n[0] };

assign mem_addr = word_index;
assign mem_din  = addr[1] ? { 16'd0, din[15:0] } : { din[15:0], 16'd0 };
assign mem_we   = cs && wr && store_cs && !wr_seen ? (addr[1] ? store_we_lo : store_we_hi) : 4'd0;

assign dout = { 16'd0, dout16 };

always @(posedge clk) begin
    if (rst) begin
        latch         <= 16'd0;
        wr_seen       <= 1'b0;
        rd_seen       <= 1'b0;
        latch_pending <= 1'b0;
        latch_half    <= 1'b0;
    end else begin
        if (!cs || !wr) wr_seen <= 1'b0;
        if (!cs || !rd) rd_seen <= 1'b0;

        if (cs && wr && !wr_seen) begin
            wr_seen <= 1'b1;
        end

        if (cs && rd && !rd_seen) begin
            rd_seen <= 1'b1;
            if (latch_cs) begin
                latch_pending <= 1'b1;
                latch_half    <= addr[1];
            end
        end

        if (latch_pending) begin
            latch         <= latch_data;
            latch_pending <= 1'b0;
        end
    end
end

endmodule
