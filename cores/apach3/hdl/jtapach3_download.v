/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

module jtapach3_download(
    input      [21:0] prog_addr,
    input      [ 7:0] prog_data,
    input      [ 1:0] prog_ba,
    output     [ 7:0] post_data
);

localparam [31:0] MASTER_GAP1_END   = 32'h10000,
                  MASTER_GAP2_START = 32'h20000,
                  MASTER_GAP2_END   = 32'h30000,
                  SLAVE_GAP_START   = (`SLAVE_START+32'h20000) >> 1,
                  SLAVE_GAP_END     = (`SLAVE_START+32'h40000) >> 1,
                  OKI_GAP_START     = (`OKI_START-`JTFRAME_BA3_START+32'h30000) >> 1,
                  OKI_GAP_END       = (`OKI_START-`JTFRAME_BA3_START+32'h40000) >> 1;

wire [31:0] addr = {10'd0,prog_addr};
wire zero_master = prog_ba == 2'd0 &&
    (addr < MASTER_GAP1_END || (addr >= MASTER_GAP2_START && addr < MASTER_GAP2_END));
wire zero_slave = prog_ba == 2'd0 && addr >= SLAVE_GAP_START && addr < SLAVE_GAP_END;
wire zero_oki = prog_ba == 2'd3 && addr >= OKI_GAP_START && addr < OKI_GAP_END;

assign post_data = zero_master || zero_slave || zero_oki ? 8'h00 : prog_data;

endmodule
