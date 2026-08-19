/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: aCORES
    Version: 1.0
    Date: 18-8-2026 */

// Sub (sound) Z80 of the Universal Do! Castle hardware family. Ported from the
// standalone MiSTer Universal_DoCastle core this core derives from, onto
// jtframe's CPU/SDRAM boundary.
//
// Differences from the source core's sub CPU, and why:
//   1. T80se instantiated directly -> jtframe_sysz80 (RAM_AW=11). Same
//      integration pattern as jtdcastl_main.v's u_cpu (see that file's
//      header note 1) -- jtframe_sysz80 fuses the Z80, its own work RAM
//      (jtframe_dual_nvram), and a rom_cs/rom_ok wait-state generator
//      (jtframe_z80_romwait) in one module.
//   2. The local `work_ram[0:2047]` BRAM block and its ram_cs read/write
//      logic are REMOVED -- that RAM now lives inside jtframe_sysz80's own
//      jtframe_dual_nvram. RAM_AW=11 exactly covers the original 2048-byte,
//      11-bit-addressed window (cpu_addr[10:0]), matching ram_cs's own
//      0x8000-0x87ff range (0x800 = 2048 locations). ram_cs/ram_dout are
//      wired to the wrapper instead of a locally-inferred array; every use
//      of the old `work_q` read register in the cpu_din mux is now
//      `ram_dout`.
//   3. NEW input `rom_ok`, same reasoning as jtdcastl_main.v note 3: ROM
//      is now SDRAM-backed with variable latency, and jtframe_sysz80
//      internally inserts Z80 WAIT states while `rom_cs && !rom_ok`. The
//      rom_cs decode itself (cpu_addr < 0x4000, matching rom_addr's 14-bit
//      window) is UNCHANGED -- it is now given an explicit wire name so it
//      can drive both the wrapper's rom_cs input and the existing cpu_din
//      read mux (which previously spelled the same condition out inline).
//   4. Same boundary shape as jtdcastl_main.v note 4: rom_q/rom_addr/
//      rom_cs/rom_ok are exposed here and jtdcastl_game.v wires the
//      mem.yaml-generated "sub" bus (sub_addr/sub_data/sub_ok) to them.
//   5. CLR_INT(0) chosen to match the source core's direct `.INT_n(irq_n)`
//      pass-through -- irq_n is a raw external level, not latched by M1/
//      IORQ inside this module, same reasoning as jtdcastl_main.v note 5.
//      This module's own NMI generation (the `nmi_n` register, clocked from
//      `nmi_req`) is UNCHANGED logic and is now wired straight to
//      jtframe_sysz80's `nmi_n` port instead of T80se's `NMI_n` pin.
//   6. Everything else -- the profile-dependent memory map (ram_cs/comm_cs/
//      input_cs), the TMS1025 input-mux/flip-screen latching, the edge-
//      detected write/read logic, and the 4x jt89 PSG instantiation
//      (`.rst(reset)`/`.clk_en(ce_psg)`) -- is unchanged from the source
//      core.
//   7. KNOWN LIMITATION -- see the detailed comment immediately before the
//      u_cpu instantiation below. It shares a root cause with
//      jtdcastl_main.v's comm_wait_n limitation (jtframe_sysz80 exposes no
//      general external WAIT_n input) but it is a DIFFERENT signal and NOT
//      the cross-CPU mailbox handshake -- see that comment for the evidence.
//
// MAME reference: src/mame/universal/docastle.cpp sound_map variants.

module jtdcastl_sub
(
	input         clk,
	input         reset,
	input         ce_cpu,
	input         ce_psg,
	input         pause,
	input   [1:0] profile,
	input         irq_n,
	input         nmi_req,

	input   [7:0] rom_q,
	output [13:0] rom_addr,
	output        rom_cs,       // exposed so jtdcastl_game.v can drive
	                            // mem.yaml's `sub_cs` SDRAM-slot request.
	                            // Decode is the source core's (cpu_addr < 0x4000).
	input         rom_ok,       // SDRAM-fetch-ready qualifier, see header note 3

	input   [7:0] comm_latch,
	output  [7:0] comm_dout,
	output        comm_access,
	output        comm_write,

	input   [7:0] dsw1,
	input   [7:0] dsw2,
	input   [7:0] joys,
	input   [7:0] joys2,
	input   [7:0] buttons,
	input   [7:0] system,
	output reg    flipscreen,

	output signed [15:0] audio,
	output [15:0] cpu_addr_debug,
	output        m1_n_debug,
	output        iorq_n_debug,
	output  [3:0] psg_ready_debug
);

localparam [1:0] PROFILE_RUNRUN = 2'd1;
wire is_runrun = profile == PROFILE_RUNRUN;
wire cpu_ena = ce_cpu & ~pause & cpu_wait_n;
wire [15:0] cpu_addr;
wire  [7:0] cpu_dout;
wire  [7:0] ram_dout;
reg   [7:0] cpu_din;
wire m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, rst_n;
wire [3:0] psg_ready;
wire cpu_wait_n = &psg_ready;   // low while any PSG is servicing a write
reg nmi_n;

assign rst_n = ~reset;

always @(posedge clk) begin
	if (reset) nmi_n <= 1;
	else begin
		if (nmi_req) nmi_n <= 0;
		else if (ce_cpu) nmi_n <= 1;
	end
end

// KNOWN LIMITATION -- PSG-busy WAIT not injected. On the PCB the sub Z80's
// WAIT_n carries `cpu_wait_n = &psg_ready`: a stall on the sub CPU's OWN bus
// while any of the four jt89 PSGs is still busy servicing a prior write. This
// is NOT the same signal as jtdcastl_main.v's comm_wait_n limitation. The
// main/sub mailbox handshake is ASYMMETRIC, not a mutual or bidirectional
// WAIT: only main's Z80 ever stalls on it (main's comm_wait_n = ~main_wait;
// main_wait is set when main pulses comm_start and cleared when SUB pulses
// comm_access against the shared comm_latch register, which lives at board
// level). Sub's own bus is never stalled by that mailbox exchange -- the sub
// CPU has no comm_wait_n port at all. So moving sub to jtframe_sysz80 does
// not lose a cross-CPU WAIT hookup (it never had one); the signal that
// becomes homeless here is purely the local PSG-busy stall. As with main,
// jtframe_sysz80 exposes no general external WAIT_n input (only its internal
// rom_cs/rom_ok wait generator, jtframe_z80_romwait), so `cpu_wait_n` is
// still computed exactly as before (it drives `psg_ready_debug`) but is left
// unconnected to the CPU wrapper, stubbed below rather than wired to
// something arbitrary. The correct injection point must be determined from
// hardware evidence rather than guessed.

jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(0),.RECOVERY(1)) u_cpu
(
	.rst_n      ( rst_n       ),
	.clk        ( clk         ),
	.cen        ( cpu_ena     ),
	.cpu_cen    (             ),
	.int_n      ( irq_n       ),
	.nmi_n      ( nmi_n       ),
	.busrq_n    ( 1'b1        ),
	.busak_n    (             ),
	.m1_n       ( m1_n        ),
	.mreq_n     ( mreq_n      ),
	.iorq_n     ( iorq_n      ),
	.rd_n       ( rd_n        ),
	.wr_n       ( wr_n        ),
	.rfsh_n     ( rfsh_n      ),
	.halt_n     (             ),
	.A          ( cpu_addr    ),
	.cpu_din    ( cpu_din     ),
	.cpu_dout   ( cpu_dout    ),
	.ram_dout   ( ram_dout    ),
	// No NVRAM pins: jtframe_sysz80 does not expose prog_addr/prog_data/
	// prog_din/prog_we -- see the note in jtdcastl_main.v.
	// ROM/RAM access
	.ram_cs     ( ram_cs      ),
	.rom_cs     ( rom_cs      ),
	.rom_ok     ( rom_ok      )
);

assign cpu_addr_debug = cpu_addr;
assign m1_n_debug = m1_n;
assign iorq_n_debug = iorq_n;
assign psg_ready_debug = psg_ready;
assign rom_addr = cpu_addr[13:0];

wire mem_cycle = ~mreq_n & rfsh_n & (~rd_n | ~wr_n);
wire wr_level = mem_cycle & ~wr_n;
wire rd_level = mem_cycle & ~rd_n;
reg wr_d, rd_d;
wire wr_edge = wr_level & ~wr_d;
wire rd_edge = rd_level & ~rd_d;

assign rom_cs = cpu_addr < 16'h4000;
wire ram_cs = (cpu_addr >= 16'h8000) && (cpu_addr <= 16'h87ff);
wire comm_cs = is_runrun
	? ((cpu_addr >= 16'he000) && (cpu_addr <= 16'he7ff))
	: ((cpu_addr >= 16'ha000) && (cpu_addr <= 16'ha7ff));
wire input_cs = (cpu_addr[15:8] == 8'hc0) && (cpu_addr[6:3] == 4'b0000);

function automatic [7:0] input_mux(input [2:0] sel);
	begin
		case (sel)
			3'd1: input_mux = dsw2;
			3'd2: input_mux = dsw1;
			3'd3: input_mux = joys;
			3'd4: input_mux = joys2;
			3'd5: input_mux = buttons;
			3'd7: input_mux = system;
			default: input_mux = 8'hff;
		endcase
	end
endfunction

reg [2:0] input_sel;
reg [7:0] input_latch;
reg [7:0] input_hold;
wire [7:0] selected_input = input_mux(input_sel);

always @(posedge clk) begin
	if (reset) begin
		wr_d <= 0;
		rd_d <= 0;
		input_sel <= 0;
		input_latch <= 8'h00;
		input_hold <= 8'h00;
		flipscreen <= 0;
	end else begin
		wr_d <= wr_level;
		rd_d <= rd_level;

		// A read returns the previously selected TMS1025 port, then latches
		// A0-A2 for the next read. Port zero is high-Z and retains the value
		// last driven onto H. Reads and writes both latch A7 as flip-screen.
		if ((rd_edge || wr_edge) && input_cs)
			flipscreen <= cpu_addr[7];
		if (rd_edge && input_cs) begin
			input_latch <= (input_sel == 0) ? input_hold : selected_input;
			if (input_sel != 0) input_hold <= selected_input;
			input_sel <= cpu_addr[2:0];
		end
	end
end

assign comm_access = (rd_edge | wr_edge) & comm_cs;
assign comm_write  = wr_edge & comm_cs;
assign comm_dout   = cpu_dout;

always @(*) begin
	cpu_din = 8'hff;
	if (rom_cs)               cpu_din = rom_q;
	else if (ram_cs)          cpu_din = ram_dout;
	else if (comm_cs)         cpu_din = comm_latch;
	else if (input_cs)        cpu_din = input_latch;
end

// One clean PSG strobe per Z80 write cycle. READY from any chip stalls the
// sub CPU, matching MAME's INPUT_MERGER_ANY_LOW wiring.
reg [3:0] sn_pulse;
reg [7:0] sn_data [0:3];
always @(posedge clk) begin
	if (reset) begin
		sn_pulse <= 0;
		sn_data[0] <= 0;
		sn_data[1] <= 0;
		sn_data[2] <= 0;
		sn_data[3] <= 0;
	end else begin
		sn_pulse <= 0;
		if (wr_edge) begin
			if (is_runrun) begin
				case (cpu_addr)
					16'ha000: begin sn_data[0] <= cpu_dout; sn_pulse[0] <= 1; end
					16'ha400: begin sn_data[1] <= cpu_dout; sn_pulse[1] <= 1; end
					16'ha800: begin sn_data[2] <= cpu_dout; sn_pulse[2] <= 1; end
					16'hac00: begin sn_data[3] <= cpu_dout; sn_pulse[3] <= 1; end
					default: ;
				endcase
			end else begin
				case (cpu_addr)
					16'he000: begin sn_data[0] <= cpu_dout; sn_pulse[0] <= 1; end
					16'he400: begin sn_data[1] <= cpu_dout; sn_pulse[1] <= 1; end
					16'he800: begin sn_data[2] <= cpu_dout; sn_pulse[2] <= 1; end
					16'hec00: begin sn_data[3] <= cpu_dout; sn_pulse[3] <= 1; end
					default: ;
				endcase
			end
		end
	end
end

wire signed [10:0] sn_sound [0:3];
genvar gi;
generate for (gi=0; gi<4; gi=gi+1) begin : psg
	jt89 #(.MODE(0)) chip
	(
		.rst(reset), .clk(clk), .clk_en(ce_psg),
		.wr_n(~sn_pulse[gi]), .cs_n(~sn_pulse[gi]), .din(sn_data[gi]),
		.sound(sn_sound[gi]), .ready(psg_ready[gi])
	);
end endgenerate

wire signed [12:0] sn0e = {{2{sn_sound[0][10]}},sn_sound[0]};
wire signed [12:0] sn1e = {{2{sn_sound[1][10]}},sn_sound[1]};
wire signed [12:0] sn2e = {{2{sn_sound[2][10]}},sn_sound[2]};
wire signed [12:0] sn3e = {{2{sn_sound[3][10]}},sn_sound[3]};
wire signed [13:0] sn_sum = sn0e + sn1e + sn2e + sn3e;
wire signed [17:0] scaled = $signed(sn_sum) * 18'sd8;
assign audio = (reset || pause) ? 16'sd0 : scaled[15:0];

endmodule
