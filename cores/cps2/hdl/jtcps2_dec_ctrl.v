/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-1-2021 */

module jtcps2_dec_ctrl(
    input             clk,
    input             rom_ok,
    output            rom_ok_out,

    input      [15:0] range,
    input      [23:1] addr,
    input      [ 2:0] fc,
    input             en,

    input      [15:0] din,
    input      [15:0] dec,
    output reg [15:0] dout
);

reg en_latch;
reg [1:0] ok_sh;

assign rom_ok_out = ok_sh[0];

wire op_fetch = fc[1:0]==2'b10;

always @(posedge clk) begin
    en_latch <= op_fetch && en && (addr[14+:10] <= range[9:0]);
    ok_sh    <= { ok_sh[0], rom_ok };
    dout     <= en_latch ? dec : din;
end

endmodule