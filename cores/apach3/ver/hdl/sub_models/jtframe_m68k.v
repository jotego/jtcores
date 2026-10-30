/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
module jtframe_m68k(
    input clk, rst, cpu_cen, cpu_cenb, BERRn, VPAn, BGACKn, HALTn,
    output RESETn,
    output [23:1] eab,
    output ASn, LDSn, UDSn, eRWn,
    input DTACKn,
    input [15:0] iEdb,
    output [15:0] oEdb,
    input BRn,
    output BGn,
    input [2:0] IPLn,
    output [2:0] FC
);
assign RESETn=1;
assign eab=0;
assign ASn=1;
assign LDSn=1;
assign UDSn=1;
assign eRWn=1;
assign oEdb=0;
assign BGn=1;
assign FC=0;
endmodule
