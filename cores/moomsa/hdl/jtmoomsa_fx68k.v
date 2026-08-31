/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_fx68k(
	input          clk,
	input          rst,
	input          cpu_cen,
	input          cpu_cenb,
	input          BERRn,
	input          VPAn,
	input          BGACKn,
	input          HALTn,
	output         RESETn,
	output [23:1]  eab,
	output         ASn,
	output         LDSn,
	output         UDSn,
	output         eRWn,
	input          DTACKn,
	input  [15:0]  iEdb,
	output [15:0]  oEdb,
	input          BRn,
	output         BGn,
	input  [2:0]   IPLn,
	output [2:0]   FC
);

/* Optional CPU status outputs are retained explicitly for diagnostics. */
/* verilator lint_off UNUSEDSIGNAL */
wire         cpu_halted_n;
wire         cpu_vma_n;
wire         cpu_e;
/* verilator lint_on UNUSEDSIGNAL */

fx68k u_cpu(
	.clk(clk), .extReset(rst), .pwrUp(rst),
	.enPhi1(cpu_cen), .enPhi2(cpu_cenb),
	.HALTn(HALTn), .BERRn(BERRn), .VPAn(VPAn), .DTACKn(DTACKn),
	.BRn(BRn), .BGACKn(BGACKn), .BGn(BGn),
	.IPL0n(IPLn[0]), .IPL1n(IPLn[1]), .IPL2n(IPLn[2]),
	.eab(eab), .iEdb(iEdb), .oEdb(oEdb),
	.ASn(ASn), .LDSn(LDSn), .UDSn(UDSn), .eRWn(eRWn),
	.FC0(FC[0]), .FC1(FC[1]), .FC2(FC[2]),
	.oRESETn(RESETn), .oHALTEDn(cpu_halted_n), .VMAn(cpu_vma_n), .E(cpu_e)
);

endmodule
