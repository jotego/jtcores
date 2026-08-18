// UNVERIFIED DRAFT -- ported from mrdo/rtl/docastle_spritecpu.sv onto
// jtframe's CPU/SDRAM boundary, not yet compiled or simulated against real
// jtframe tooling (Docker toolchain was down for the whole of this port
// attempt).
//
// 8301 sprite/protection Z80 and the board's 0x200-byte sprite doorway.
//
// The main CPU writes an addressable staging latch at 0x9800/0x3800/0x5800.
// CPU3 reads that window at 0x8000, copies it through its 0x4321 work area,
// and then streams the protected bytes to the CF37201 doorway at 0xc000.
// copy_we observes the first transfer; cf_we is exclusively the real second
// transfer. Keeping those phases separate is important to the board timing
// (unchanged from the original module's own header -- this is real
// PCB-accuracy work and none of that bus-phase logic below has been
// simplified).
//
// Changes vs. the original docastle_spritecpu.sv, and why:
//   1. T80se instantiated directly -> jtframe_sysz80 (RAM_AW=11). Same
//      integration pattern as jtdocastle_main.v's u_cpu (see that file's
//      header note 1).
//   2. TWO local RAM blocks existed in the original module, and they are
//      NOT treated the same way:
//        - `work_ram[0:2047]` (cpu_addr[10:0], ram_cs 0x4000-0x47ff) is a
//          plain Z80-only work RAM -- exactly the case jtframe_sysz80's
//          wrapper is built for. It is REMOVED and now lives inside
//          jtframe_sysz80's own jtframe_dual_nvram; RAM_AW=11 exactly
//          covers its 2048-byte, 11-bit-addressed window. ram_cs/ram_dout
//          are wired to the wrapper; every use of the old `work_q` read
//          register in the cpu_din mux is now `ram_dout`.
//        - `staging_ram[0:511]` (cpu_addr[8:0], stage_cs 0x8000-0x81ff) is
//          NOT a Z80-only RAM: it is genuinely dual-ported, written live
//          every cycle by the MAIN CPU's own `main_addr`/`main_data`/
//          `main_we` port (the addressable staging latch described above),
//          independent of this CPU's own bus cycles. jtframe_sysz80's
//          second RAM port (prog_addr/prog_data/prog_we) is an NVRAM
//          dump/restore path meant for save-state/reset use, not a live
//          cross-CPU write port during normal operation -- so it is NOT a
//          substitute for this array. `staging_ram` is therefore KEPT
//          EXACTLY AS IN THE ORIGINAL, as this module's own local
//          dual-port BRAM, completely UNCHANGED (declaration, `staging_q`
//          read register, `main_we` write, and the `stage_cs` read-mux
//          term are all untouched).
//   3. NEW input `rom_ok`, same reasoning as jtdocastle_main.v note 3: ROM
//      is now SDRAM-backed with variable latency, and jtframe_sysz80
//      internally inserts Z80 WAIT states while `rom_cs && !rom_ok`. The
//      rom_cs decode itself (cpu_addr <= 0x00ff, a 256-byte window) is
//      UNCHANGED -- it is now given an explicit wire name so it can drive
//      both the wrapper's rom_cs input and the existing cpu_din read mux
//      (which previously spelled the same condition out inline).
//   4. PLACEHOLDER, NOT VERIFIED: same caveat as jtdocastle_main.v note 4 --
//      this module still exposes rom_q/rom_addr at its own boundary
//      unchanged, and the caller is expected to wire a mem.yaml-generated
//      "spritecpu" bus (e.g. spritecpu_addr/spritecpu_data/spritecpu_ok) to
//      them once real jtframe codegen is available to confirm the exact
//      generated port names.
//   5. CLR_INT(0) chosen, but for a DIFFERENT reason than main/sub: this
//      module's local `int_n` register is NOT a raw external level -- it
//      already implements its OWN M1/IORQ-ack-based interrupt clearing
//      (`int_ack = ~m1_n & ~iorq_n`; `int_n` is forced low while
//      `pcb_fidelity && cf_irq_req`, and cleared back to 1 on `int_ack`,
//      exactly matching jtframe_z80's own CLR_INT=1 latch-and-clear-on-ack
//      pattern, just implemented locally with different set conditions).
//      Using CLR_INT(1) here would apply a SECOND, redundant layer of
//      edge-triggered latching on top of a signal this module already
//      resolves to a final level itself, changing this CPU's
//      PCB-accuracy-critical IRQ timing. CLR_INT(0) keeps the existing
//      local `int_n`/`nmi_n` generation logic completely UNCHANGED and
//      just feeds the already-resolved level into the wrapper's raw
//      int_n/nmi_n ports, same class of reasoning as jtdocastle_main.v's
//      note 5 and jtdocastle_sub.v's note 5 (don't let the wrapper re-latch
//      a signal that is already a final level at this module's boundary).
//   6. NO WAIT-handshake open question applies to this file. The original
//      T80se's WAIT_n pin was tied `1'b1` (never asserted) in
//      docastle_spritecpu.sv -- this CPU never had an external WAIT
//      dependency of any kind, unlike main's comm_wait_n (see
//      jtdocastle_main.v) or sub's PSG-busy WAIT_n (see jtdocastle_sub.v).
//      jtframe_sysz80 exposing no general external WAIT_n input therefore
//      loses nothing here; there is nothing to flag or resolve.
//   7. Everything else -- the profile-independent memory map (ram_cs/
//      stage_cs/cf_cs), the copy_window/cf_wr staging-to-doorway streaming
//      logic, and pcb_fidelity gating -- is UNCHANGED logic, only
//      re-hosted in this file.
//
// MAME reference: src/mame/universal/docastle.cpp (unchanged from the
// original module's own header).

module jtdocastle_spritecpu
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
	// No NVRAM pins: jtframe_sysz80 does not expose prog_addr/prog_data/
	// prog_din/prog_we -- see the note in jtdocastle_main.v. (This was
	// also never related to `staging_ram` below -- see header note 2.)
	// ROM/RAM access
	.ram_cs     ( ram_cs      ),
	.rom_cs     ( rom_cs      ),
	.rom_ok     ( rom_ok      )
);

assign rom_addr = cpu_addr[8:0];
assign cpu_addr_debug = cpu_addr;

// staging_ram is genuinely dual-ported (live cross-CPU write from the main
// CPU's own main_addr/main_data/main_we), so it is KEPT EXACTLY AS IN THE
// ORIGINAL -- see header note 2. Only work_ram moved into jtframe_sysz80.
(* ramstyle = "M10K, no_rw_check" *) reg [7:0] staging_ram [0:511];
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
