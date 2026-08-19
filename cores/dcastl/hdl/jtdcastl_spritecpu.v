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
	output reg [8:0] copy_addr,
	output reg [7:0] copy_data,
	output reg       copy_we,
	output reg [10:0] cf_addr,
	output reg  [7:0] cf_data,
	output reg        cf_we,
	output            cf_irq_ack,
	output [15:0] cpu_addr_debug
);

reg nmi_n;
reg int_n;
wire [15:0] cpu_addr;
wire [7:0] cpu_dout;
wire [7:0] ram_dout;
reg  [7:0] cpu_din;
wire m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, rst_n;
wire int_ack = ~m1_n & ~iorq_n;
assign cf_irq_ack = int_ack;

assign rst_n = ~reset;

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

assign rom_addr = cpu_addr[8:0];
assign cpu_addr_debug = cpu_addr;

reg [7:0] staging_ram [0:511];
reg [7:0] staging_q;
wire stage_cs = (cpu_addr >= 16'h8000) && (cpu_addr <= 16'h81ff);
wire rom_cs = cpu_addr <= 16'h00ff;
wire ram_cs = (cpu_addr >= 16'h4000) && (cpu_addr <= 16'h47ff);
wire cf_cs = (cpu_addr >= 16'hc000) && (cpu_addr <= 16'hc7ff);
wire mem_wr = ~mreq_n & ~wr_n & rfsh_n & ce_cpu;
wire ram_wr = mem_wr & ram_cs;
wire cf_wr = mem_wr & cf_cs;
wire copy_window = (cpu_addr >= 16'h4321) && (cpu_addr <= 16'h4520);

always @(posedge clk) begin
	staging_q <= staging_ram[cpu_addr[8:0]];
	if (main_we) staging_ram[main_addr] <= main_data;

	copy_we <= 0;
	cf_we <= 0;
	if (pcb_fidelity && ram_wr && copy_window) begin
		copy_addr <= cpu_addr[8:0] - 9'h121;
		copy_data <= cpu_dout;
		copy_we <= 1;
	end
	if (pcb_fidelity && cf_wr) begin
		cf_addr <= cpu_addr[10:0];
		cf_data <= cpu_dout;
		cf_we <= 1;
	end
	if (!pcb_fidelity) begin
		copy_we <= 0;
		cf_we <= 0;
	end
end

always @(*) begin
	cpu_din = 8'hff;
	if (rom_cs) cpu_din = rom_q;
	else if (ram_cs) cpu_din = ram_dout;
	else if (stage_cs) cpu_din = staging_q;
end

wire _unused = rd_n;
endmodule
