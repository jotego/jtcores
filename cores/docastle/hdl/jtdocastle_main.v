// UNVERIFIED DRAFT -- ported from mrdo/rtl/docastle_main.sv onto jtframe's
// CPU/SDRAM boundary, not yet compiled or simulated against real jtframe
// tooling (Docker toolchain was down for the whole of this port attempt).
//
// Changes vs. the original docastle_main.sv, and why:
//   1. T80se instantiated directly -> jtframe_sysz80 (RAM_AW=13). The
//      wrapper fuses the Z80, its own work RAM (jtframe_dual_nvram), and a
//      rom_cs/rom_ok wait-state generator (jtframe_z80_romwait) in one
//      module -- this is jtframe's standard CPU/SDRAM integration pattern
//      (confirmed against modules/jtframe/hdl/cpu/jtframe_z80.v and
//      cores/flstory/hdl/jtflstory_main.v's real u_cpu instance).
//   2. The local `work_ram[0:6143]` BRAM block and its ram_cs read/write
//      logic are REMOVED -- that RAM now lives inside jtframe_sysz80's own
//      jtframe_dual_nvram (RAM_AW=13 exactly covers the original 6144-byte,
//      13-bit-addressed window: cpu_addr[12:0]). ram_cs/ram_dout are wired
//      to the wrapper instead of a locally-inferred array.
//   3. NEW input `rom_ok`. The original module assumed the ROM store
//      (docastle_rom.sv) always returned valid data with fixed 1-cycle
//      latency, so it never needed to wait for ROM. Under jtframe, ROM is
//      SDRAM-backed with variable latency, and jtframe_sysz80 internally
//      inserts Z80 WAIT states while `rom_cs && !rom_ok`. rom_cs itself is
//      unchanged -- it's the same profile-dependent address decode as
//      before, now doubling as the wrapper's wait-state qualifier.
//   4. PLACEHOLDER, NOT VERIFIED: this module still exposes `rom_q`/
//      `rom_addr` at its own boundary (unchanged names) so the caller
//      (jtdocastle_game.v) is expected to wire mem.yaml's generated `main`
//      bus ports to them (main_data->rom_q, cpu_addr->main_addr,
//      main_ok->rom_ok). The exact generated port names for a mem.yaml bus
//      named "main" were NOT confirmed by running jtframe's codegen (Docker
//      down) -- "main_addr"/"main_data"/"main_ok" is the naming pattern
//      seen used elsewhere in this codebase's convention, but treat it as
//      an assumption to verify once the toolchain works.
//   5. CLR_INT(0) chosen to match the original's direct `.INT_n(irq_n)`
//      pass-through (a raw level-sensitive interrupt line, not latched by
//      M1/IORQ) -- see jtframe_z80.v's CLR_INT parameter doc. This differs
//      from flstory's own CLR_INT(1) choice; flstory's IRQ source works
//      differently and is not evidence for how docastle's should behave.
//   6. Everything else -- the profile-dependent memory map (rom_cs/ram_cs/
//      sprite_cs/video_cs/color_cs/comm_cs/adpcm_cs/nmi_cs/watchdog_cs),
//      the edge-detected write/read logic, the CRTC register-write
//      protocol, sub-CPU NMI request, and the comm/adpcm/sprite/video/color
//      port list -- is UNCHANGED logic, only re-hosted in this file.
//
// MAME reference: src/mame/universal/docastle.cpp main_map variants
// (unchanged from the original module's own header).

module jtdocastle_main
(
	input         rst,
	input         clk,
	input         ce_cpu,
	input         pause,
	input   [1:0] profile,
	input         irq_n,

	input   [7:0] rom_q,
	output [15:0] rom_addr,
	output        rom_cs,       // NEW (2nd pass): exposed so jtdocastle_game.v can
	                            // drive mem.yaml's `main_cs` SDRAM-slot request.
	                            // The decode itself is UNCHANGED -- it was already
	                            // computed internally as a local wire; the wire
	                            // declaration simply became a port + assign.
	input         rom_ok,       // NEW: SDRAM-fetch-ready qualifier, see header note 3/4

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
wire cpu_ena = ce_cpu & ~pause;
wire [15:0] cpu_addr;
wire  [7:0] cpu_dout;
wire  [7:0] ram_dout;
reg   [7:0] cpu_din;
wire m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, rst_n;

assign rst_n = ~rst;

// OPEN QUESTION, not resolved in this draft: the original T80se's WAIT_n
// port carried ONLY the cross-CPU comm_wait_n handshake (main/sub WAIT
// protocol), with no ROM-wait mechanism (see header note 3). jtframe_sysz80
// generates its own internal WAIT for rom_cs/rom_ok and does not expose a
// combined external WAIT_n input the way T80se did -- so the comm_wait_n
// handshake needs a different injection point than "WAIT_n" once real
// jtframe tooling is available to check jtframe_z80_romwait's exact wait
// arbitration. For this draft, comm_wait_n is threaded through unchanged at
// the port boundary but is NOT yet wired into the CPU wrapper -- flagged
// here rather than silently guessed. This is exactly the main/sub
// WAIT-handshake timing this core's README calls out as real PCB-accuracy
// work; it must not be paved over with a guess.

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
	// No NVRAM pins here: jtframe_sysz80 does not expose prog_addr/
	// prog_data/prog_din/prog_we -- it instantiates jtframe_sysz80_nvram
	// internally and ties them off itself (jtframe_z80.v). Connecting them
	// was a drafting error, caught by the first real Verilator lint run.
	// ROM/RAM access
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
