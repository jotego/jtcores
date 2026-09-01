/* SPDX-License-Identifier: GPL-3.0-or-later */

// FPGA-native form of the J9 74LS273 boundary.  The PCB clocks this latch
// from ~M6; the game wrapper supplies the corresponding synchronous enable.
// The enable-to-edge relationship remains an integration assumption until a
// board capture is available.
module jtmoomsa_obj_meta_latch(
    input             clk,
    input             rst,
    input             cen,
    input      [4:0]  prio_in,
    input      [1:0]  shd_in,
    output reg [4:0]  prio_out,
    output reg [1:0]  shd_out
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        prio_out <= 5'd0;
        shd_out  <= 2'd0;
    end else if (cen) begin
        prio_out <= prio_in;
        shd_out  <= shd_in;
    end
end

endmodule
