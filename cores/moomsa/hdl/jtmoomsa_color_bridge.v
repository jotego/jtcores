/* SPDX-License-Identifier: GPL-3.0-or-later */

// Behavioral MCOLR/MCOLRB boundary.  The PCB's G8/G9/H8/H9 muxes and L5/K5
// latches are collapsed here; only their registered external interface is
// retained.
module jtmoomsa_color_bridge(
    input             clk,
    input             rst,
    input             cen,
    input      [10:0] col,
    input             brit,
    input             col_n,
    input       [1:0] sdo,
    output     [10:0] palette_addr,
    output      [1:0] mix_code,
    output      [1:0] shadow_code,
    output      [1:0] bright_code,
    output            color_blank
);

reg [7:0] mcolr;
reg [7:0] mcolrb;

wire [7:0] mcol  = col[7:0];
// H6 combines MCOLB0 with the inverted MCOLB2 before K5 captures the
// high control bit.  The CRAM~CS mux select is not yet separately exposed;
// this preserves the active video COL inputs at the FPGA boundary.
wire       mcolb_a = col[8] & ~col[10];
wire [7:0] mcolb = {mcolb_a,sdo[1],sdo[0],brit,col_n,col[10:8]};

always @(posedge clk) begin
    if (rst) begin
        mcolr  <= 8'h00;
        mcolrb <= 8'h00;
    end else if (cen) begin
        mcolr  <= mcol;
        mcolrb <= mcolb;
    end
end

assign palette_addr = {mcolrb[2:0],mcolr};
assign mix_code     = {1'b0,mcolrb[7]};
assign shadow_code  = {mcolrb[6],mcolrb[5]};
assign bright_code  = {1'b0,mcolrb[4]};
assign color_blank  = mcolrb[3];

endmodule
