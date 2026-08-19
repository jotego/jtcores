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

    Author: meathax
    Version: 1.0
    Date: 18-8-2026 */

module jtdcastl_main
(
	input         rst,
	input         clk,
	input         ce_cpu,
	input         pause,
	input   [1:0] profile,
	input         irq_n,

	input   [7:0] rom_q,
	output [15:0] rom_addr,
	output reg    rom_cs,       // exposed so jtdcastl_game.v can drive
	                            // mem.yaml's `main_cs` SDRAM-slot request. The
	                            // decode itself is the source core's, unchanged.
	input         rom_ok,       // SDRAM-fetch-ready qualifier, see header notes 3/4

	input   [7:0] comm_latch,
	output  [7:0] comm_dout,
	output        comm_start,
	output        comm_write,
	input         comm_wait_n,  // NOTE: cross-CPU handshake wait -- see open question below

	output  [8:0] sprite_addr,
	output  [7:0] sprite_din,
	output        sprite_we,

	output  [9:0] video_addr,
	output  [7:0] video_din,
	input   [7:0] video_dout,
	output        video_we,

	output  [9:0] color_addr,
	output  [7:0] color_din,
	input   [7:0] color_dout,
	output        color_we,

	input   [7:0] adpcm_status,
	output        adpcm_wr,
	output  [7:0] adpcm_data,

	output reg [4:0] crtc_reg,
	output reg [7:0] crtc_data,
	output reg       crtc_we,
	output           sub_nmi_req,
	output           watchdog_kick,

	output [15:0] cpu_addr_debug,
	output        m1_n_debug,
	output        iorq_n_debug
);

// -------------------------------------------------------------------------
// Declarations
// -------------------------------------------------------------------------
localparam [1:0] PROFILE_CASTLE = 2'd0;
localparam [1:0] PROFILE_RUNRUN = 2'd1;
localparam [1:0] PROFILE_SOCCER = 2'd2;

wire is_runrun = profile == PROFILE_RUNRUN;
wire is_soccer = profile == PROFILE_SOCCER;
wire cpu_ena = ce_cpu & ~pause & comm_wait_n;
wire [15:0] cpu_addr;
wire  [7:0] cpu_dout;
wire  [7:0] ram_dout;
wire  [7:0] cpu_din;
wire m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, rst_n;

assign rst_n = ~rst;

// Qualified bus cycles (jotego review request #2 / #4): a real Z80 memory
// access excludes I/O and refresh cycles, so every memory-space select
// below is gated by cpu_macc rather than by address alone. I/O-space
// selects (the CRTC register port) are qualified by ~iorq_n instead.
wire cpu_macc = ~mreq_n & rfsh_n;
wire cpu_rd   = cpu_macc & ~rd_n;
wire cpu_wr   = cpu_macc & ~wr_n;
wire cpu_iord = ~iorq_n & ~rd_n;
wire cpu_iowr = ~iorq_n & ~wr_n;

// Decoder outputs -- one explicit combinational block below drives all of
// these, defaulting every select low every cycle (zero-latency decode).
reg ram_cs, sprite_cs, video_cs, color_cs, comm_cs, adpcm_cs;
reg nmi_cs, watchdog_cs, crtc_reg_cs, crtc_data_cs;

// -------------------------------------------------------------------------
// Address decoder -- one explicit always block. Every select defaults low,
// then the profile-dependent memory map is decoded as three adjacent,
// independently auditable per-profile cases (see doc/main_map.md, which
// transcribes the address ranges below from mrdo's docastle_main.sv /
// MAME src/mame/universal/docastle.cpp main_map variants). The CRTC I/O
// register port is address-identical across all three profiles, so it is
// decoded once, outside the profile case, qualified by ~iorq_n only.
// -------------------------------------------------------------------------
always @* begin
	rom_cs     = 1'b0;
	ram_cs       = 1'b0;
	sprite_cs    = 1'b0;
	video_cs     = 1'b0;
	color_cs     = 1'b0;
	comm_cs      = 1'b0;
	adpcm_cs     = 1'b0;
	nmi_cs       = 1'b0;
	watchdog_cs  = 1'b0;
	crtc_reg_cs  = 1'b0;
	crtc_data_cs = 1'b0;

	if (cpu_macc) begin
		case (profile)
			PROFILE_CASTLE: begin
				if (cpu_addr < 16'h8000)
					rom_cs = 1'b1;
				else if (cpu_addr >= 16'h8000 && cpu_addr <= 16'h97ff)
					ram_cs = 1'b1;
				else if (cpu_addr >= 16'h9800 && cpu_addr <= 16'h99ff)
					sprite_cs = 1'b1;
				else if (cpu_addr >= 16'ha000 && cpu_addr <= 16'ha7ff)
					comm_cs = 1'b1;
				else if (cpu_addr == 16'ha800)
					watchdog_cs = 1'b1;
				else if (cpu_addr[15:12] == 4'hb && !cpu_addr[10])
					video_cs = 1'b1;
				else if (cpu_addr[15:12] == 4'hb && cpu_addr[10])
					color_cs = 1'b1;
				else if (cpu_addr == 16'he000)
					nmi_cs = 1'b1;
			end

			PROFILE_RUNRUN: begin
				if (cpu_addr < 16'h2000)
					rom_cs = 1'b1;
				else if (cpu_addr >= 16'h2000 && cpu_addr <= 16'h37ff)
					ram_cs = 1'b1;
				else if (cpu_addr >= 16'h3800 && cpu_addr <= 16'h39ff)
					sprite_cs = 1'b1;
				else if (cpu_addr >= 16'h4000 && cpu_addr <= 16'h9fff)
					rom_cs = 1'b1;
				else if (cpu_addr >= 16'ha000 && cpu_addr <= 16'ha7ff)
					comm_cs = 1'b1;
				else if (cpu_addr == 16'ha800)
					watchdog_cs = 1'b1;
				else if (cpu_addr >= 16'hb000 && cpu_addr <= 16'hb3ff)
					video_cs = 1'b1;
				else if (cpu_addr >= 16'hb400 && cpu_addr <= 16'hb7ff)
					color_cs = 1'b1;
				else if (cpu_addr == 16'hb800)
					nmi_cs = 1'b1;
			end

			PROFILE_SOCCER: begin
				if (cpu_addr < 16'h4000)
					rom_cs = 1'b1;
				else if (cpu_addr >= 16'h4000 && cpu_addr <= 16'h57ff)
					ram_cs = 1'b1;
				else if (cpu_addr >= 16'h5800 && cpu_addr <= 16'h59ff)
					sprite_cs = 1'b1;
				else if (cpu_addr >= 16'h6000 && cpu_addr <= 16'h9fff)
					rom_cs = 1'b1;
				else if (cpu_addr >= 16'ha000 && cpu_addr <= 16'ha7ff)
					comm_cs = 1'b1;
				else if (cpu_addr == 16'ha800)
					watchdog_cs = 1'b1;
				else if (cpu_addr[15:12] == 4'hb && !cpu_addr[10])
					video_cs = 1'b1;
				else if (cpu_addr[15:12] == 4'hb && cpu_addr[10])
					color_cs = 1'b1;
				else if (cpu_addr == 16'hc000)
					adpcm_cs = 1'b1;
				else if (cpu_addr == 16'he000)
					nmi_cs = 1'b1;
			end

			default: ; // unreachable, profile is only 2 bits wide over 3 values
		endcase
	end

	// CRTC register port -- I/O space, identical across all profiles.
	if (~iorq_n) begin
		if (cpu_addr[7:0] == 8'h00)
			crtc_reg_cs = 1'b1;
		else if (cpu_addr[7:0] == 8'h02)
			crtc_data_cs = 1'b1;
	end
end

// -------------------------------------------------------------------------
// Input-data mux -- combinational priority ternary chain into the CPU,
// same timing as before (cpu_din was a purely combinational, address-
// decoded mux with no register stage).
// -------------------------------------------------------------------------
assign cpu_din = rom_cs   ? rom_q         :
                 ram_cs   ? ram_dout      :
                 comm_cs  ? comm_latch    :
                 video_cs ? video_dout    :
                 color_cs ? color_dout    :
                 adpcm_cs ? adpcm_status  : 8'hff;

// -------------------------------------------------------------------------
// Peripheral-facing bus connections and state.
//
// Memory/register writes (sprite, video, color, comm, ADPCM, watchdog,
// CRTC) are plain synchronous write-enables: the decoded select qualified
// with cpu_wr/cpu_iowr is already a one-shot-equivalent strobe from the
// consuming register/RAM's point of view (holding it across extra bus
// clocks just re-writes the same byte), so no edge detection is needed
// for them (jotego review request #4).
//
// comm_start and sub_nmi_req are genuine one-cycle events: comm_start
// kicks off the cross-CPU handshake exactly once per bus access, and
// sub_nmi_req must pulse for exactly one clock to trigger the NMI request
// once per write, not once per clock the write signal is held. Both use
// jtframe_edge, self-cleared the cycle after they assert, to reproduce
// the previous wr_edge/rd_edge-based one-cycle pulse exactly.
// -------------------------------------------------------------------------
assign sprite_addr = cpu_addr[8:0];
assign sprite_din  = cpu_dout;
assign sprite_we   = cpu_wr & sprite_cs;
assign video_addr  = cpu_addr[9:0];
assign video_din   = cpu_dout;
assign video_we    = cpu_wr & video_cs;
assign color_addr  = cpu_addr[9:0];
assign color_din   = cpu_dout;
assign color_we    = cpu_wr & color_cs;
assign comm_write  = cpu_wr & comm_cs;
assign comm_dout   = cpu_dout;
assign adpcm_wr    = cpu_wr & adpcm_cs;
assign adpcm_data  = cpu_dout;
assign watchdog_kick = cpu_wr & watchdog_cs;

wire comm_acc = (cpu_rd | cpu_wr) & comm_cs;
jtframe_edge #(.QSET(1)) u_comm_edge (
	.rst    ( rst        ),
	.clk    ( clk        ),
	.edgeof ( comm_acc   ),
	.clr    ( comm_start ),
	.q      ( comm_start )
);

wire nmi_wr = cpu_wr & nmi_cs;
jtframe_edge #(.QSET(1)) u_nmi_edge (
	.rst    ( rst          ),
	.clk    ( clk          ),
	.edgeof ( nmi_wr       ),
	.clr    ( sub_nmi_req  ),
	.q      ( sub_nmi_req  )
);

// CRTC register-index/data-latch commit. The select comes from the main
// decoder (crtc_reg_cs/crtc_data_cs, item 3); the frame-shadowed register
// commit protocol itself (index vs data latch, crtc_we pulse) is legitimate
// stateful behaviour and stays sequential, unchanged from before.
always @(posedge clk) begin
	if (rst) begin
		crtc_reg  <= 0;
		crtc_data <= 0;
		crtc_we   <= 0;
	end else begin
		crtc_we <= 0;

		if (cpu_iowr && crtc_reg_cs)
			crtc_reg <= cpu_dout[4:0];

		if (cpu_iowr && crtc_data_cs) begin
			crtc_data <= cpu_dout;
			crtc_we   <= 1;
		end
	end
end

// -------------------------------------------------------------------------
// CPU instance -- last, per house style.
// -------------------------------------------------------------------------
jtframe_sysz80 #(.RAM_AW(13),.CLR_INT(0),.RECOVERY(1)) u_cpu
(
	.rst_n      ( rst_n       ),
	.clk        ( clk         ),
	.cen        ( cpu_ena     ),
	.cpu_cen    (             ),
	.int_n      ( irq_n       ),
	.nmi_n      ( 1'b1        ),
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
	.ram_cs     ( ram_cs      ),
	.rom_cs     ( rom_cs      ),
	.rom_ok     ( rom_ok      )
);

assign cpu_addr_debug = cpu_addr;
assign m1_n_debug = m1_n;
assign iorq_n_debug = iorq_n;
assign rom_addr = cpu_addr;

endmodule
