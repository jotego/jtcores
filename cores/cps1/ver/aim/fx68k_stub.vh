/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
// Bus-only replacement: the testbench drives reads through hierarchical forces.
// The actual CPU is covered by the whole-core boot simulation.
module fx68k(
    input clk, extReset, pwrUp, enPhi1, enPhi2,
    input HALTn, BRn, BGACKn, DTACKn, VPAn, BERRn,
    input IPL0n, IPL1n, IPL2n,
    input [15:0] iEdb,
    output [23:1] eab,
    output [15:0] oEdb,
    output eRWn, LDSn, UDSn, ASn, FC0, FC1, FC2, BGn,
    output oRESETn, oHALTEDn, VMAn, E
);

assign eab=0, oEdb=0;
assign eRWn=1, LDSn=1, UDSn=1, ASn=1;
assign FC0=0, FC1=0, FC2=0, BGn=1;
assign oRESETn=1, oHALTEDn=1, VMAn=1, E=0;

endmodule
