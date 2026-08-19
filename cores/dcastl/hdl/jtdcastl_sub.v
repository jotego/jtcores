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
	output reg    rom_cs,       // exposed so jtdcastl_game.v can drive
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

// rom_cs is declared `output reg` above -- outside `ifndef so the NOSOUND
// tie-off (initial) and the real decoder (always@*) both drive the same net

`ifndef NOSOUND

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

assign cpu_addr_debug = cpu_addr;
assign m1_n_debug = m1_n;
assign iorq_n_debug = iorq_n;
assign psg_ready_debug = psg_ready;
assign rom_addr = cpu_addr[13:0];

// ---------------------------------------------------------------------
// Address decoder. All selects default 0; every branch is a preserved
// address range from the previous revision. Every select on this CPU is
// memory-mapped (there is no I/O-space access on the sub board: iorq_n
// is only tapped for iorq_n_debug), so cpu_macc -- not iorq_n -- is the
// qualifier used downstream by cpu_rd/cpu_wr. rom_cs/ram_cs stay pure
// combinational address decodes: jtframe_sysz80 (modules/jtframe/hdl/
// cpu/jtframe_z80.v:53-55) takes them as plain decode inputs and does
// its own mreq_n-qualified wait-state handling internally, so ANDing
// cpu_macc into these two specifically would double-gate the wrapper's
// contract rather than follow it.
// ---------------------------------------------------------------------
reg        ram_cs;
reg        comm_cs;
reg        input_cs;
reg  [3:0] psg_cs;

always @* begin
	rom_cs   = 1'b0;
	ram_cs   = 1'b0;
	comm_cs  = 1'b0;
	input_cs = 1'b0;
	psg_cs   = 4'b0000;

	if (cpu_addr < 16'h4000)
		rom_cs = 1'b1;
	else if (cpu_addr >= 16'h8000 && cpu_addr <= 16'h87ff)
		ram_cs = 1'b1;
	else if (cpu_addr[15:8] == 8'hc0 && cpu_addr[6:3] == 4'b0000)
		input_cs = 1'b1;
	else if (is_runrun && cpu_addr >= 16'he000 && cpu_addr <= 16'he7ff)
		comm_cs = 1'b1;
	else if (!is_runrun && cpu_addr >= 16'ha000 && cpu_addr <= 16'ha7ff)
		comm_cs = 1'b1;
	else if (is_runrun) begin
		case (cpu_addr)
			16'ha000: psg_cs[0] = 1'b1;
			16'ha400: psg_cs[1] = 1'b1;
			16'ha800: psg_cs[2] = 1'b1;
			16'hac00: psg_cs[3] = 1'b1;
			default: ;
		endcase
	end else begin
		case (cpu_addr)
			16'he000: psg_cs[0] = 1'b1;
			16'he400: psg_cs[1] = 1'b1;
			16'he800: psg_cs[2] = 1'b1;
			16'hec00: psg_cs[3] = 1'b1;
			default: ;
		endcase
	end
end

// Standard bus strobes. cpu_rd/cpu_wr are the qualified memory-space
// levels; wr_edge/rd_edge are the genuine one-shot events consumed by
// the sequential blocks below (input select, flipscreen, comm strobes,
// PSG writes), built with jtframe_edge_pulse rather than hand-rolled
// _d/_edge registers.
wire cpu_macc = ~mreq_n & rfsh_n;
wire cpu_rd = cpu_macc & ~rd_n;
wire cpu_wr = cpu_macc & ~wr_n;
wire wr_edge, rd_edge;

jtframe_edge_pulse u_wr_edge(
	.rst    ( reset     ),
	.clk    ( clk       ),
	.cen    ( 1'b1      ),
	.sigin  ( cpu_wr    ),
	.pulse  ( wr_edge   )
);

jtframe_edge_pulse u_rd_edge(
	.rst    ( reset     ),
	.clk    ( clk       ),
	.cen    ( 1'b1      ),
	.sigin  ( cpu_rd    ),
	.pulse  ( rd_edge   )
);

// TMS1025-style cabinet input selector: a registered mux, not a
// single-use function. cab_mux resolves the source combinationally
// from the *previous* input_sel (registered address selector), matching
// the multiplexer's one-cycle-late behaviour bit-for-bit.
reg [2:0] input_sel;
reg [7:0] input_latch;
reg [7:0] input_hold;

wire [7:0] cab_mux =
	input_sel == 3'd1 ? dsw2    :
	input_sel == 3'd2 ? dsw1    :
	input_sel == 3'd3 ? joys    :
	input_sel == 3'd4 ? joys2   :
	input_sel == 3'd5 ? buttons :
	input_sel == 3'd7 ? system  :
	                     8'hff;

always @(posedge clk) begin
	if (reset) begin
		input_sel   <= 3'd0;
		input_latch <= 8'h00;
		input_hold  <= 8'h00;
		flipscreen  <= 1'b0;
	end else begin
		if ((rd_edge | wr_edge) && input_cs)
			flipscreen <= cpu_addr[7];
		if (rd_edge && input_cs) begin
			input_latch <= (input_sel == 3'd0) ? input_hold : cab_mux;
			if (input_sel != 3'd0) input_hold <= cab_mux;
			input_sel <= cpu_addr[2:0];
		end
	end
end

// Combinational, matching the previous revision's timing exactly:
// cpu_din must be valid within the same cycle rd_n falls.
always @* begin
	cpu_din = rom_cs   ? rom_q      :
	          ram_cs   ? ram_dout   :
	          comm_cs  ? comm_latch :
	          input_cs ? input_latch:
	                     8'hff;
end

// Mailbox response side: comm_cs is the one decoded select from the
// block above; these are the only consumers, no scattered inline
// address compares.
assign comm_access = (rd_edge | wr_edge) & comm_cs;
assign comm_write  = wr_edge & comm_cs;
assign comm_dout   = cpu_dout;

// One clean PSG strobe per Z80 write cycle, gated by the explicit
// psg_cs[3:0] decoded above. READY from any chip stalls the sub CPU,
// matching MAME's INPUT_MERGER_ANY_LOW wiring.
reg [3:0] sn_pulse;
reg [7:0] sn_data [0:3];
always @(posedge clk) begin
	if (reset) begin
		sn_pulse   <= 4'b0000;
		sn_data[0] <= 8'h00;
		sn_data[1] <= 8'h00;
		sn_data[2] <= 8'h00;
		sn_data[3] <= 8'h00;
	end else begin
		sn_pulse <= 4'b0000;
		if (wr_edge) begin
			if (psg_cs[0]) begin sn_data[0] <= cpu_dout; sn_pulse[0] <= 1'b1; end
			if (psg_cs[1]) begin sn_data[1] <= cpu_dout; sn_pulse[1] <= 1'b1; end
			if (psg_cs[2]) begin sn_data[2] <= cpu_dout; sn_pulse[2] <= 1'b1; end
			if (psg_cs[3]) begin sn_data[3] <= cpu_dout; sn_pulse[3] <= 1'b1; end
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
	.ram_cs     ( ram_cs      ),
	.rom_cs     ( rom_cs      ),
	.rom_ok     ( rom_ok      )
);

`else

initial rom_cs   = 1'b0;
assign  rom_addr = 14'd0;
assign  comm_dout   = 8'd0;
assign  comm_access = 1'b0;
assign  comm_write  = 1'b0;
initial flipscreen  = 1'b0;
assign  audio = 16'sd0;
assign  cpu_addr_debug = 16'd0;
assign  m1_n_debug = 1'b0;
assign  iorq_n_debug = 1'b0;
assign  psg_ready_debug = 4'd0;

`endif

endmodule
