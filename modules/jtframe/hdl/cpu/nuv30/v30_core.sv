`ifdef SYNTHESIS
`define JTV30_SYNTHESIS
`elsif ALTERA_RESERVED_QIS
`define JTV30_SYNTHESIS
`endif

// SPDX-FileCopyrightText: 2026 Andrea Bogazzi
// Date: 18-10-2026
//============================================================================
//
//  v30_core (ucore) - the ROM-driven NEC V30 (uPD70116) core, max mode.
//
//  This is the ucore TOP.  It is a DROP-IN alternative to hdl/rtl/core/
//  v30_core.sv: same module name, same port list, same package name
//  (`v30_ss_pkg`, supplied here by hdl/rtl/ucore/v30u_ss_pkg.sv), so the two
//  cores are selected by the RTL FILE LIST alone -- `sw/check_core.py
//  --core {fsm,ucore}` and, later, hdl/files_ucore.qip.  hdl/tb/tb_v30_core.sv
//  is not parameterised on the engine.
//
//  Governance: hdl/rtl/ucore/README.md.  The correctness target is "identical
//  to sim/ clock-for-clock"; the BIU below is a transliteration of
//  sim/biu_timed.{h,cpp}, mechanism by mechanism.
//
//  STAGE U1: BIU only.  `v30u_eu` is a tied-off placeholder and the EU side is
//  held inert exactly as the FSM core's scripted-consumer mode holds it.
//
//  --- THE BUS SHAPE: `V30_MUXED_AD` (2026-08-14) ---------------------------
//
//  The V30 multiplexes one twenty-pin bus three ways because a 40-pin DIP has
//  no room for sixty pins.  Inside an FPGA that constraint does not exist, so
//  the three quantities the pins share are published as ports of their own --
//  and every one of them was already a register in `v30u_biu`, so this adds NO
//  FLOP and NO LOGIC.  The de-mux is a re-slicing of a mux.
//
//    ADDR_O[19:0]  the LINEAR ADDRESS of the cycle that owns the bus.  VALID
//                  FROM the announcement clock (carrying the ANNOUNCED cycle's
//                  address) THROUGH the whole of that cycle's T1/T2/Tw/T3/T4
//                  (carrying the RUNNING cycle's).  Never meaningless: with
//                  nothing running it holds the last running cycle's address,
//                  which is what the real part's pads show by retention.  An
//                  INTA announces no address and this reads ZERO there.
//    DATA_O[15:0]  the WRITE WORD of the cycle that owns the bus, in bus byte
//                  order (swapped on an odd address).  MEANINGFUL from the
//                  owning WRITE cycle's T1 through its T4.  On a READ cycle it
//                  holds the previous write's word and is DECLARED MEANINGLESS
//                  -- the multiplexed view never publishes it there either.
//    STATUS_O[3:0] {md8080, psw_ie, seg[1:0]} -- the nibble A19-16 carries
//                  whenever it is not carrying an address.  MEANINGFUL for the
//                  whole of the owning cycle, and it follows the SAME owner
//                  the address does.
//
//  There is deliberately NO "address valid" strobe.  The real part in max mode
//  announces with BS (S0-S2) and the bus controller derives the rest; this
//  interface does the same, with BS / RD_N / UBE_N unchanged.  A strobe would
//  be a pin the die does not have.
//
//  `V30_MUXED_AD` decides whether the MULTIPLEXED VIEW exists at all.  It is
//  orthogonal to `SYNTHESIS` (which selects fabric-vs-sim); this one is the
//  bus shape, and the rig defines BOTH.
//    defined   -- AD / AD_OE are ports, `v30u_biu` carries `t1_half2` and the
//                 `ad_oe_*` enables, `ad_o` is COMPOSED from
//                 ADDR_O/DATA_O/STATUS_O, and behaviour is byte-identical to
//                 the pre-2026-08-14 core.
//    undefined -- those two ports DO NOT EXIST on this module, `t1_half2` and
//                 the `ad_oe_*` PORTS go with them, and read data arrives on
//                 DATA_I instead of on AD.  A de-muxed build is a DIFFERENT
//                 SAVE-STATE STREAM (`SSA_B_T1_HALF2` has no flop behind it).
//  ⚠ 2026-09-08: `CE_HALF` USED TO BE THE THIRD PORT ON THAT LIST AND IS NOT
//  ANY MORE.  The ce/ce_half PHASE SPLIT gives the EU's next-state cone a
//  STAGE 1 captured on `ce_half`, so `ce_half` is a CORE CLOCKING input in
//  every configuration, not bus-shape machinery.  A de-muxed integrator that
//  did not connect it will now fail to elaborate, and that refusal is the
//  intended, surfaced consequence -- the same shape as the
//  `SYNTHESIS`-without-`V30_MUXED_AD` refusal E-6 records.
//  ⚠ The define removes the PINS, not the drive: `v30u_biu` still computes
//  what the core would put on shared pads, because F58 makes a HALT
//  pseudo-cycle PUBLISH the AD output latch and that makes the drive machine
//  state.  See THE AD OUTPUT LATCH in `v30u_biu.sv`.
//  `docs/notes/demux_bus_prereg_2026-08-14.md`.
//
//  SCRIPTED-CONSUMER MODE (V30_BACKDOOR, verification only).  `scr_en` hands
//  the queue port to `scr_qop`, using the QS encoding as the command:
//      2'b00  idle
//      2'b01  pop, and this pop is an F (instruction first byte)
//      2'b11  pop, and this pop is an S (subsequent byte)
//      2'b10  FLUSH + redirect to bkd_cs : bkd_fetch_ip
//  A pop is a DEMAND: it is served on the first clock the front byte is ripe,
//  which is M8's `pop = max(demand, ready)`.  The FSM core's scripted mode has
//  no flush command (its `q_flush` is tied low under `scr_en`); ucore spends
//  the otherwise-unused E encoding on it so the F1/F3/M12/M19 flush family is
//  reachable without an EU.  Recorded in docs/notes/ucore_provenance.md.
//
//============================================================================

module v30_core #(
`ifdef JTV30_SYNTHESIS
    parameter string HEXDIR = "rtl/ucore/"
`else
    parameter string HEXDIR = "hdl/rtl/ucore/"
`endif
) (
    input             CLK,
    input             CE,        // clock-enable: advance core state this clk
    // CE_HALF -- THE CORE'S SECOND CLOCKING PHASE, AND IT IS UNCONDITIONAL.
    // It was a `V30_MUXED_AD` port until the ce/ce_half PHASE SPLIT (WAVE 2,
    // 2026-09-08), on the reading that its only consumer was `v30u_biu`'s
    // `t1_half2`, the T1 AD address->data turnaround -- multiplexed-bus
    // machinery.  THAT READING IS NOW FALSE: the EU's next-state cone is split
    // across the two phases, so `ce_half` captures STAGE 1 in EVERY
    // configuration.  `V30_MUXED_AD` governs the BUS SHAPE (see THE BUS SHAPE
    // above, which already says the define is not about clocking); a core
    // clocking input is orthogonal to it and does not belong under it.
    // `docs/notes/phase_split_landing_prereg_2026-09-08.md` §4.
    input             CE_HALF,   // clock-enable marking the CPU clock's HALF
                                 // cycle: STAGE 1's capture edge, and (muxed
                                 // bus only) the T1 AD address->data turnaround
    input             RESET,
    input             READY,
    input             INT,
    input             NMI,
    input             POLL_N,
`ifdef V30_MUXED_AD
    // --- THE MULTIPLEXED VIEW (see THE BUS SHAPE in the header) ---
    inout      [19:0] AD,
    output     [19:0] AD_OE,     // the pads' own output enable (task #37)
`else
    // --- ...and its read-data half, when there is no AD to carry it ---
    input      [15:0] DATA_I,    // read data (AD[15:0] carries it when muxed)
`endif
    // --- THE DE-MUXED BUS (always present) ---
    output     [19:0] ADDR_O,    // the owning cycle's linear address
    output     [15:0] DATA_O,    // the owning cycle's write word
    output      [3:0] STATUS_O,  // {md8080, psw_ie, seg} -- the PS nibble
    output      [1:0] QS,
    output      [2:0] BS,
    output            RD_N,
    output            UBE_N,
    output            BUSLOCK_N,
    input [v30_ss_pkg::SS_ADDR_W-1:0] SS_ADDR,
    input      [15:0] SS_WDATA,
    input             SS_WE,
    output     [15:0] SS_RDATA,
    output reg        SS_ERR,
    output            SS_BUS_QUIET
`ifdef V30_BACKDOOR
    ,
    input             bkd_load,     // pulse while RESET=1: inject state
    input     [223:0] bkd_regs,     // {psw,ip,ds,ss,cs,es,di,si,bp,sp,bx,dx,cx,ax}
    input      [47:0] bkd_queue,    // queue bytes, entry 0 first
    input       [2:0] bkd_qlen,
    input      [15:0] bkd_fetch_ip, // BIU fetch offset (= ip + qlen)
    input             scr_en,       // scripted-consumer mode (BIU-only test)
    input       [1:0] scr_qop,      // per-cycle queue op, QS encoding
    output    [223:0] dbg_regs,     // ip slot holds the retired-instruction IP
    output            dbg_first_pop,
    output            dbg_pend
`endif
);

import v30_ss_pkg::*;

`ifndef V30_BACKDOOR
logic         bkd_load = 1'b0;
logic [223:0] bkd_regs = '0;
logic  [47:0] bkd_queue = '0;
logic   [2:0] bkd_qlen = '0;
logic  [15:0] bkd_fetch_ip = '0;
logic         scr_en = 1'b0;
logic   [1:0] scr_qop = '0;
`endif

//----------------------------------------------------------------------------
// BIU <-> EU
//----------------------------------------------------------------------------
wire  [7:0] q_byte;
wire        q_ripe, q_ripe_lead_n0, q_ripe_lead_n1;   // WAVE 15 C1
wire  [3:0] q_cnt;
wire        eu_ghost_full, eu_ghost_idle, eu_ghost_stack_first;
// the launch-law's publications (the 8F ghost read's two drivers)
wire        eu_ghost_row, eu_ghost_acc;
wire [19:0] eu_ghost_sp, eu_ghost_bare;
wire        eu_pop, eu_first, eu_flush;
wire        eu_flush_pre, eu_flush_rep, eu_flush_stage, eu_flush_pend;
wire        eu_flush_nmi, eu_flush_int_live;
wire [15:0] eu_flush_cs, eu_flush_cs_old, eu_flush_ip;
wire        eu_flush_cs_we;
wire        eu_post, eu_post_hold, eu_halt_irq, eu_vector_post;
wire        eu_word, eu_pair, eu_pair2, eu_split;
wire        eu_slot_busy, eu_slot_busy_n, eu_access_active;
wire        eu_direct_fetch, eu_fetch_tail;
wire  [2:0] eu_bs;
wire [19:0] eu_addr, eu_addr2;
wire  [1:0] eu_seg, eu_seg2;
wire [15:0] eu_wdata, eu_rdata_n;
wire        eu_rd_done_n, eu_wr_done_n, eu_wr_eval;
wire        eu_rd_edge;
wire [15:0] eu_rd_edge_d;
wire        eu_opr_free;
wire        eu_susp, eu_resume, eu_halt, eu_unhalt, biu_halted;
wire        eu_unhalt_disp;                       // F43 (SM3 sitting 6)
wire        eu_bnd_take, eu_bnd_post;   // SM3 sitting 11 (H1's remains)
wire        psw_ie, md8080;
wire [15:0] ss_eu_rdata, ss_biu_rdata;
wire        ss_biu_bus_quiet;
reg   [8:0] ss_addr_q;
reg  [15:0] ss_wdata_q;
reg         ss_we_q;
reg         ss_sel_eu_q, ss_sel_tag_q;

always_ff @(posedge CLK) begin
    ss_addr_q    <= SS_ADDR;
    ss_wdata_q   <= SS_WDATA;
    ss_we_q      <= SS_WE;
    ss_sel_eu_q  <= ss_addr_q[8];
    ss_sel_tag_q <= (ss_addr_q == SSA_TAG);
end

assign SS_RDATA = ss_sel_tag_q ? SS_TAG
                : ss_sel_eu_q  ? ss_eu_rdata : ss_biu_rdata;

always_ff @(posedge CLK) begin
    if (RESET) SS_ERR <= 1'b0;
    else if (ss_we_q && ss_addr_q == SSA_TAG)
        SS_ERR <= (ss_wdata_q != SS_TAG);
end

assign SS_BUS_QUIET = ss_biu_bus_quiet;

//----------------------------------------------------------------------------
// THE ce/ce_half CONTRACT, ENFORCED IN THE MODULE  (USER RULING 2026-08-13)
//----------------------------------------------------------------------------
// "Correct the guidance on ce and ce_half. They do not need to be separated by
//  a clock, they just cannot be enabled at the same time, we should have an
//  assert in the module that prevents that."
//
// THE CONTRACT IS ONE PREMISE:
//
//   C-a  `CE` and `CE_HALF` are never asserted on the same fabric clock.
//
// ADJACENT ASSERTIONS ARE LEGAL.  That is not a hypothetical -- M72 drives the
// ucore from a catch-up train whose phases strictly alternate one per fabric
// clock during a burst (`docs/notes/m72_downstream_timing_2026-08-12.md` §1).
// The 2026-08-12 "one cycle gap" clause (C-b) and the `ce -> ce >= 4`
// arithmetic derived from it (C-c) are DELETED.
//
// AND ONE STRUCTURAL FACT ABOUT THIS CORE, WHICH IS NOT A CONTRACT CLAUSE:
//
//   S-1  at least one `CE_HALF` falls between consecutive `CE`s.
//
// This is the core's own functional requirement, not an assumption about a
// train's shape: `ce_half` is the only enable on `v30u_biu|t1_half2`, and
// `t1_half2` is the T1 address->data turnaround that gates `ad_oe_data`
// (`v30u_biu.sv:1056/1062/1080`).  A `CE -> CE` with no `CE_HALF` between them
// leaves the ADDRESS on AD for a whole write cycle.  A platform that does this
// has already broken the core, so asserting it is no stronger than "the core
// works" -- and S-1 is what makes `CE -> CE >= 2` true CONTRACT-FREE, which is
// the whole of `nec_test.sdc`'s remaining CE exception.  Extra `CE_HALF`s in a
// gap are harmless: `t1_half2`'s update is idempotent.
//
// WHY IT IS HERE AND NOT IN A TESTBENCH.  `hdl/tb/ce_contract_check.sv` was
// instantiated in three testbenches and saw only those three.  This block is
// in the core module, so EVERY instantiation inherits it -- including any
// downstream integrator's simulation, which is where the trains this contract
// exists for actually come from.  That checker is retired.
//
// `$fatal`, not `$error`: a train outside the envelope has invalidated every
// row downstream of it, so continuing produces a SCORED NUMBER taken outside
// the contract -- which is exactly what happened when the golden scorer ran at
// `--ce-div 1` (`docs/notes/t1_half2_posedge_results_2026-08-13.md` §5.1).
//
// NON-VACUITY is a registered deliverable, not a hope:
// `docs/notes/ce_contract_correction_prereg_2026-08-13.md` §3, P-1.
//
// ⚠ 2026-08-14 SUPERSEDED, 2026-09-08.  This paragraph used to read *"BOTH
// CLAUSES NAME `CE_HALF`, SO BOTH LIVE UNDER `V30_MUXED_AD` WITH THE PIN ...
// what S-1 protects is `t1_half2`, the T1 address->data turnaround, which a
// de-muxed bus does not have.  A de-muxed integrator's only enable contract is
// `CE`."*  **EVERY SENTENCE OF THAT IS NOW FALSE.**  The ce/ce_half PHASE
// SPLIT (WAVE 2) gives `v30u_eu` a STAGE 1 captured on `ce_half`, so `CE_HALF`
// is an unconditional port and BOTH clauses are asserted in EVERY
// configuration.  S-1 in particular is no longer about the BIU's turnaround
// alone: without a `CE_HALF` between two `CE`s the EU consumes a STALE STAGE 1
// and the core computes the wrong next state.  It was "no stronger than the
// core works"; it still is, and it now says so about the EU as well.
`ifndef JTV30_SYNTHESIS
// has a CE_HALF been seen since the last CE?  Starts asserted so a run's FIRST
// CE is never reported -- there is no preceding CE for it to be too close to.
// ⚠ AND THAT IS EXACTLY WHY THE PHASE-SPLIT SHADOW MAY NOT DEPEND ON HAVING
// BEEN CAPTURED BEFORE THE FIRST CE.  It does not: the shadow's commit
// condition is `(ss_we || srst || ce_half)` and RESET is asserted at the head
// of every run, so the shadow tracks stage 1 on every reset clock and is
// current at the first CE whether or not a CE_HALF preceded it.  See THE
// PHASE SPLIT in v30u_eu.sv.
logic ce_half_since_ce = 1'b1;

always @(posedge CLK) begin
    if (CE && CE_HALF)
        $fatal(1, "v30_core: ce/ce_half CONTRACT VIOLATED (C-a) at %0t -- CE and CE_HALF asserted on the SAME fabric clock.  They may be adjacent; they may not coincide.  USER RULING 2026-08-13; see hdl/nec_test.sdc and docs/notes/ce_contract_correction_prereg_2026-08-13.md.",
               $time);

    if (CE && !ce_half_since_ce)
        $fatal(1, "v30_core: ce/ce_half REQUIREMENT VIOLATED (S-1) at %0t -- two CEs with NO CE_HALF between them.  CE_HALF is v30u_eu's STAGE-1 capture edge (THE PHASE SPLIT, v30u_eu.sv): with no CE_HALF between two CEs the EU consumes a STALE stage 1 and computes the wrong next state.  It is ALSO the only enable on t1_half2, the T1 address->data turnaround gating ad_oe_data, so on a muxed bus the BIU additionally leaves the ADDRESS on AD for a whole write cycle.",
               $time);

    if (CE_HALF)  ce_half_since_ce <= 1'b1;
    else if (CE)  ce_half_since_ce <= 1'b0;
end

// The SAVE-STATE contract is bus-shape independent and is asserted in every
// configuration.  (It was in the block above until 2026-08-14, when the two
// ce/ce_half clauses moved under `V30_MUXED_AD` and it could not follow them.
// ⚠ 2026-09-08: THAT SPLIT IS UNDONE.  `CE_HALF` is an unconditional port
// now, so the two blocks are one `ifndef SYNTHESIS` again and the SS clauses
// can finally name it -- which is what USER RULING 1 of 2026-09-08 asks for.)
//
// USER RULING 1 (2026-09-08): THE FREEZE CLAUSE IS EXTENDED TO `CE_HALF`.
// The freeze that a save-state write assumes is a freeze of the WHOLE core,
// and since the phase split the core advances on TWO enables, not one.  A
// `CE_HALF` during an SS write would re-capture the phase-split shadow from a
// half-restored register file; a `CE_HALF` with the command staging still
// undrained would capture stage 1 evaluated in the `ss_we` arm.  Both are the
// same defect the two `CE` clauses already name, one phase over.
always @(posedge CLK) begin
    if (SS_WE && CE)      $error("SS_WE asserted while CE high (core not frozen)");
    if (SS_WE && CE_HALF) $error("SS_WE asserted while CE_HALF high (core not frozen -- the phase-split shadow would re-capture from a half-restored register file).  USER RULING 2026-09-08.");
    if (SS_WE && RESET)   $error("SS_WE asserted during RESET");
    // Resume-drain contract (A2): the platform must NOT re-enable CE until the
    // SS command staging has drained.  ss_we_q still high at a CE cycle means
    // the core takes its `if (ss_we)` branch and SKIPS its state advance -> a
    // phantom wait on resume.
    if (CE && ss_we_q)      $error("CE resumed with SS command staging undrained (ss_we_q high)");
    if (CE_HALF && ss_we_q) $error("CE_HALF resumed with SS command staging undrained (ss_we_q high) -- the shadow would capture stage 1 as evaluated in the ss_we arm.  USER RULING 2026-09-08.");
end
`endif

//----------------------------------------------------------------------------
// scripted-consumer override (BIU-only verification) -- see the header
//----------------------------------------------------------------------------
wire q_pop   = scr_en ? (scr_qop == 2'b01 || scr_qop == 2'b11) : eu_pop;
wire q_first = scr_en ? (scr_qop == 2'b01)                     : eu_first;
wire q_flush = scr_en ? (scr_qop == 2'b10)                     : eu_flush;
wire [15:0] flush_cs = scr_en ? bkd_regs[144 +: 16] : eu_flush_cs;
wire [15:0] flush_ip = scr_en ? bkd_fetch_ip        : eu_flush_ip;

`ifdef V30_MUXED_AD
wire [19:0] ad_o;
wire        ad_oe_addr, ad_oe_ps, ad_oe_data;
`endif

v30u_biu u_biu (
    .clk        (CLK),
    .ce         (CE),
`ifdef V30_MUXED_AD
    .ce_half    (CE_HALF),
`endif
    .srst       (RESET),
    .bs         (BS),
`ifdef V30_MUXED_AD
    .ad_o       (ad_o),
    .ad_oe_addr (ad_oe_addr),
    .ad_oe_ps   (ad_oe_ps),
    .ad_oe_data (ad_oe_data),
    .ad_i       (AD[15:0]),
`else
    .ad_i       (DATA_I),
`endif
    .addr_o     (ADDR_O),
    .data_o     (DATA_O),
    .status_o   (STATUS_O),
    .ube_n      (UBE_N),
    .rd_n       (RD_N),
    .qs         (QS),
    .ready      (READY),
    .psw_ie     (psw_ie),
    .md8080     (md8080),
    .q_byte     (q_byte),
    .q_ripe     (q_ripe),
    .q_ripe_lead_n0(q_ripe_lead_n0),
    .q_ripe_lead_n1(q_ripe_lead_n1),
    .q_cnt_o    (q_cnt),
    .q_pop      (q_pop),
    .q_first    (q_first),
    .q_flush    (q_flush),
    .flush_pre  (scr_en ? 1'b0 : eu_flush_pre),
    .flush_rep  (scr_en ? 1'b0 : eu_flush_rep),
    .flush_stage(scr_en ? 1'b0 : eu_flush_stage),
    .flush_pend (scr_en ? 1'b0 : eu_flush_pend),
    .flush_nmi  (scr_en ? 1'b0 : eu_flush_nmi),
    .flush_int_live(scr_en ? 1'b0 : eu_flush_int_live),
    .flush_cs   (flush_cs),
    .flush_cs_old(eu_flush_cs_old),
    .flush_cs_we(scr_en ? 1'b0 : eu_flush_cs_we),
    .flush_ip   (flush_ip),
    .eu_post    (scr_en ? 1'b0 : eu_post),
    .eu_post_hold(scr_en ? 1'b0 : eu_post_hold),
    .eu_halt_irq(scr_en ? 1'b0 : eu_halt_irq),
    .eu_vector_post(scr_en ? 1'b0 : eu_vector_post),
    .eu_bs      (eu_bs),
    .eu_addr    (eu_addr),
    .eu_addr2   (eu_addr2),
    .eu_split   (eu_split),
    .eu_seg     (eu_seg),
    .eu_seg2    (eu_seg2),
    .eu_word    (eu_word),
    .eu_slot_busy (eu_slot_busy),
    .eu_slot_busy_n (eu_slot_busy_n),
    .eu_access_active(eu_access_active),
    .eu_direct_fetch(eu_direct_fetch),
    .eu_fetch_tail(eu_fetch_tail),
    .eu_ghost_full(eu_ghost_full),
    .eu_ghost_idle(eu_ghost_idle),
    .eu_ghost_stack_first(eu_ghost_stack_first),
    .eu_ghost_row(eu_ghost_row),
    .eu_ghost_acc(eu_ghost_acc),
    .eu_ghost_sp(eu_ghost_sp),
    .eu_ghost_bare(eu_ghost_bare),
    .eu_pair    (scr_en ? 1'b0 : eu_pair),
    .eu_pair2   (eu_pair2),
    .eu_wdata   (eu_wdata),
    .eu_rdata_n (eu_rdata_n),
    .eu_rd_done_n (eu_rd_done_n),
    .eu_rd_edge (eu_rd_edge),
    .eu_rd_edge_d (eu_rd_edge_d),
    .eu_wr_done_n (eu_wr_done_n),
    .eu_wr_eval   (eu_wr_eval),
    .eu_opr_free(eu_opr_free),
    .eu_susp    (scr_en ? 1'b0 : eu_susp),
    .eu_resume  (scr_en ? 1'b0 : eu_resume),
    .eu_halt    (scr_en ? 1'b0 : eu_halt),
    .eu_unhalt  (scr_en ? 1'b0 : eu_unhalt),
    .eu_unhalt_disp(scr_en ? 1'b0 : eu_unhalt_disp),
    .halted_o   (biu_halted),
    .eu_bnd_take(scr_en ? 1'b0 : eu_bnd_take),
    .eu_bnd_post(eu_bnd_post),
    .bkd_load   (bkd_load),
    .bkd_cs     (bkd_regs[144 +: 16]),
    .bkd_ip     (bkd_fetch_ip),
    .bkd_queue  (bkd_queue),
    .bkd_qlen   (bkd_qlen),
    .ss_addr    (ss_addr_q),
    .ss_wdata   (ss_wdata_q),
    .ss_we      (ss_we_q),
    .ss_rdata   (ss_biu_rdata),
    .ss_bus_quiet(ss_biu_bus_quiet)
);

v30u_eu #(
    .HEXDIR ( HEXDIR )
) u_eu (
    .clk        (CLK),
    .ce         (CE),
    // THE PHASE SPLIT: stage 1's capture edge.  Unconditional, like the port.
    .ce_half    (CE_HALF),
    .srst       (RESET),
    .q_byte     (q_byte),
    .q_ripe     (q_ripe),
    .q_ripe_lead_n0(q_ripe_lead_n0),
    .q_ripe_lead_n1(q_ripe_lead_n1),
    .q_cnt      (q_cnt),
    .q_pop      (eu_pop),
    .q_first    (eu_first),
    .q_flush    (eu_flush),
    .flush_pre  (eu_flush_pre),
    .flush_rep  (eu_flush_rep),
    .flush_stage(eu_flush_stage),
    .flush_pend (eu_flush_pend),
    .flush_nmi  (eu_flush_nmi),
    .flush_int_live(eu_flush_int_live),
    .flush_cs   (eu_flush_cs),
    .flush_cs_old(eu_flush_cs_old),
    .flush_cs_we(eu_flush_cs_we),
    .flush_ip   (eu_flush_ip),
    .eu_post    (eu_post),
    .eu_post_hold(eu_post_hold),
    .eu_halt_irq(eu_halt_irq),
    .eu_vector_post(eu_vector_post),
    .eu_bs      (eu_bs),
    .eu_addr    (eu_addr),
    .eu_addr2   (eu_addr2),
    .eu_split   (eu_split),
    .eu_seg     (eu_seg),
    .eu_seg2    (eu_seg2),
    .eu_word    (eu_word),
    .eu_slot_busy (eu_slot_busy),
    .eu_slot_busy_n (eu_slot_busy_n),
    .eu_access_active(eu_access_active),
    .eu_direct_fetch(eu_direct_fetch),
    .eu_fetch_tail(eu_fetch_tail),
    .eu_ghost_full(eu_ghost_full),
    .eu_ghost_idle(eu_ghost_idle),
    .eu_ghost_stack_first(eu_ghost_stack_first),
    .eu_ghost_row(eu_ghost_row),
    .eu_ghost_acc(eu_ghost_acc),
    .eu_ghost_sp(eu_ghost_sp),
    .eu_ghost_bare(eu_ghost_bare),
    .eu_pair    (eu_pair),
    .eu_pair2   (eu_pair2),
    .eu_wdata   (eu_wdata),
    .eu_rdata_n (eu_rdata_n),
    .eu_rd_done_n (eu_rd_done_n),
    .eu_rd_edge (eu_rd_edge),
    .eu_rd_edge_d (eu_rd_edge_d),
    .eu_wr_done_n (eu_wr_done_n),
    .eu_wr_eval   (eu_wr_eval),
    .eu_opr_free(eu_opr_free),
    .eu_susp    (eu_susp),
    .eu_resume  (eu_resume),
    .eu_halt    (eu_halt),
    .eu_unhalt  (eu_unhalt),
    .eu_unhalt_disp(eu_unhalt_disp),
    .halted     (biu_halted),
    .eu_bnd_take(eu_bnd_take),
    .eu_bnd_post(eu_bnd_post),
    .psw_ie     (psw_ie),
    .md8080     (md8080),
    .pin_int    (INT),
    .pin_nmi    (NMI),
    .pin_poll_n (POLL_N),
    .bkd_load   (bkd_load),
    .bkd_regs   (bkd_regs),
`ifdef V30_BACKDOOR
    .dbg_regs      (dbg_regs),
    .dbg_first_pop (dbg_first_pop),
    .dbg_pend      (dbg_pend),
`else
    /* verilator lint_off PINCONNECTEMPTY */
    .dbg_regs      (),
    .dbg_first_pop (),
    .dbg_pend      (),
    /* verilator lint_on PINCONNECTEMPTY */
`endif
    .ss_addr    (ss_addr_q),
    .ss_wdata   (ss_wdata_q),
    .ss_we      (ss_we_q),
    .ss_rdata   (ss_eu_rdata)
);

`ifdef V30_MUXED_AD
// AD drive (simple en?val:'z forms only - Verilator requirement).
// AD[19:16] carry the address during address phases and PS3-0 during the
// data phase; AD[15:0] additionally carry write data.
assign AD[15:0]  = (ad_oe_addr | ad_oe_data) ? ad_o[15:0]  : 16'hzzzz;
assign AD[19:16] = (ad_oe_addr | ad_oe_ps)   ? ad_o[19:16] : 4'hz;

// AD_OE -- THE PADS' OWN OUTPUT ENABLE, PUBLISHED (task #37, user-approved
// 2026-08-04).  This is a WIRE, not a rule: it is bit-for-bit the SAME
// expression the two `assign AD[...]` statements above already use to decide
// whether to drive, so it adds no logic and cannot disagree with the drive.
// The real part has two pad-enable groups (AD0-15, A16-19/PS0-3) and so does
// this; the 20-bit form just replicates them so a consumer needs no knowledge
// of where the groups split.
//
// WHY IT EXISTS.  ucore_provenance.md §56.3a's retention intervention needs an
// "is anyone driving" term, and §56.3a forbids MANUFACTURING one in the
// harness (that would be a fitted rule in the exact place the intervention
// must not have one).  It does not forbid the core TELLING the truth: the
// V30's pads have an output enable, so publishing it is the part's own
// structure, not the instrument's.  §59.7.1's blocker -- Quartus 17.1 folds
// `net === 1'bz` on an internal tri-state and deletes the retention register
// -- is removed by construction, because the model no longer asks the net.
assign AD_OE = {{4{ad_oe_addr | ad_oe_ps}}, {16{ad_oe_addr | ad_oe_data}}};
`endif  // V30_MUXED_AD

// BUSLOCK is not implemented (inherited scope note; the FSM core drives it
// from the EU's LOCK prefix, which U2 restores).
assign BUSLOCK_N = 1'b1;

endmodule
