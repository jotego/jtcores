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

module jtdcastl_spritecpu
(
	input         clk,
	input         reset,
	input         ce_cpu,
	input         pause,
	input         pcb_fidelity,
	input         nmi_req,
	input         cf_irq_req,
	input   [8:0] main_addr,
	input   [7:0] main_data,
	input         main_we,
	input   [7:0] rom_q,
	output  [8:0] rom_addr,
	input         rom_ok,       // NEW: SDRAM-fetch-ready qualifier, see header note 3
	output reg [10:0] cf_addr,
	output reg  [7:0] cf_data,
	output reg        cf_we,
	output            cf_irq_ack,
	output [15:0] cpu_addr_debug
);

// CPU bus
wire [15:0] cpu_addr;
wire [ 7:0] cpu_dout;
wire [ 7:0] ram_dout;
reg  [ 7:0] cpu_din;
wire        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, rst_n;
wire        int_ack = ~m1_n & ~iorq_n;

reg nmi_n, int_n;

assign rst_n          = ~reset;
assign cf_irq_ack     = int_ack;
assign rom_addr       = cpu_addr[8:0];
assign cpu_addr_debug = cpu_addr;

// ---------------------------------------------------------------------
// Address decoder -- CF37201 doorway CPU memory map (all memory mapped,
// this CPU makes no I/O-space accesses)
//   0x0000-0x00ff  rom_cs    program ROM
//   0x4000-0x47ff  ram_cs    work RAM
//   0x8000-0x81ff  stage_cs  shared sprite staging RAM (read side)
//   0xc000-0xc7ff  cf_cs     CF37201 doorway write window
// ---------------------------------------------------------------------
reg rom_cs, ram_cs, stage_cs, cf_cs;
wire cpu_macc = ~mreq_n & rfsh_n;

always @* begin
	rom_cs   = 0;
	ram_cs   = 0;
	stage_cs = 0;
	cf_cs    = 0;
	if (cpu_macc) begin
		if (cpu_addr <= 16'h00ff) begin
			rom_cs = 1;
		end else if (cpu_addr >= 16'h4000 && cpu_addr <= 16'h47ff) begin
			ram_cs = 1;
		end else if (cpu_addr >= 16'h8000 && cpu_addr <= 16'h81ff) begin
			stage_cs = 1;
		end else if (cpu_addr >= 16'hc000 && cpu_addr <= 16'hc7ff) begin
			cf_cs = 1;
		end
	end
end

wire cpu_wr = cpu_macc & ~wr_n & ce_cpu;
wire cf_wr  = cpu_wr & cf_cs;

// input data mux (combinational, matches original timing)
always @* begin
	cpu_din = rom_cs   ? rom_q     :
	          ram_cs   ? ram_dout  :
	          stage_cs ? staging_q :
	                     8'hff;
end

// ---------------------------------------------------------------------
// Shared sprite staging RAM -- ownership & arbitration contract
//   * main CPU: async side port (main_addr/main_data/main_we), same
//     clk/cen domain as this CPU -- NOT a CDC boundary.
//   * sprite CPU: read-only access on its own bus, decoded via stage_cs.
//   * arbitration: main CPU is the sole writer to this array; the sprite
//     CPU never asserts a write to it in this module, so there is no
//     simultaneous-write conflict to resolve.
// First bus phase (staging RAM -> internal work RAM) only touches this
// CPU's private RAM; it never drove the displayed sprite RAM on hardware.
// ---------------------------------------------------------------------
reg [7:0] staging_ram [0:511];
reg [7:0] staging_q;

always @(posedge clk) begin
	staging_q <= staging_ram[cpu_addr[8:0]];
	if (main_we) staging_ram[main_addr] <= main_data;
end

// CF37201 doorway write latch
always @(posedge clk) begin
	cf_we <= 0;
	if (pcb_fidelity && cf_wr) begin
		cf_addr <= cpu_addr[10:0];
		cf_data <= cpu_dout;
		cf_we   <= 1;
	end
	if (!pcb_fidelity) cf_we <= 0;
end

// interrupts
always @(posedge clk) begin
	if (reset) begin
		nmi_n <= 1;
		int_n <= 1;
	end else begin
		if (nmi_req) nmi_n <= 0;
		else if (ce_cpu) nmi_n <= 1;
		if (int_ack) int_n <= 1;
		if (pcb_fidelity && cf_irq_req) int_n <= 0;
		if (!pcb_fidelity) int_n <= 1;
	end
end

wire _unused = rd_n;

jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(0),.RECOVERY(1)) u_cpu
(
	.rst_n      ( rst_n       ),
	.clk        ( clk         ),
	.cen        ( ce_cpu & ~pause ),
	.cpu_cen    (             ),
	.int_n      ( int_n       ),
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

endmodule
