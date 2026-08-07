// jtsuperman_cchip.v — real-MCU-backed C-chip wrapper for Superman.
//
// Adapted from Fulvio's jtrisle_cchip_mcu.v (Rainbow Islands C-chip
// wrapper, originally MAME-derived, BSD-3-Clause). The CPU core
// jtsuperman_upd78c11 is also Fulvio's work, untouched aside from
// the module rename. This file currently lives inside the Superman
// core; once a second Taito-C-chip game lands it likely graduates to
// modules/jt78c11/ (or similar) as a shared core. See STATUS.md for
// the chain of custody.
//
// Wraps jtsuperman_upd78c11 with the full C-chip memory subsystem:
//   - 4 KB mask ROM          ($0000-$0FFF, read-only, from mask_rom.mem)
//   - 8 KB shared SRAM       (dual-ported: MCU at $1000-$13FF via bank_mcu,
//                             68k sees bank 0 directly — Superman has no
//                             68k-side bank register, unlike Rainbow Is.)
//   - 4 ASIC registers       (dual-ported: MCU at $1400-$1403, 68k at $400-$403)
//   - MCU bank register      (MCU writes $1600 -> bank_mcu[2:0])
//   - 8 KB game EPROM        ($2000-$3FFF, read-only, loaded from the MRA;
//                             this is b61_11.m11 for Superman)
//   - 256 B MCU internal RAM ($FF00-$FFFF)
//
// Memory map seen by the 68k (relative to 0x900000, byte addressing,
// only low byte wired per MAME's umask16(0x00ff)):
//   $000-$7FF : shared SRAM (1 KB effective, 1024 valid bytes at odd
//                            byte addresses) — taito_cchip_device::mem68
//   $800-$FFF : ASIC regs   (4 unique slots, region mirrors them) —
//                            taito_cchip_device::asic_r / asic68_w
//
// Plus the bring-up scaffolding that the ver/upd78c11 tb has been
// carrying: mask-ROM $1401 command-inject chain, $060D-gated IRQ re-
// arm, and the synthetic task-state plant. All of that is gated by
// the BRING_UP parameter and goes away once the real 68k drives
// commands through the bus.
//
// IRQ output (int_n) is still stubbed high — wiring com_int_latch
// from an MCU memory-write marker is the next incremental milestone
// after the 68k read/write path is proved.

`timescale 1ns/1ps

module jtsuperman_cchip #(
    parameter [0:0] BRING_UP      = 1'b1   // 0 = rely on real 68k + timers
)(
    input             clk,
    input             rstn,

    // ---- 68k side (0x800000, 8-bit on lower byte) ----
    input             cs,
    input      [11:1] addr,
    input      [ 7:0] din,
    output     [ 7:0] dout,
    input             we,
    input             uds_n,
    input             lds_n,
    output            dtack_n,
    output            int_n,
    input             com_res_n,

    // ---- Game-specific C-chip EPROM ----
    // For Superman the 8 KB EPROM (b61_11.m11) is baked into the
    // bitstream via $readmemh of cchip_eprom.mem. Once the MRA-driven
    // prom-load path is wired we'll switch to external epr_addr/data
    // again; for the current bring-up keeping it internal removes one
    // layer of wiring to debug.

    // ---- MCU port inputs ----
    input      [ 7:0] port_pa,
    input      [ 7:0] port_pb,
    input      [ 7:0] port_pc,
    input      [ 7:0] port_pd,
    input      [ 7:0] port_cr0,
    input      [ 7:0] port_cr1,
    input      [ 7:0] port_cr2,
    input      [ 7:0] port_cr3,

    // ---- MCU port outputs ----
    output     [ 7:0] port_pa_out,
    output     [ 7:0] port_pb_out,
    output     [ 7:0] port_pc_out,
    output     [ 7:0] port_pd_out,
    output     [ 7:0] port_pf_out,

    // ---- 60 Hz tick (unused; will drive INTFT0 when timers land) ----
    input             ext_tick,

    // ---- Debug taps (consumed by the TSV harness) ----
    output     [15:0] dbg_pc,
    output     [15:0] dbg_pc_next,
    output      [7:0] dbg_a, dbg_v,
    output     [15:0] dbg_bc, dbg_de, dbg_hl, dbg_ea, dbg_sp,
    output      [7:0] dbg_psw,
    output            dbg_iff,
    output      [7:0] dbg_ap, dbg_vp,
    output     [15:0] dbg_bcp, dbg_dep, dbg_hlp, dbg_eap,
    output      [7:0] dbg_mm, dbg_mkh, dbg_mkl,
    output            dbg_retire, dbg_trap
);

    // --------------------------------------------------------------------
    // Storage (one BRAM-equivalent per region).
    // --------------------------------------------------------------------
    (* ramstyle = "no_rw_check, m9k" *) reg [7:0] mask_rom   [0:4095]; // $0000-$0FFF
    (* ramstyle = "no_rw_check, m9k" *) reg [7:0] eprom      [0:8191]; // $2000-$3FFF (b61_11.m11)
    (* ramstyle = "no_rw_check, m9k" *) reg [7:0] shared_ram [0:8191]; // bank-switched, dual-ported
    reg [7:0] asic_ram   [0:3];      // $1400-$1403 MCU / $400-$403 68k
    (* ramstyle = "no_rw_check, m9k" *) reg [7:0] mcu_ram    [0:255];  // $FF00-$FFFF

    reg [2:0] bank_mcu;
    reg [2:0] bank_68k;

    integer   i;
    initial begin
        for (i = 0; i < 4096;  i = i + 1) mask_rom[i]   = 8'hFF;
        // Quartus caps initial-loop unrolling at 5000 iterations.  Split
        // the 8192-entry eprom init into two 4096-iter halves so both
        // sides fit under the cap (same pattern used by shared_ram below).
        for (i = 0;    i < 4096; i = i + 1) eprom[i]      = 8'hFF;
        for (i = 4096; i < 8192; i = i + 1) eprom[i]      = 8'hFF;
        // Match the old unified-$FF pre-boot so reads of un-initialized
        // bytes produce the same values the upd78c11 golden was captured
        // with.  Real silicon: shared_ram and asic_ram are DRAM/flip-flops
        // with undefined reset state; the mask ROM zeros what it needs.
        for (i = 0; i < 4096;  i = i + 1) shared_ram[i] = 8'hFF;
        for (i = 4096; i < 8192;  i = i + 1) shared_ram[i] = 8'hFF;
        for (i = 0; i < 4;     i = i + 1) asic_ram[i]   = 8'hFF;
        for (i = 0; i < 256;   i = i + 1) mcu_ram[i]    = 8'hFF;
        $readmemh("mask_rom.mem",    mask_rom);
        $readmemh("cchip_eprom.mem", eprom);
        $display(">>>> cchip init: mask_rom[0]=%02x mask_rom[FFF]=%02x eprom[0]=%02x eprom[1FFF]=%02x",
                 mask_rom[0], mask_rom[12'hFFF], eprom[0], eprom[13'h1FFF]);
    end

    // --------------------------------------------------------------------
    // MCU-side memory map.
    // --------------------------------------------------------------------
    wire [15:0] mcu_addr;
    wire  [7:0] mcu_dout;
    wire        mcu_rd, mcu_wr;
    wire  [7:0] mcu_din;

    // Match MAME taitocchip.cpp cchip_map exactly:
    //   0x0000-0x0FFF : internal mask ROM
    //   0x1000-0x13FF : 1 KB window into 8 KB shared SRAM (banked by 0x1600)
    //   0x1400-0x17FF : ASIC region.  Writes to 0x1600 set bank_mcu;
    //                   every other offset in [0x1400-0x17FF] mirrors the
    //                   4-byte asic_ram (asic_w stores to m_asic_ram[off&3]
    //                   when offset != 0x200).  Reads return asic_ram for
    //                   offsets <0x200 (i.e. 0x1400-0x15FF) and 0 for the
    //                   upper half.
    //   0x2000-0x3FFF : external EPROM (b61_11.m11 for Superman)
    //   0xFF00-0xFFFF : 256 B internal RAM of the uPD78C11
    wire mcu_sel_mask = (mcu_addr <  16'h1000);
    wire mcu_sel_sram = (mcu_addr >= 16'h1000) && (mcu_addr < 16'h1400);
    wire mcu_sel_asic = (mcu_addr >= 16'h1400) && (mcu_addr < 16'h1800);
    // mcu_asic_lo (0x1400-0x15FF, the low ASIC bank) is decoded but the
    // MCU never reads/writes there in Superman's mask ROM — dropped to
    // silence Quartus warning 10036. Add back if a sibling game routes
    // commands through the low bank.
    wire mcu_sel_bank = (mcu_addr == 16'h1600);
    wire mcu_sel_epr  = (mcu_addr >= 16'h2000) && (mcu_addr < 16'h4000);
    wire mcu_sel_iram = (mcu_addr >= 16'hFF00);

    wire [12:0] mcu_sram_idx = {bank_mcu, mcu_addr[9:0]};
    reg  [ 7:0] eprom_dout;
    always @(posedge clk) eprom_dout <= eprom[mcu_addr[12:0]];
    wire        mcu_wr_sram  = mcu_wr && mcu_sel_sram;
    wire        mcu_wr_asic  = mcu_wr && mcu_sel_asic;
    wire        mcu_wr_bank  = mcu_wr && mcu_sel_bank;
    wire        mcu_wr_iram  = mcu_wr && mcu_sel_iram;

    // --------------------------------------------------------------------
    // 68k-side memory map.  Matches MAME taito_x.cpp / taitocchip.cpp:
    //
    //   $900000-$9007FF : 1 KB window into shared SRAM at bank_68k
    //                     (mem68_r/mem68_w — addr[11]=0, byte stride 2)
    //   $900800-$900FFF : ASIC region (asic_r / asic68_w)
    //       offset 0x200 (byte $900C00, addr[11:1]=11'h600)
    //                   : write bank_68k (low 3 bits of data)
    //       any other offset : mirror of the 4-byte asic_ram
    //
    // Superman absolutely uses the 68k-side bank — its boot sequence clears
    // banks 2, 1, 0 in turn via $2BD2 (`MOVE.B Dn, $900C01`) before writing
    // the J/F/4 handshake into bank 0.  The earlier note that "Superman has
    // no 68k-side bank register" was wrong.
    // --------------------------------------------------------------------
    wire k68_sel_ram  = cs & ~addr[11];                                    // $900000-$9007FF
    wire k68_sel_asic = cs &  addr[11];                                    // $900800-$900FFF
    wire k68_sel_bank = k68_sel_asic & (addr[10:1] == 10'h200);            // exact offset 0x200
    wire [9:0]  k68_ram_off  = addr[10:1];
    wire [1:0]  k68_asic_off = addr[2:1];
    wire [12:0] k68_sram_idx = {bank_68k, k68_ram_off};

    // --------------------------------------------------------------------
    // Writes.  Two writers per region — MCU via mcu_wr / mcu_dout, and
    // the 68k via cs/we/lds_n/addr/din.  If both writers target the same
    // cell on the same cycle, 68k wins (matches the behavioural model).
    // lds_n must be low for a byte write to land (the cchip's RAM lives
    // on the lower byte of the 16-bit word).
    // --------------------------------------------------------------------
    wire k68_wr     = cs & we & ~lds_n;
    wire k68_wr_ram  = k68_wr & k68_sel_ram;
    wire k68_wr_asic = k68_wr & k68_sel_asic;
    wire k68_wr_bank = k68_wr & k68_sel_bank;
    wire mcu_rstn    = rstn & com_res_n;
    wire mcu_wr_sram_ok = mcu_wr_sram &&
                          !(k68_wr_ram && (k68_sram_idx == mcu_sram_idx));

    reg       k68_rd_q;
    reg       k68_sel_ram_q;
    reg       k68_sel_asic_q;
    reg       k68_sel_bank_q;
    reg [7:0] k68_ram_dout;
    reg [7:0] k68_asic_dout;
    reg [7:0] k68_bank_dout;
    reg [7:0] mcu_mask_dout;
    reg [7:0] mcu_sram_dout;
    reg [7:0] mcu_asic_dout;
    reg [7:0] mcu_bank_dout;
    reg [7:0] mcu_iram_dout;
    reg       mcu_sel_mask_q;
    reg       mcu_sel_epr_q;
    reg       mcu_sel_sram_q;
    reg       mcu_sel_asic_q;
    reg       mcu_sel_bank_q;
    reg       mcu_sel_iram_q;

    assign dout = k68_sel_ram_q  ? k68_ram_dout  :
                  k68_sel_asic_q ? k68_asic_dout :
                  k68_sel_bank_q ? k68_bank_dout :
                                    8'hFF;

    assign mcu_din = mcu_sel_mask_q ? mcu_mask_dout :
                     mcu_sel_sram_q ? mcu_sram_dout :
                     mcu_sel_asic_q ? mcu_asic_dout :
                     mcu_sel_bank_q ? mcu_bank_dout :
                     mcu_sel_epr_q  ? eprom_dout    :
                     mcu_sel_iram_q ? mcu_iram_dout :
                                       8'hFF;

    assign dtack_n = ~((cs & we) | k68_rd_q);

    /* verilator lint_off MULTIDRIVEN */
    always @(posedge clk) begin
        k68_ram_dout <= shared_ram[k68_sram_idx];
        if (k68_wr_ram) shared_ram[k68_sram_idx] <= din;
    end

    always @(posedge clk) begin
        if (!mcu_rstn) begin
            k68_rd_q       <= 1'b0;
            k68_sel_ram_q  <= 1'b0;
            k68_sel_asic_q <= 1'b0;
            k68_sel_bank_q <= 1'b0;
            k68_asic_dout  <= 8'hFF;
            k68_bank_dout  <= 8'hFF;
        end else begin
            k68_rd_q       <= cs & ~we;
            k68_sel_ram_q  <= k68_sel_ram;
            k68_sel_asic_q <= k68_sel_asic;
            k68_sel_bank_q <= k68_sel_bank;
            k68_asic_dout  <= asic_ram[k68_asic_off];
            k68_bank_dout  <= {5'd0, bank_68k};
        end
    end

    always @(posedge clk) begin
        mcu_sram_dout <= shared_ram[mcu_sram_idx];
        if (mcu_wr_sram_ok) shared_ram[mcu_sram_idx] <= mcu_dout;
`ifdef VOLFIED_CCHIP_DEBUG
        if (mcu_wr_sram_ok && mcu_sram_idx[9:0] < 10'd256) begin
            $display("[%0t] MCU_W_SRAM  bank=%0d off=%03x  byte_addr=%04x  data=%02x  PA=%02x PB=%02x",
                     $time, bank_mcu, mcu_sram_idx[9:0], mcu_addr, mcu_dout,
                     port_pa, port_pb);
        end
`endif
    end

    always @(posedge clk) begin
        mcu_mask_dout <= mask_rom[mcu_addr[11:0]];
    end

    always @(posedge clk) begin
        mcu_iram_dout <= mcu_ram[mcu_addr[7:0]];
        if (mcu_wr_iram) mcu_ram[mcu_addr[7:0]] <= mcu_dout;
    end

    always @(posedge clk) begin
        if (!mcu_rstn) begin
            mcu_sel_mask_q <= 1'b0;
            mcu_sel_epr_q  <= 1'b0;
            mcu_sel_sram_q <= 1'b0;
            mcu_sel_asic_q <= 1'b0;
            mcu_sel_bank_q <= 1'b0;
            mcu_sel_iram_q <= 1'b0;
            mcu_asic_dout  <= 8'hFF;
            mcu_bank_dout  <= 8'hFF;
        end else begin
            mcu_sel_mask_q <= mcu_rd & mcu_sel_mask;
            mcu_sel_epr_q  <= mcu_rd & mcu_sel_epr;
            mcu_sel_sram_q <= mcu_rd & mcu_sel_sram;
            mcu_sel_asic_q <= mcu_rd & mcu_sel_asic;
            mcu_sel_bank_q <= mcu_rd & mcu_sel_bank;
            mcu_sel_iram_q <= mcu_rd & mcu_sel_iram;
            mcu_asic_dout  <= asic_ram[mcu_addr[1:0]];
            mcu_bank_dout  <= {5'd0, bank_mcu};
        end
    end
    /* verilator lint_on MULTIDRIVEN */

    always @(posedge clk) begin
        if (!mcu_rstn) begin
            bank_mcu <= 3'd0;
            bank_68k <= 3'd0;
        end else begin
            // ASIC RAM mirrors: any ASIC-region write that is *not* the
            // bank-set address lands in the 4-byte asic_ram (MAME pattern
            // `else { m_asic_ram[offset & 3] = data; }`).
            if      (k68_wr_asic & ~k68_sel_bank) asic_ram[k68_asic_off]   <= din;
            else if (mcu_wr_asic & ~mcu_sel_bank) asic_ram[mcu_addr[1:0]]  <= mcu_dout;
            // Bank regs (each side has its own — 68k via $900C01 / MCU via $1600)
            if (k68_wr_bank)                      bank_68k <= din[2:0];
            if (mcu_wr_bank)                      bank_mcu <= mcu_dout[2:0];
`ifdef VOLFIED_CCHIP_DEBUG
            if (k68_wr_bank && din[2:0] != bank_68k)
                $display("[%0t] BANK_68K  %0d -> %0d  (68k write @addr=%03x din=%02x)",
                         $time, bank_68k, din[2:0], addr, din);
            if (mcu_wr_bank && mcu_dout[2:0] != bank_mcu)
                $display("[%0t] BANK_MCU  %0d -> %0d  (MCU write @addr=%04x data=%02x)",
                         $time, bank_mcu, mcu_dout[2:0], mcu_addr, mcu_dout);
`endif
        end
    end

    // --------------------------------------------------------------------
    // IRQ output to the 68k — stubbed until the command-complete handler
    // marker is identified.  When that lands the MCU writes to a known
    // ASIC reg / shared RAM byte with a specific value and the latch
    // goes high until the 68k reads the status register.
    // --------------------------------------------------------------------
    assign int_n = 1'b1;

    // --------------------------------------------------------------------
    // MCU instance.
    // --------------------------------------------------------------------
    reg ext_int1_req;
    reg dbg_force_iff;
    jtsuperman_upd78c11 u_mcu (
        .clk         (clk),
        .rstn        (mcu_rstn),
        .mem_addr    (mcu_addr),
        .mem_dout    (mcu_dout),
        .mem_rd      (mcu_rd),
        .mem_wr      (mcu_wr),
        .mem_din     (mcu_din),
        .pa_in       (port_pa),
        .pb_in       (port_pb),
        .pc_in       (port_pc),
        .pd_in       (port_pd),
        .cr0_in      (port_cr0),
        .cr1_in      (port_cr1),
        .cr2_in      (port_cr2),
        .cr3_in      (port_cr3),
        .pa_out      (port_pa_out),
        .pb_out      (port_pb_out),
        .pc_out      (port_pc_out),
        .pd_out      (port_pd_out),
        .pf_out      (port_pf_out),
        .ext_int1_req(ext_int1_req),
        .dbg_force_iff(dbg_force_iff),
        .dbg_pc      (dbg_pc),
        .dbg_pc_next (dbg_pc_next),
        .dbg_a       (dbg_a),
        .dbg_v       (dbg_v),
        .dbg_bc      (dbg_bc),
        .dbg_de      (dbg_de),
        .dbg_hl      (dbg_hl),
        .dbg_ea      (dbg_ea),
        .dbg_sp      (dbg_sp),
        .dbg_psw     (dbg_psw),
        .dbg_iff     (dbg_iff),
        .dbg_ap      (dbg_ap),
        .dbg_vp      (dbg_vp),
        .dbg_bcp     (dbg_bcp),
        .dbg_dep     (dbg_dep),
        .dbg_hlp     (dbg_hlp),
        .dbg_eap     (dbg_eap),
        .dbg_mm      (dbg_mm),
        .dbg_mkh     (dbg_mkh),
        .dbg_mkl     (dbg_mkl),
        .dbg_retire  (dbg_retire),
        .dbg_trap    (dbg_trap)
    );

    // --------------------------------------------------------------------
    // Sink unused 68k inputs so lint is clean.  ext_tick is used in the
    // BRING_UP=0 generate branch, so it doesn't appear here even though
    // BRING_UP=1 ignores it.
    //
    // Wrapped in synthesis translate_off so Verilator (sim/lint) still
    // sees the sink — keeping the UNUSED warning suppressed — but
    // Quartus skips it during synthesis and doesn't emit warning 10036.
    // --------------------------------------------------------------------
    // synthesis translate_off
    wire _unused_68k = &{1'b0, uds_n};
    // synthesis translate_on

    // --------------------------------------------------------------------
    // Bring-up scaffolding.  Mask-ROM $1401 command-inject chain,
    // $060D-gated IRQ re-arm with retire-counted cooldown, synthetic
    // task-state plant.  Drops away when BRING_UP=0.
    // --------------------------------------------------------------------
    generate if (BRING_UP) begin : g_bringup
        localparam [15:0] IRQ_COOLDOWN = 16'd1500;

        reg inj01_pending, inj01_done;
        reg inj0a_pending, inj0a_done;
        always @(posedge clk) begin
            if (!rstn) begin
                inj01_pending <= 0;  inj01_done <= 0;
                inj0a_pending <= 0;  inj0a_done <= 0;
            end else begin
                if (!inj01_done && mcu_wr && mcu_addr == 16'h1401 && mcu_dout == 8'h01)
                    inj01_pending <= 1'b1;
                if (inj01_pending) begin
                    asic_ram[1]   <= 8'h03;
                    inj01_pending <= 0;
                    inj01_done    <= 1;
                end
                if (inj01_done && !inj0a_done && mcu_wr && mcu_addr == 16'h1401 && mcu_dout == 8'h0A)
                    inj0a_pending <= 1'b1;
                if (inj0a_pending) begin
                    asic_ram[1]   <= 8'h0B;
                    inj0a_pending <= 0;
                    inj0a_done    <= 1;
                end
            end
        end

        reg        irq_armed = 1'b0;
        reg [15:0] retires_since_pulse = 16'hFFFF;
        always @(posedge clk) begin
            if (!rstn) begin
                ext_int1_req        <= 1'b0;
                dbg_force_iff       <= 1'b0;
                irq_armed           <= 1'b0;
                retires_since_pulse <= 16'hFFFF;
            end else begin
                ext_int1_req  <= 1'b0;
                dbg_force_iff <= 1'b0;
                if (dbg_retire && retires_since_pulse != 16'hFFFF)
                    retires_since_pulse <= (retires_since_pulse == 16'hFFFE)
                                           ? 16'hFFFF
                                           : retires_since_pulse + 16'd1;
                if (dbg_retire && dbg_pc == 16'h060D &&
                    retires_since_pulse >= (IRQ_COOLDOWN - 16'd1)) begin
                    irq_armed <= 1'b1;
                    // $FF9B=1 -> ISR path B ($20A0, CALL $20CF -> mask $09D0)
                    mcu_ram[8'h9B] <= 8'h01;
                    // $FF00=1 -> $04DB A!=0 branch -> EXX at $0506
                    mcu_ram[8'h00] <= 8'h01;
                    // Synthetic task-state block
                    mcu_ram[8'h03] <= 8'h12;
                    mcu_ram[8'h04] <= 8'hFF;
                    mcu_ram[8'h12] <= 8'h11;
                    mcu_ram[8'h13] <= 8'h22;
                    mcu_ram[8'h14] <= 8'h33;
                    mcu_ram[8'h15] <= 8'h44;
                    mcu_ram[8'h16] <= 8'h55;
                    mcu_ram[8'h17] <= 8'h66;
                    mcu_ram[8'h18] <= 8'h77;
                    mcu_ram[8'h19] <= 8'h88;
                    mcu_ram[8'h22] <= 8'hAD;
                    mcu_ram[8'h23] <= 8'h20;
                    mcu_ram[8'h2E] <= 8'h0D;
                    mcu_ram[8'h2F] <= 8'h06;
                    mcu_ram[8'h30] <= 8'h00;
                end
                if (irq_armed) begin
                    ext_int1_req        <= 1'b1;
                    dbg_force_iff       <= 1'b1;
                    irq_armed           <= 1'b0;
                    retires_since_pulse <= 16'd0;
                end
            end
        end
    end else begin : g_real_68k
        // Real-mode wiring.  Matches what rbisland.cpp does in MAME:
        // VBLANK raises INTF1 via ext_interrupt(ASSERT_LINE); a timer
        // clears it via ext_interrupt(CLEAR_LINE).  We treat ext_tick
        // as the level-hold INTF1 signal — caller holds it high for
        // one+ clocks on frame start and low the rest of the frame,
        // same as the `m_cchip_irq_clear` timer pattern.
        //
        // dbg_force_iff stays 0 in real mode — the mask ROM's first
        // command handler runs and (per MAME exec) eventually EIs
        // before INTF1 actually needs to dispatch.  If it ever hangs
        // in sim, that's a bug in the handler-EI path or in our IFF
        // handling, not a missing force.
        always @(posedge clk) begin
            if (!rstn) begin
                ext_int1_req  <= 1'b0;
                dbg_force_iff <= 1'b0;
            end else begin
                ext_int1_req  <= ext_tick;
                dbg_force_iff <= 1'b0;
            end
        end
    end endgenerate

endmodule
