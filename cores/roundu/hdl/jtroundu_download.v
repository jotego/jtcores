/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

module jtroundu_download(
    input      [21:0] prog_addr,
    input      [ 7:0] prog_data,
    input      [ 1:0] prog_ba,
    output     [ 7:0] post_data
);

localparam [31:0] OKI_ZERO_START = (`OKI_START-`JTFRAME_BA3_START+32'h30000) >> 1,
                  OKI_ZERO_END   = (`OKI_START-`JTFRAME_BA3_START+32'h40000) >> 1;

assign post_data = prog_ba == 2'd3 && {10'd0,prog_addr} >= OKI_ZERO_START && {10'd0,prog_addr} < OKI_ZERO_END
                 ? 8'h00 : prog_data;

endmodule
