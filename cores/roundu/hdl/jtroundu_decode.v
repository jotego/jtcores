/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

module jtroundu_decode(
    input      [19:0] addr,
    input             rd,
    input             wr,
    output     [12:0] cs
);

assign cs[ 0] = (rd || wr) && addr[19:15] == 0;
assign cs[ 1] = (rd || wr) && addr[19:14] == 6'h02;
assign cs[ 2] = wr         && (addr & 20'hffffc) == 20'h0c000;
assign cs[ 3] = rd         && (addr & 20'hffffe) == 20'h0d000;
assign cs[ 4] = (rd || wr) && (addr & 20'hffff0) == 20'h0d400;
assign cs[ 5] = wr         && (addr & 20'hffffe) == 20'h0d800;
assign cs[ 6] = wr         && (addr & 20'hffffe) == 20'h0dc00;
assign cs[ 7] = wr         && (addr & 20'hffffe) == 20'h0e000;
assign cs[ 8] = (rd || wr) && addr[19:12] == 8'h0f;
assign cs[ 9] = (rd || wr) && addr[19:16] == 4'h1;
assign cs[10] = (rd || wr) && addr[19:16] == 4'h2;
assign cs[11] = (rd || wr) && addr[19:16] == 4'h3;
assign cs[12] = rd         && addr[19];

endmodule
