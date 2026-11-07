/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-12-2020 */

module jtframe_rom_sync(
    input       clk,
    input       rdy_in,
    input       ack_in,
    output      rdy_out,
    output      ack_out
);

reg last_rdy, last_ack;

assign rdy_out = rdy_in & last_rdy;
assign ack_out = ack_in & last_ack;

always @(posedge clk) begin
    last_rdy <= rdy_in;
    last_ack <= ack_in;
end

endmodule
