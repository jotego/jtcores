/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 14-10-2026 */

module jtpopeye_prot(
    input            rst,
    input            clk,
    input            reset_n,
    input            cs,
    input            we,
    input            addr,
    input      [7:0] din,
    output     [7:0] dout
);

wire [15:0] pair, shifted;
wire        wr;
reg  [ 7:0] d0, d1;
reg  [ 2:0] sh;
reg         wr_l;

assign wr      = cs & we;
assign pair    = { d1, d0 };
assign shifted = pair << sh;
assign dout    = addr ? shifted[15:8] : 8'hf8;

always @(posedge clk) begin
    if( rst || !reset_n ) begin
        d0   <= 0;
        d1   <= 0;
        sh   <= 0;
        wr_l <= 0;
    end else begin
        wr_l <= wr;
        if( wr && !wr_l ) begin
            if( addr ) begin
                sh <= din[2:0];
            end else begin
                d0 <= d1;
                d1 <= din;
            end
        end
    end
end

endmodule
