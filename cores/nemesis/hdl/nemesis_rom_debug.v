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
//  SDRAM Debugging Utility Module (pass-through in releases)
//================================================================================

`default_nettype none

module nemesis_rom_debug(
	input         i_clk,
	input         i_cen,

	input  [ 7:0] i_debug_bus,
	output [ 7:0] o_debug_view,
	
	input         i_z80_cs, // z80_cs | ~cpu_start
	input         i_z80_ok,
	input  [13:0] i_z80_addr,
	input  [ 7:0] i_z80_data,
	output        o_z80_sdram_cs,
	output [13:0] o_z80_sdram_addr,
	
	input         i_main_cs, // main_cs | ~cpu_start
	input         i_main_ok,
	input  [16:0] i_main_addr,
	input  [15:0] i_main_data,
	output        o_main_sdram_cs,
	output [16:0] o_main_sdram_addr
);

`ifdef ROM_DEBUG_Z80
	`define ROM_DEBUG
`endif
`ifdef ROM_DEBUG_MAIN
	`define ROM_DEBUG
`endif

`ifdef ROM_DEBUG

reg  [7:0] i_debug_bus_prev;
reg        debug_cs;
wire       debug_ok;
wire [7:0] debug_data;

always @( posedge i_clk ) if( i_cen ) begin
	if ( i_debug_bus != debug_bus_prev ) begin
		debug_cs <= 1'b1;
	end

	if( debug_ok ) begin
		o_debug_view <= debug_data;
		debug_cs <= 1'b0;
	end

	debug_bus_prev <= i_debug_bus;
end

`endif

`ifdef ROM_DEBUG_Z80
	assign o_z80_sdram_cs    = debug_cs;
	assign o_z80_sdram_addr  = i_debug_bus;
	assign debug_ok        = i_z80_ok;
	assign debug_data      = i_z80_data;
`else
	assign o_z80_sdram_cs    = i_z80_cs;
	assign o_z80_sdram_addr  = i_z80_addr;
`endif

`ifdef ROM_DEBUG_MAIN
	assign o_main_sdram_cs   = debug_cs;
	assign o_main_sdram_addr = i_debug_bus >> 1;
	assign debug_ok        = i_main_ok;
	// on the 68k, MSB is on even addresses
	assign debug_data      = i_debug_bus[0] ? i_main_data[7:0] : i_main_data[15:8];
`else
	assign o_main_sdram_cs   = i_main_cs;
	assign o_main_sdram_addr = i_main_addr;
`endif

endmodule
