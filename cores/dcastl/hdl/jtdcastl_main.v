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
	output        rom_cs,       // exposed so jtdcastl_game.v can drive
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
	output reg       sub_nmi_req,
	output           watchdog_kick,

	output [15:0] cpu_addr_debug,
	output        m1_n_debug,
	output        iorq_n_debug
);

localparam [1:0] PROFILE_CASTLE = 2'd0;
localparam [1:0] PROFILE_RUNRUN = 2'd1;
localparam [1:0] PROFILE_SOCCER = 2'd2;

wire is_runrun = profile == PROFILE_RUNRUN;
wire is_soccer = profile == PROFILE_SOCCER;
wire cpu_ena = ce_cpu & ~pause & comm_wait_n;
wire [15:0] cpu_addr;
wire  [7:0] cpu_dout;
wire  [7:0] ram_dout;
reg   [7:0] cpu_din;
wire m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, rst_n;

assign rst_n = ~rst;

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

wire mem_cycle = ~mreq_n & rfsh_n & (~rd_n | ~wr_n);
wire wr_level  = mem_cycle & ~wr_n;
wire rd_level  = mem_cycle & ~rd_n;
wire io_wr_level = ~iorq_n & ~wr_n;
reg wr_d, rd_d, io_wr_d;
wire wr_edge = wr_level & ~wr_d;
wire rd_edge = rd_level & ~rd_d;
wire io_wr_edge = io_wr_level & ~io_wr_d;

assign rom_cs = (profile == PROFILE_CASTLE)
	? (cpu_addr < 16'h8000)
	: is_runrun
		? ((cpu_addr < 16'h2000) || ((cpu_addr >= 16'h4000) && (cpu_addr <= 16'h9fff)))
		: ((cpu_addr < 16'h4000) || ((cpu_addr >= 16'h6000) && (cpu_addr <= 16'h9fff)));

wire ram_cs = (profile == PROFILE_CASTLE)
	? ((cpu_addr >= 16'h8000) && (cpu_addr <= 16'h97ff))
	: is_runrun
		? ((cpu_addr >= 16'h2000) && (cpu_addr <= 16'h37ff))
		: ((cpu_addr >= 16'h4000) && (cpu_addr <= 16'h57ff));

wire sprite_cs = (profile == PROFILE_CASTLE)
	? ((cpu_addr >= 16'h9800) && (cpu_addr <= 16'h99ff))
	: is_runrun
		? ((cpu_addr >= 16'h3800) && (cpu_addr <= 16'h39ff))
		: ((cpu_addr >= 16'h5800) && (cpu_addr <= 16'h59ff));

wire comm_cs = (cpu_addr >= 16'ha000) && (cpu_addr <= 16'ha7ff);
wire video_cs = is_runrun
	? ((cpu_addr >= 16'hb000) && (cpu_addr <= 16'hb3ff))
	: ((cpu_addr[15:12] == 4'hb) && !cpu_addr[10]);
wire color_cs = is_runrun
	? ((cpu_addr >= 16'hb400) && (cpu_addr <= 16'hb7ff))
	: ((cpu_addr[15:12] == 4'hb) && cpu_addr[10]);
wire adpcm_cs = is_soccer && (cpu_addr == 16'hc000);
wire nmi_cs = is_runrun ? (cpu_addr == 16'hb800) : (cpu_addr == 16'he000);
wire watchdog_cs = cpu_addr == 16'ha800;

assign sprite_addr = cpu_addr[8:0];
assign sprite_din  = cpu_dout;
assign sprite_we   = wr_edge & sprite_cs;
assign video_addr  = cpu_addr[9:0];
assign video_din   = cpu_dout;
assign video_we    = wr_edge & video_cs;
assign color_addr  = cpu_addr[9:0];
assign color_din   = cpu_dout;
assign color_we    = wr_edge & color_cs;
assign comm_start  = (wr_edge | rd_edge) & comm_cs;
assign comm_write  = wr_edge & comm_cs;
assign comm_dout   = cpu_dout;
assign adpcm_wr    = wr_edge & adpcm_cs;
assign adpcm_data  = cpu_dout;
assign watchdog_kick = wr_edge & watchdog_cs;

always @(*) begin
	cpu_din = 8'hff;
	if (rom_cs)            cpu_din = rom_q;
	else if (ram_cs)       cpu_din = ram_dout;
	else if (comm_cs)      cpu_din = comm_latch;
	else if (video_cs)     cpu_din = video_dout;
	else if (color_cs)     cpu_din = color_dout;
	else if (adpcm_cs)     cpu_din = adpcm_status;
end

always @(posedge clk) begin
	if (rst) begin
		wr_d <= 0;
		rd_d <= 0;
		io_wr_d <= 0;
		crtc_reg <= 0;
		crtc_data <= 0;
		crtc_we <= 0;
		sub_nmi_req <= 0;
	end else begin
		wr_d <= wr_level;
		rd_d <= rd_level;
		io_wr_d <= io_wr_level;
		crtc_we <= 0;
		sub_nmi_req <= 0;

		if (wr_edge && nmi_cs)
			sub_nmi_req <= 1;

		if (io_wr_edge) begin
			case (cpu_addr[7:0])
			8'h00: crtc_reg <= cpu_dout[4:0];
			8'h02: begin
				crtc_data <= cpu_dout;
				crtc_we <= 1;
			end
			default: ;
			endcase
		end
	end
end

endmodule
