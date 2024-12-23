/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2023.

Support the authors:

       Raki: https://www.patreon.com/ikamusume
    LMN-san: https://ko-fi.com/lmnsan
  OScherler: https://ko-fi.com/oscherler

The authors do not endorse or participate in illegal distribution
of copyrighted material. This work can be used with legally
obtained ROM dumps of games or with homebrew software for
the arcade platform.

This file license is GNU GPLv3.
You can read the whole license file at http://www.gnu.org/licenses/

*/

//================================================================================
//  68000 CPU Address Decoder
//================================================================================

`default_nettype none

module nemesis_68k_addr_dec(
	input        i_as_n,
	input        i_lds_n,
	input        i_uds_n,
	input [23:1] i_cpu_addr,

	output reg   o_prom_cs_n,
	output reg   o_chara,
	output reg   o_excs_n,
	output reg   o_ram_cs_n,
	output reg   o_vzure,
	output reg   o_vramcs1,
	output reg   o_vramcs2,
	output reg   o_objram,
	output reg   o_color_ram,
	output reg   o_u11k_g_n,
	output reg   o_u13j_g_n,
	output reg   o_data_n,
	output reg   o_afe_n,
	output reg   o_input_mux_g_n,
	output reg   o_dip1_g_n,
	output reg   o_dip2_g_n
);

// 68k address decoding
//
// Use = in always @(*) (like in jt_gng/sf) so that changes are immediate
// even with an intermidiate variable.
//
// ** 3 x 3-to-8 line decoder **
// ** [LS138] @ 14J, 6J, 13G **
// ** tri 3-input NOR gates **
// ** [LS27]  @ 16G **
// ** quad 2-input NAND gates **
// ** [LS00]  @ 17J **
// ** hex inverters **
// ** [LS04]  @ 12G **
// ** quad 2-input OR gates **
// ** [LS32]  @ 11E, 4J **
always @(*) begin
	reg u14j_en, u6j_g2b_n, u6j_en, u13g_g2a_n, u11e_sel_n, u13g_en, dip_sel_n;

	// [LS27] @ 16G, [LS00] @ 17J + AS signal
	u14j_en = i_cpu_addr[23:19] == 5'b0 && ~i_as_n;

	// [LS138] @ 14J
	o_prom_cs_n  = ! ( u14j_en && i_cpu_addr[18]    == 1'b0   ); // Y0-Y3
	o_chara      = ! ( u14j_en && i_cpu_addr[18:16] == 3'b100 ); // Y4
	u6j_g2b_n    = ! ( u14j_en && i_cpu_addr[18:16] == 3'b101 ); // Y5
	o_ram_cs_n   = ! ( u14j_en && i_cpu_addr[18:16] == 3'b110 ); // Y6
	o_excs_n     = ! ( u14j_en && i_cpu_addr[18:16] == 3'b111 ); // Y7
	
	// [LS32] @ 11E, [LS04] @ 12G
	// Unused, as we group both signals as o_ram_cs_n
	
	u6j_en = &{ ~u6j_g2b_n, ~i_as_n };

	// [LS138] @ 6J
	o_vzure      = ! ( u6j_en && i_cpu_addr[15:13] == 3'b000 ); // Y0
	o_vramcs1    = ! ( u6j_en && i_cpu_addr[15:13] == 3'b001 ); // Y1
	o_vramcs2    = ! ( u6j_en && i_cpu_addr[15:13] == 3'b010 ); // Y2
	o_objram     = ! ( u6j_en && i_cpu_addr[15:13] == 3'b011 ); // Y3
	o_color_ram  = ! ( u6j_en && i_cpu_addr[15:13] == 3'b101 ); // Y5
	u13g_g2a_n   = ! ( u6j_en && i_cpu_addr[15:13] == 3'b110 ); // Y6
	u11e_sel_n   = ! ( u6j_en && i_cpu_addr[15:13] == 3'b111 ); // Y7

	// [LS32] @ 11E
	o_u11k_g_n = ~&{ ~i_lds_n, ~u11e_sel_n };
	o_u13j_g_n = ~&{ ~i_uds_n, ~u11e_sel_n };

	u13g_en = &{ ~u13g_g2a_n, ~i_lds_n };

	// [LS138] @ 13G
	o_data_n        = ! ( u13g_en && i_cpu_addr[12:10] == 3'b000 ); // Y0
	dip_sel_n       = ! ( u13g_en && i_cpu_addr[12:10] == 3'b001 ); // Y1
	o_afe_n         = ! ( u13g_en && i_cpu_addr[12:10] == 3'b010 ); // Y2
	o_input_mux_g_n = ! ( u13g_en && i_cpu_addr[12:10] == 3'b011 ); // Y3
	
	// [LS32] @ 4J, [LS04] @ 12G
	o_dip1_g_n = ~&{ ~dip_sel_n, ~i_cpu_addr[1] };
	o_dip2_g_n = ~&{ ~dip_sel_n,  i_cpu_addr[1] }; // signal is labeled DIP3 on schematic but goes to DIP2
end

endmodule
