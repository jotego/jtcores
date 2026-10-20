`ifdef SYNTHESIS
`define JTV30_SYNTHESIS
`elsif ALTERA_RESERVED_QIS
`define JTV30_SYNTHESIS
`endif

// SPDX-FileCopyrightText: 2026 Andrea Bogazzi
// Date: 19-10-2026
//============================================================================
//
//  v30u_biu - the ucore bus-interface unit.
//
//  THIS MODULE IS A TRANSLITERATION OF sim/biu_timed.{h,cpp}.  Every mechanism
//  carries its ledger tag (M1..M23, M2r, M5b, F1..F3) and the reference
//  model's own words, condensed.  The governance rule (hdl/rtl/ucore/README.md)
//  is that the model is the SPEC: an RTL-vs-sim divergence is a bug HERE.
//
//  --- THE SPINE: ONE EVAL INSTANT, DERIVED FROM ONE FLOP -------------------
//
//  M2r says the READY sample is the only wait-state mechanism and that it is
//  ONE INSTANT: the CPU registers READY at the end of every clock and one
//  clock later it (a) releases the status register and (b) runs the completion
//  eval at that clock's end.  The reference model computes the instant from
//  the wait count it knows (`e = w==0 ? 2 : 3+w`); the RTL does not know the
//  wait count and does not need to -- the instant falls out of two local
//  quantities:
//
//      eval instant  ==  the first clock with  dage >= 3  and  ready_prev
//
//  where `dage` is this cycle's age counted from its DISPLAY clock (0 on the
//  display) and `ready_prev` is the registered READY pin.  That this IS the
//  model's instant at every wait level, for the rig of hdl/rtl/nec_bus.sv:
//
//    w0   READY is high from T1 entry.  T1 = disp+1, so dage>=3 first happens
//         at T3 = index 2 == the model's `eval_i` at zero waits.
//    wN   READY is low from T1 entry and high from the LAST Tw, so ready_prev
//         is first high at T4 == index 3+N == the model's `eval_i`.
//    M22  a cycle whose T1 the bus made WAIT: the model counts the zero-wait
//         instant from the DISPLAY (`disp+3`), not from the T1.  That is
//         literally `dage >= 3`.  No second rule, no wait counter.
//
//  The HALT pseudo-cycle is the one access that does not go through the
//  arbiter (the HLT micro-row writes the status register directly) and its
//  MEASURED status release is at index 1 -- `dage >= 2`, wait-independent.
//  That is M21, and it is the only exception in the module.
//
//  Everything else is a FIXED OFFSET from the eval instant `e`:
//      e     status goes passive; OPR is released to a `-> OPR` row
//      e+1   the DISPLAY clock
//      e+2   the winner's T1; eu_done (read handover, store retire)
//      e+3   a fetched byte becomes POPPABLE
//  ...so the module carries `sev` (clocks since this cycle's own eval) and
//  initialises all three landing windows from it.  See the T4 block.
//
//  --- ABSOLUTE CLOCKS -> BOUNDED RELATIVE COUNTERS -------------------------
//
//  Every absolute `long` clock in the model (cmt_t1_, cmt_expire_,
//  pf_infl_to_, push_absorb_*, the QByte ready stamps -- and, until F56
//  deleted M6 in both engines, pf_land_*) is re-expressed as a
//  small counter, with a SYNTHESIS bound assertion (campaign risk #2).
//
//  --- THE EDGE -------------------------------------------------------------
//
//  The module is ONE next-state function (`always_comb`) and ONE register bank
//  (`always_ff`).  `r_<x>` IS the register -- the state the model has at the
//  START of `tick(c)`; the unprefixed `<x>` is the value that same register
//  takes at this edge, i.e. the state at the start of `tick(c+1)`.  The
//  next-state body is written with blocking assignments because they ARE the
//  model's sequential semantics, but they are now confined to one combinational
//  process, so NO consumer -- inside the module or outside it -- can observe an
//  intermediate.  See THE EU CONTRACT below for what the EU is allowed to read.
//
//  U4 pass 3 -- WHERE `ce` IS.  It is on the REGISTER BANK's enable
//  (`always_ff @(posedge clk) if (ss_we || srst || ce)`), not in the
//  next-state function, whose third arm is now the unconditional `else`.  The
//  two forms are identical in behaviour -- the next-state body preloads every
//  value from its own register, so a CE-low evaluation reproduces the register
//  and the commit is a no-op either way -- but only this one lets Quartus
//  extract a clock enable.  With `ce` inside the function it went into the
//  DATA cone instead: the BIU's registers clocked every SYS clock, and a
//  `v30u_biu` -> `v30u_eu` path was the worst violation left after the EU's
//  own exception (ledger sec.51.7, `r_q_cnt[3]` -> `m_kind[0]`).
//
//  One evaluation of the next-state function performs, in the model's order:
//
//     (a) capture the clock-c predicates that later steps must not re-read
//     (b) the EU's own acts, which the model makes at `clk_ == c` BEFORE
//         tick(c) runs: pop, post, pair, susp, flush
//     (c) tick(c)'s end-of-clock block: advance the cycle, land the bytes
//     (d) tick(c)'s completion / idle / flush eval
//     (e) tick(c+1)'s PRE-ROW block: expire the announcement, open the T1,
//         let a pending HALT take the register
//     (f) age the relative counters into their clock-c+1 values
//
//  ONE interface consequence, booked as a mapping note (U1 -> U2): the model's
//  `note_halt` / `unhalt` land in tick(c)'s PRE-ROW block, which in RTL is the
//  edge ending c-1.  `eu_halt` / `eu_unhalt` are therefore specified to LEAD
//  by one clock -- the same one-row-early control decode F2 already measures
//  for SUSP.  Nothing else in the interface leads.
//
//  --- CE DISCIPLINE (docs/notes/ce_plan.md) --------------------------------
//
//  Nothing clocked runs unless `srst` or `ce`; reset is ungated so `bkd_load`
//  fires regardless of CE.  There is NO negedge process in the BIU -- and,
//  with `v30u_eu.sv:48`, none anywhere in the synthesised core, since
//  2026-08-13.  `t1_half2` (the T1 AD half) is a POSEDGE flop enabled by
//  `ce_half`; it was the last negedge flop in the design.
//  ⚠ THE ARCHIVED FSM CORE (`hdl/rtl/core/v30_biu.sv`) KEEPS ITS NEGEDGE
//  `t1_half2` and is deliberately NOT touched -- `fsm_core_archive_2026-08-04.md`.
//
//  --- THE DE-MUXED BUS, AND `V30_MUXED_AD` (2026-08-14) -------------------
//
//  The V30 multiplexes one twenty-pin bus three ways because a 40-pin DIP has
//  no room for sixty pins.  Inside an FPGA that constraint does not exist.
//  THE WHOLE OF THE MULTIPLEXING LAW IS ONE SENTENCE:
//
//      A19-16 carries the ADDRESS's top nibble during the address ONE-SHOT
//      and the STATUS nibble otherwise; A15-0 carries the address low during
//      an address phase and the WRITE DATA otherwise.
//
//  It has exactly three operands -- an address, a write word, a status nibble
//  -- and every one of them was already a register in this module.  So the
//  de-mux is a RE-SLICING OF A MUX, not a new mechanism, and it adds NO FLOP.
//  The three are published as `addr_o` / `data_o` / `status_o`, which exist in
//  every configuration; their contracts are written at THE DE-MUXED BUS below.
//
//  `V30_MUXED_AD` selects whether the multiplexed VIEW exists at all.  It is
//  orthogonal to `SYNTHESIS` (fabric-vs-sim): this one is the BUS SHAPE.
//    defined   -- `ad_o` / `ad_oe_*` / `ce_half` / `t1_half2` are present, and
//                 `ad_o` is COMPOSED from the three ports above, so there is
//                 no second derivation to drift.  The rig builds this way and
//                 it is byte-identical to the pre-2026-08-14 behaviour.
//    undefined -- those PORTS are gone, `ce_half` and `t1_half2` with them
//                 (`t1_half2` has ZERO consumers in the next-state logic --
//                 `t1_half2_anatomy_2026-08-13.md` §1.3), and the read data
//                 arrives on the core's `DATA_I` instead of on `AD`.
//                 A define-OFF build is a DIFFERENT SAVE-STATE STREAM: the
//                 flop's address has no flop behind it and reads 0.  (Naming
//                 that address here would be a THIRD textual reference and
//                 `ss_lint` counts them -- it caught exactly that on this
//                 comment's first draft, as it did on the 08-13 one below.)
//
//  ⚠ WHAT THE DEFINE DOES NOT REMOVE, and this is a FINDING of the wave: the
//  multiplexed view's VALUE (`ad_o` / `ad_oe_*`) is still computed, because
//  THE AD OUTPUT LATCH HAS A FUNCTIONAL CONSUMER -- F58 makes a HALT
//  pseudo-cycle publish it (see THE AD OUTPUT LATCH below).  The shared-pad
//  drive is machine state, so a de-muxed core keeps it and drops only the
//  pins.  The phase it needs comes from `bus_half`, which is what `t1_half2`
//  equals at every `ce` -- derived from S-1 and ASSERTED, not assumed.
//  `docs/notes/demux_bus_prereg_2026-08-14.md`.
//
//============================================================================

module v30u_biu (
    input             clk,
    input             ce,
`ifdef V30_MUXED_AD
    input             ce_half,     // MUXED-BUS ONLY: `t1_half2`'s only enable
`endif
    input             srst,

    // --- chip pins (composed in the top) ---
    output      [2:0] bs,
`ifdef V30_MUXED_AD
    // THE MULTIPLEXED VIEW, as PORTS.  Present only when `V30_MUXED_AD` is
    // defined; it is COMPOSED from the de-muxed bus below and owns no operand
    // of its own.  ⚠ The view itself is computed in EVERY configuration -- see
    // THE AD OUTPUT LATCH below; only its exposure is conditional.
    output     [19:0] ad_o,
    output            ad_oe_addr,
    output            ad_oe_ps,
    output            ad_oe_data,
`endif
    // --- THE DE-MUXED BUS (always present) --- see THE DE-MUXED BUS below
    output     [19:0] addr_o,      // the owning cycle's linear address
    output     [15:0] data_o,      // the owning cycle's write word
    output      [3:0] status_o,    // {md8080, psw_ie, seg} -- the PS nibble
    output            ube_n,
    output            rd_n,
    output      [1:0] qs,          // F1: the BIU owns the QS port
    input      [15:0] ad_i,        // read data (from AD[15:0] or from DATA_I)
    input             ready,

    // --- machine state the pins carry (M9) ---
    input             psw_ie,
    input             md8080,

    // --- queue port (the consumer side) ---
    output      [7:0] q_byte,      // the front byte
    output            q_ripe,      // ...and it may be popped THIS clock (M3)
    // WAVE 15 C1 -- THE 1BL LEAD IS PUBLISHED AS TWO LEVELS, ONE FOR EACH
    // THING THE EU CAN DO TO THE QUEUE THIS CLOCK.  Neither depends on `q_pop`;
    // the EU selects with its own act.  See THE EU CONTRACT below.
    output            q_ripe_lead_n0, // ...will be ripe NEXT clock if NO pop
    output            q_ripe_lead_n1, // ...and if the EU DOES pop this clock
    output      [3:0] q_cnt_o,
    input             q_pop,       // consumer takes it (qualify with q_ripe)
    input             q_first,     // this pop is an F (instruction first byte)
    input             q_flush,     // flush + redirect, acts on THIS clock
    input             flush_pre,   // empty-tail REP withdrawal, one row before FLUSH
    input             flush_rep,   // ...from the REP-withdrawal control path
    input             flush_stage, // ...with a staged element tail of either kind
    input             flush_pend,  // ...with an accepted EU element still draining
    input             flush_nmi,   // ...recognized from the NMI latch
    input             flush_int_live, // ...with the maskable pin still asserted
    input      [15:0] flush_cs,
    input      [15:0] flush_cs_old,
    input             flush_cs_we,
    input      [15:0] flush_ip,

    // --- EU bus requests (M10: ONE request slot) ---
    input             eu_post,     // post an access this clock
    input             eu_post_hold,// reserve now, arbitrate on next idle clock
    input             eu_halt_irq, // first INTA belongs to a HALT wake
    input             eu_vector_post,
    input       [2:0] eu_bs,       // 0 INTA 1 IOR 2 IOW 5 MEMR 6 MEMW
    input      [19:0] eu_addr,
    input      [19:0] eu_addr2,    // the SECOND cycle of a split word access
    input             eu_split,    // ...which the BIU manufactures (M10)
    input       [1:0] eu_seg,      // S4:S3 -- 0 ES 1 SS 2 CS/none 3 DS
    input       [1:0] eu_seg2,     // second half may retain a different rail
    input             eu_word,
    output            eu_slot_busy,
    output            eu_slot_busy_n,
    output            eu_access_active,
    output            eu_direct_fetch,
    output            eu_fetch_tail,
    output            eu_ghost_full,
    output            eu_ghost_idle,
    output            eu_ghost_stack_first,
    // THE 8F GHOST READ IS DECORATED AT **LAUNCH**.  The EU hands over the two
    // drivers' composed addresses and the currency of its own micro-row; the
    // age and the pick are here, at `g_age` and the commit mux.
    input             eu_ghost_row,
    input             eu_ghost_acc,
    input      [19:0] eu_ghost_sp,
    input      [19:0] eu_ghost_bare,
    input             eu_pair,     // pair write data into the reserved cycle
    input             eu_pair2,    // ...and it fills TWO of them (a split)
    input      [15:0] eu_wdata,
    output     [15:0] eu_rdata_n,
    output            eu_rd_done_n,// pulse at a completed read's e+2
    output            eu_rd_edge,  // ...and the READ'S DATA EDGE itself (T3->T4)
    output     [15:0] eu_rd_edge_d,// the word the data latch closes on
    output            eu_wr_done_n,// pulse at a completed write's e+2
    output            eu_wr_eval,  // final write cycle's completion eval
    output            eu_opr_free, // 11.4 / M13: the store lets go of OPR
                                 // (a LEVEL off the register: `opr_held == 0`)

    // --- prefetch control ---
    input             eu_susp,     // F2: SUSP, one row early
    input             eu_resume,
    input             eu_halt,     // M20: the HLT row's status write (leads 1)
    input             eu_unhalt,   // M20: the wake (leads 1)
    input             eu_unhalt_disp, // F43: the same wake as the DISPLAY's
                                 // own decision edge sees it (int_p[1])
    output            halted_o,

    // --- H1: the RE-ENTRY acknowledge's recognition floor (SM3 sitting 3) ---
    input             eu_bnd_take,  // a recognition boundary IS taken this clock
    input             eu_bnd_post,  // ...it is a retire, and the IE gate HELD it

    // --- backdoor / reset injection ---
    input             bkd_load,
    input      [15:0] bkd_cs,
    input      [15:0] bkd_ip,
    input      [47:0] bkd_queue,
    input       [2:0] bkd_qlen,

    // --- save-state ---
    input       [8:0] ss_addr,
    input      [15:0] ss_wdata,
    input             ss_we,
    output reg [15:0] ss_rdata,
    output            ss_bus_quiet
);

import v30_ss_pkg::*;

// rows.h encodings -- the comparator stack's own
localparam bit [2:0] BS_INTA = 3'd0, BS_IOR = 3'd1, BS_IOW = 3'd2,
                     BS_HALT = 3'd3, BS_CODE = 3'd4, BS_MEMR = 3'd5,
                     BS_MEMW = 3'd6, BS_PASV = 3'd7;
localparam bit [2:0] TS_TI = 3'd0, TS_T1 = 3'd1, TS_T2 = 3'd2,
                     TS_T3 = 3'd3, TS_TW = 3'd4, TS_T4 = 3'd5;
localparam bit [1:0] QS_NONE = 2'd0, QS_FIRST = 2'd1,
                     QS_EMPTY = 2'd2, QS_SUBSEQ = 2'd3;

//============================================================================
// STATE
//============================================================================

// --- the RUNNING cycle -----------------------------------------------------
reg        run;
reg  [2:0] ts;            // T-state during this clock
reg  [2:0] cur_bs;
reg [19:0] cur_addr;
reg [15:0] cur_data;      // read data latched at T2 / paired write data
reg        cur_ube_n;
// M5b: the ACCESS's own A0, carried by every cycle of it.  The S5 fallback
// (`a store that reaches T1 unpaired drives what is still standing in OPR`)
// rotates by THIS, not by the cycle's own address -- `sim/biu_timed.cpp` keeps
// it as `Access::odd_base` for exactly that reason, and the second half of a
// split word store has an EVEN address but an ODD base (`A5` MOVSW).
reg        cur_odd;
reg  [1:0] cur_seg;
reg        cur_fetch;
reg        cur_halt;
reg        cur_noaddr;    // M15: an INTA drives no address
reg        cur_wr;
reg        cur_need;      // S5: reserved, data not paired yet
reg        cur_rd_last;   // a SPLIT is ONE access: releases on the 2nd cycle
reg  [1:0] cur_pn;        // queue bytes this fetch delivers (0 = doomed)
reg        cur_late_t1;   // M23: this T1 did NOT open at disp+1
reg        evald;         // the completion eval has fired for this cycle
reg  [1:0] sev;           // clocks since that eval (bounded, asserted)
reg  [2:0] dage;          // this cycle's age from its own DISPLAY clock

// --- the ANNOUNCEMENT (the registered status output, M2) -------------------
reg        cmt_valid;
reg  [2:0] cmt_bs;
reg [19:0] cmt_addr;
reg [15:0] cmt_data;
reg        cmt_ube_n;
reg        cmt_odd;
reg  [1:0] cmt_seg;
reg        cmt_fetch;
reg        cmt_halt;
reg        cmt_noaddr;
reg        cmt_wr;
reg        cmt_need;
reg        cmt_rd_last;
reg  [1:0] cmt_pn;
reg  [2:0] cdage;         // M22: clocks since the DISPLAY (saturates)
reg [15:0] cmt_prev_fp;   // fetch_ptr before this fetch took it
reg        cmt_was_owed;  // M19's latch as it stood before the grant

// --- pad retention ---------------------------------------------------------
reg        last_ube;
reg [15:0] last_fetch_addr;
// F58: THE AD OUTPUT LATCH ITSELF, one lane per output enable.  See the
// always block near `last_ube` and the HALT display in step (e).
reg  [3:0] last_ad_hi;
reg [15:0] last_ad_lo;

// --- the queue (M3) --------------------------------------------------------
reg  [7:0] q_mem [0:5];
reg  [2:0] q_head;
reg  [3:0] q_cnt;
reg  [3:0] q_cnt_np;      // WAVE 15 C1: ...before the EU's own pop this clock
reg  [1:0] grn_n;         // newest bytes not yet POPPABLE
reg  [1:0] grn_ttl;       // ...for this many more clocks (ready at e+3)
reg [15:0] fetch_ptr;
reg [15:0] cs_r;

// --- the prefetch scheduler ------------------------------------------------
reg        suspended;
reg        halted;        // S8/S9: once halted the prefetcher never runs again
reg        halt_pending;  // M20: the HLT row's write WAITING for the register
reg        pf_owed;       // M19: the redirect is a STANDING request
reg        pf_arm;        // M7: the eligibility answer, sampled at T3
// ~~pf_land~~ -- DELETED 2026-08-05 as F56.  M6 (`no fetch is chosen while the
// previous fetch's bytes are LANDING`) is REFUTED by its own firing census and
// is gone from both engines; its save-state code 9'h038 is RETIRED, NOT
// REUSED -- the package says so at the hole it leaves.
// See sim/biu_timed.h at the deleted fields and ucore_provenance.md sec.82.
reg  [1:0] infl_ttl;      // M7b: the outstanding-fetch term
reg  [1:0] infl_n;
reg  [1:0] absorb_ttl;    // F1(b): the QS port while the bytes land
reg        no_eval;       // M2r: the display slot is NOT an eval point
reg        flush_eval;    // F3: the flush-only T4 eval point
reg        e_pend;        // F1: a parked QS=E

// --- SM3 SITTING 11 -- H1's RECOGNITION FLOOR IS GONE FROM THIS MODULE -----
//
// It used to live here as `bnd_pending` / `bnd_arm` / `bnd_stamp` / `bnd_cnt`:
// an INTA armed it, a flush re-armed it, the restarted prefetch's GRANT
// stamped it, a 2-clock counter from that fetch's T1 ran it out, a pop spent
// it, and `bnd_hold` held the EU's boundary open until it fell.  FIVE flops,
// six hook sites, one output port and four save-state addresses.
//
// SM3 sitting 11 SUBSUMED all of it into ONE TERM on a wire the EU's
// recognition already reads: `irq_int_lvl = int_p[2] && ie_p[2] && psw[FIE]`
// -- the LIVE IE as well as the pipelined one.  A gate that demands IE up NOW
// and up three clocks ago cannot act on a rising IE, and that IS the floor.
// With the term in place `bnd_hold` was MEASURED INERT: the whole 3,242-seed
// bank scores identically with it forced to zero -- REGISTERED 1,490,
// EVT 910, COMBINED 2,400, to the seed.
//
// What survives of the mechanism is the prefetcher SUSPEND below, and the EU
// publishes its condition directly now (`eu_bnd_post`, which carries "this is
// a retire AND the IE gate is what held it": `!intr_pending && !ie_p[3]`).
// Forcing that suspend unconditional costs EVT 910 -> 897, so it is a real
// term and it is not guessed.
//
// See `ucore_provenance.md` §72 and `sm3_s11_prereg_2026-08-04.md`.

// --- the EU request slot (M10) and its 2-deep backing store ----------------
reg  [1:0] rq_n;
reg  [2:0] rq_bs   [0:1];
reg [19:0] rq_addr [0:1];
reg [15:0] rq_data [0:1];
reg        rq_ube  [0:1];
reg        rq_odd  [0:1];
reg  [1:0] rq_seg  [0:1];
reg        rq_noaddr [0:1];
reg        rq_wr   [0:1];
reg        rq_need [0:1];
reg        rq_last [0:1];
reg        rq_late [0:1];
// THE 8F GHOST READ'S LAUNCH DECORATION.  `dGR` is the clocks from the ghost
// micro-row going current to the BIU launching its cycle, and the law
// (`ghost_launch_law_results_2026-08-11.md`, 200/200) is
//     dGR == 0 -> SS:SP     dGR == 1 -> stale & SP     dGR >= 2 -> stale
// -- two drivers whose windows overlap for exactly one clock.  `g_age` IS
// `dGR`, saturating at 2 because the law needs no more; `g_row_q` makes the
// arm the ROW'S RISING EDGE, which is the law's own anchor; `g_sp`/`g_bare`
// are the two drivers' composed addresses, captured at that arm.  The AND is
// not carried: it is `rq_addr[]`, the value the EU posts.
reg        rq_ghost [0:1];
reg        cmt_ghost;
reg [19:0] g_sp;
reg [19:0] g_bare;
reg  [1:0] g_age;
reg        g_row_q;
reg        slot_busy;
reg        slot_accept;
reg  [1:0] opr_held;
reg  [7:0] rd_first_hi;   // a split read's first half
reg        rd_was_split;
integer    pk;
// M5b: the ACCESS's own A0, captured on the FIRST half a pairing fills and
// reused on the second -- ONE pass through the 8-bit rotator per ACCESS, not
// one per CYCLE.  (`sim/biu_timed.cpp::mem_write` computes `d` once, outside
// its own two-cycle loop.)  Combinational scratch, not state.
reg        pair_odd;
reg        inta_halt_l;    // combinational HALT-announcement withdrawal edge
reg  [1:0] done_ctr;      // eu_done lands at e+2 -- see the T4 block
reg        done_wr;
reg        rd_done_p;
// P1: `r_wr_done_p`'s ONE functional consumer was `flush_staged_eval`'s fitted
// `!r_wr_done_p`, and that term is deleted (see the P1 block below), so this
// flop is now driven, reset and saved but read only by the save-state mux.
// It is DELIBERATELY left in place with its save-state address (9'h05A) --
// retiring one is the save-state owner's call, and `ss_lint` must stay
// UNMOVED across this landing.  Booked, not taken.  (Do not name the SSA
// symbol here: `ss_lint` counts its occurrences and a third one FAILS the
// gate.  That is the lint working, and it caught this comment.)
reg        wr_done_p;
reg        opr_free_p;
reg [15:0] rd_val;        // OPR, shadowed (see M5b / the string loops)
// ...and the READ-LANDING half of it, published on its own.  `rd_val` is the
// shared shadow: a pairing writes the STORE's word into it (the "drives
// whatever is still standing in OPR" path), which puts `eu_wdata` in its cone
// and would close a combinational loop the moment the EU's act decode reads
// the landing value back (sec.20.2's rule).  `rd_land` is written by the read
// path ONLY, so `eu_rdata_n` stays register-only lookahead.
reg [15:0] rd_land;

// --- M2r: the ONLY wait mechanism -----------------------------------------
reg        ready_prev;

// --- the T1 AD half: a POSEDGE flop enabled by `ce_half` (was the design's
//     one negedge process until 2026-08-13).  MUXED-BUS ONLY since 2026-08-14:
//     it exists to move a SHARED pin and has no next-state consumer. ---------
`ifdef V30_MUXED_AD
reg        t1_half2;
`endif

// --- THE REGISTERS (F7).  Written ONLY by the one `always_ff` at
//     the end of this module; every name above is the NEXT-STATE
//     view the `always_comb` computes from these.
//     See the F7 CONTRACT block in the header.

reg r_run;
reg [2:0] r_ts;
reg [2:0] r_cur_bs;
reg [19:0] r_cur_addr;
reg [15:0] r_cur_data;
reg r_cur_ube_n;
reg r_cur_odd;
reg [1:0] r_cur_seg;
reg r_cur_fetch;
reg r_cur_halt;
reg r_cur_noaddr;
reg r_cur_wr;
reg r_cur_need;
reg r_cur_rd_last;
reg [1:0] r_cur_pn;
reg r_cur_late_t1;
reg r_evald;
reg [1:0] r_sev;
reg [2:0] r_dage;
reg r_cmt_valid;
reg [2:0] r_cmt_bs;
reg [19:0] r_cmt_addr;
reg [15:0] r_cmt_data;
reg r_cmt_ube_n;
reg r_cmt_odd;
reg [1:0] r_cmt_seg;
reg r_cmt_fetch;
reg r_cmt_halt;
reg r_cmt_noaddr;
reg r_cmt_wr;
reg r_cmt_need;
reg r_cmt_rd_last;
reg [1:0] r_cmt_pn;
reg [2:0] r_cdage;
reg [15:0] r_cmt_prev_fp;
reg r_cmt_was_owed;
reg [15:0] r_last_fetch_addr;
reg [2:0] r_q_head;
reg [3:0] r_q_cnt;
reg [1:0] r_grn_n;
reg [1:0] r_grn_ttl;
reg [15:0] r_fetch_ptr;
reg [15:0] r_cs_r;
reg r_suspended;
reg r_halted;
reg r_halt_pending;
reg r_pf_owed;
reg r_pf_arm;
reg [1:0] r_infl_ttl;
reg [1:0] r_infl_n;
reg [1:0] r_absorb_ttl;
reg r_no_eval;
reg r_flush_eval;
reg r_e_pend;
reg [1:0] r_rq_n;
reg r_slot_busy;
reg r_slot_accept;
reg [1:0] r_opr_held;
reg [7:0] r_rd_first_hi;
reg r_rd_was_split;
reg [1:0] r_done_ctr;
reg r_done_wr;
reg r_rd_done_p;
reg r_wr_done_p;
reg r_opr_free_p;
reg [15:0] r_rd_val;
reg [15:0] r_rd_land;
reg r_ready_prev;
reg [7:0] r_q_mem [0:5];
reg [2:0] r_rq_bs [0:1];
reg [19:0] r_rq_addr [0:1];
reg [15:0] r_rq_data [0:1];
reg r_rq_ube [0:1];
reg r_rq_odd [0:1];
reg [1:0] r_rq_seg [0:1];
reg r_rq_noaddr [0:1];
reg r_rq_wr [0:1];
reg r_rq_need [0:1];
reg r_rq_last [0:1];
reg r_rq_late [0:1];
reg r_rq_ghost [0:1];
reg r_cmt_ghost;
reg [19:0] r_g_sp;
reg [19:0] r_g_bare;
reg [1:0] r_g_age;
reg r_g_row_q;

integer ri;   // the always_comb's array copy-in
integer rj;   // the always_ff's array commit


//============================================================================
// COMBINATIONAL VIEWS  (all read ONLY at the top of the edge, see step (a))
//============================================================================

// M9: S6 is the 8080 EMULATION-MODE bit, S5 is IE, S4:S3 the segment code.
function automatic [3:0] data_ps(input [1:0] segc);
    data_ps = {md8080, psw_ie, segc};
endfunction

// F2 (generalised): SUSP -- and an EU bus request, which reaches the BIU
// through the same one-row-early control decode -- takes back a fetch the
// eval has just chosen, before its status reaches the pins.
// H3: a flush-raised prefetch whose EMPTY indication reaches the queue port is
// no longer withdrawn by the following vector request.  Merely having no E
// pending is not enough: ordinary owed announcements can share that state and
// must still be killed.  This is the pin-visible distinction between the two
// opposite trap-entry orderings in wr1/207019; no interrupt-source identity is
// involved.
wire ann_kill  = (q_flush ||
                  ((eu_susp || eu_post) &&
                   !(r_cmt_was_owed && qs_e_now))) &&
                 r_cmt_valid && r_cmt_fetch && (r_cdage == 3'd0);
// M2: `cmt_valid` is cleared when its T1 opens, so "an announcement stands"
// IS "this clock is a display clock".
wire display   = r_cmt_valid && !ann_kill;

// The REP-withdrawal FLUSH can use the redirect edge as an idle arbitration
// point.  Empty tails open T1 directly.  An NMI that meets the
// younger decoder landing (dage <= 4) withdraws that point; the older landing
// has already crossed it.  A staged read tail normally owns the edge, except
// when a still-asserted maskable INT meets it after no write completion on the
// preceding clock: that case takes an ordinary eval on the flush edge (and
// therefore still has a separate announcement clock), not the direct-T1 path.
// A staged completion delays EMPTY except while a running non-fetch access is
// still before T3.  In that early address phase the access owns the bus but
// not the queue status port, so the redirect exposes EMPTY on its own clock;
// from T3 onward the data/READY tail owns the hand-over.  These are all
// existing phase/ownership rails: there is no interrupt counter, queue, or
// identity table.
//
// THE ASSERTED PIN WITHDRAWS THE DIRECT POINT ON *EITHER* TAIL.  `flush_int_live`
// was read by the staged arm only, and the empty arm took the direct point
// unconditionally.  It is ONE rail and it acts the same way on both: while the
// maskable pin is still asserted at the withdrawal the redirect takes an
// ordinary idle eval, so EMPTY stands on the FLUSH row and the announcement
// gets its own clock.  Two disjoint populations, each unanimous:
//   pin ASSERTED  -> ordinary eval : v0.1 `INT.F3AA`, 35 of 35 empty-tail
//                    withdrawals (rows 17-22 of each; the golden is silicon)
//   pin RELEASED  -> direct T1     : fz2c+fz2e, 17 of 17 empty-tail
//                    withdrawals over 623 seeds, all at pin low
// The rail is the PIN, not a flush-clock strobe, because the empty arm has to
// read it one row EARLY (`flush_pre`) as well as on the flush row itself.
// FALSIFIER: an empty-tail withdrawal whose maskable pin CHANGES between those
// two adjacent clocks -- the two reads then disagree and EMPTY is shown twice
// or not at all.  No instance exists in either population above.
//
// SOCKET, 2026-08-06, row 7.40.7 -> redirected CODE T1:
//   empty/direct: mc1/874, mc2/700,2408,3758; NMI-age boundary: mc1/410,607
//   staged/slow:  mc2/633,1616, t30-raw/235; live-INT exception: mc2/573
//
// ...AND THE STAGED TAIL FINALLY READS THE SAME RAIL THE SENTENCE ABOVE IS
// ABOUT.  `flush_int_live` is the MASKABLE pin, and both populations that
// sentence was measured on are maskable ones; the STAGED arm was given that
// rail alone and the NON-MASKABLE recognition was never given to it at all.
// `flush_src_live` is the recognition standing at the withdrawal, whichever
// unit raised it -- the live maskable pin, or the part's own NMI latch, which
// is exactly the pair `v30u_eu.sv` publishes as "the two interrupt rails that
// physically meet the withdrawal edge".
//
// It replaces `flush_staged_eval` IN THE DISPLAY ONLY, where that wire is
// subsumed by construction (`flush_staged_eval` implies `flush_int_live`
// implies `flush_src_live`).  **`flush_staged_eval` ITSELF IS NOT TOUCHED**,
// because it has a SECOND consumer that is not a display at all -- the idle
// clock's arbitration point in step (c) -- so this landing is display-only by
// construction as well as by intent.  ONE term swapped in ONE expression, one
// wire added, no flop and no save-state address.
//
// ...AND P1 IS THAT SECOND CONSUMER.  The paragraph above is A1's, and A1's
// own results named what it left behind: "after a REP withdrawal that is not
// bus-limited, the ucore's restart -- the redirected fetch and everything
// behind it -- is still one clock late."  It is ONE ARBITER and it must read
// ONE RAIL, so `flush_staged_eval` now reads `flush_src_live` too, and the
// display and the arbitration point are finally the same statement about the
// same edge:
//
//   a STAGED withdrawal yields the flush clock's arbitration point to the
//   redirect exactly when a recognition is standing at the withdrawal --
//   maskable pin or NMI latch, whichever unit raised it -- and nothing else
//   is outstanding (`flush_idle`).  The redirect then commits on the
//   withdrawal clock itself and its CODE status is announced at
//   `withdrawal + 1`, instead of being deferred to F3's flush-only point and
//   announced at `withdrawal + 2`.
//
// `!r_wr_done_p` -- "no write completion on the preceding clock" -- is DELETED
// rather than re-fitted.  It is a one-clock lookback with no mechanism behind
// it, and silicon falsifies it 2 for 2 on the only clocks in the fz2 corpus
// that exercise it (`fz2c/408000` and `fz2e/526025`, both `r_wr_done_p = 1`,
// both announced at `withdrawal + 1`).  `flush_stage` and `flush_idle` are
// KEPT: they are ownership rails with a stated mechanism, not fits.
//
// MEASURED, and the statement is exact rather than statistical.  Over all 677
// retained fz2 captures there are 20 REP-withdrawal clocks still in LOCKSTEP
// with silicon at the withdrawal.  Twelve are staged-and-idle with the NMI
// latch standing and the maskable pin RELEASED: silicon announces at +1 and
// the ucore announced at +2 on 12 of 12.  The other eight are unanimous the
// other way -- three have `run = 1` and never reach this arm, one has
// `cmt_valid = 1` and never reaches it either, one has `flush_pend = 0` so
// the suppression is already inactive, and three are empty tails on the
// `flush_direct`/`flush_fast` path -- and all eight ALREADY AGREE with
// silicon.  **The set of clocks this edit changes in the whole retained
// corpus is exactly those twelve.**
//
// FALSIFIER: a staged REP withdrawal on an idle clock with a standing
// recognition and no outstanding EU request, where silicon still announces
// the post-flush CODE status at `withdrawal + 2`.
// SECOND FALSIFIER, for the deleted term: the same, with a write completion
// on the preceding clock (`r_wr_done_p = 1`).
//
// NOT THE CANDIDATE THAT WAS PROPOSED, and the refutation is on the rows:
// `flush_nmi_young`'s fitted `<= 4` cannot be the carrier here, because
// `flush_direct` is 0 on all twelve by `flush_stage` ALONE -- upstream of it
// in the same AND -- and because `flush_nmi_young` is 1 on seven of the twelve
// and 0 on five while the divergence signature is identical on all of them.
// It is untouched.  `docs/notes/fz2_p1_prereg_2026-08-10.md`.
//
// MEASURED, fz2 corpus, and the statement is engine-free: over the 356
// retained event-free captures the EMPTY display is held by the
// REP-withdrawal suppression AND BY NOTHING ELSE on 13 clean-prefix rows; all
// 13 are the STAGED arm with the NMI latch standing, and silicon shows EMPTY
// on that very row on 13 of 13.  The `direct` arm produces no such row at all.
// The queue port still wins and silicon agrees: `fz2c/408062` is a banked
// SUCCESS in which these same rails are set at row 3257 while a CODE fetch
// owns the port (`qs_port_fetch`), and BOTH legs put EMPTY at 3259.
// FALSIFIER: a staged REP withdrawal meeting a standing recognition with the
// queue port otherwise free, where silicon still delays EMPTY one clock.
wire flush_idle = !r_run && !r_cmt_valid && (r_rq_n == 2'd0) && !eu_post;
wire flush_nmi_young = flush_nmi && (r_dage <= 3'd4);
wire flush_src_live = flush_int_live || flush_nmi;
wire flush_staged_eval = flush_stage && flush_pend && flush_src_live &&
                         flush_idle;
wire flush_direct = !flush_stage && !flush_nmi_young && !flush_int_live;
wire flush_fast = flush_rep && flush_idle && flush_direct;
// A hardware acknowledge posted on a CODE T4 replaces a speculative CODE
// announcement already waiting behind that fetch.  The status decoder sees
// the replacement on the collision clock; the ordinary committed-request
// path below still separates that display from its T1.  `eu_post_hold` blocks
// this fast replacement when the EU identifies the slow first-INTA collision.
wire inta_tail_replace = eu_post && (eu_bs == BS_INTA) &&
                         !eu_post_hold &&
                         r_run && r_cur_fetch && (r_ts == TS_T4) &&
                         r_cmt_valid && r_cmt_fetch;
// A HALT wake can leave a speculative CODE announcement standing through the
// pseudo-cycle's T4.  When the dispatcher arrives, silicon withdraws that
// announcement before it opens T1; mc2/327 is the retained socket instance.
// `eu_halt_irq` carries the HALT provenance one clock before the INTA row.
wire inta_follow_preview = eu_post && (eu_bs == BS_INTA) &&
                           r_rd_was_split;
wire inta_preview = inta_tail_replace || inta_follow_preview;
wire vector_follow_preview = eu_vector_post && r_rd_was_split;
// A WITHDRAWN ANNOUNCEMENT IS RELEASED ON ITS OWN CLOCK, AND `bs` HAS ONLY
// ONE SAMPLE PER CLOCK TO SAY SO WITH.
//
// This arm used to force `BS_CODE` onto the HALT pseudo-cycle's T4 -- "keep
// CODE visible on that T4 even though the request has been rewound".  On the
// ADDRESS-PHASE sample that is right, and MEASURED: silicon reads
// `bs_early = CODE` there in every one of the corpus's withdrawn-announcement
// wakes.  On the END-OF-CLOCK sample it is WRONG, and measured just as
// directly -- the same rows read `bs_late = PASV`, against `bs_late = CODE`
// on every GENUINE announcement including the T4 replacement (`fz2c/403020`
// row 170).  A withdrawn announcement is a status latch being RELEASED; a
// genuine one is a status latch being HELD into its T1.
//
// The end-of-clock sample is the one that MOVES THE MACHINE.  `nec_bus` -- the
// harness, and the fabric hardware -- advances its T-state tracker out of T4
// on `bs_q`, the end-of-clock sample (`nec_bus.sv` 322, 364-370), and it
// advances the wait-LFSR ONCE PER BUS CYCLE AT T1 ENTRY.  Holding CODE to the
// end of that clock therefore manufactures a PHANTOM T1 on the following
// clock and STEALS A WAIT DRAW, and every later access in the run draws the
// shifted count.  MEASURED on `fz2c/404071` / `fz2e/514044` / `fz2e/516001`:
// the core's own arbitration is silicon's clock for clock through the whole
// wake and both acknowledges -- a registered-state probe disagreed with the
// replayed rows on 6 of 4,063 rows and they were exactly the six the phantom
// cycle mislabels -- and the entire ~1,100-row divergence is downstream of
// this one bit.
//
// So the arm comes OUT and the mux's own release logic answers: the commit
// was rewound so `display` is false, `st_rel` is set on the HALT's T4, and
// `bs` is `BS_PASV`.  THE ADDRESS-PHASE CODE IS NOT RECOVERED -- the ucore has
// one status value per CPU clock where silicon has two, and that residue is
// ONE CELL per wake, pre-registered and reported as such
// (`docs/notes/ackwake_prereg_2026-08-11.md` §2.1 A-4).
//
// Falsifier: a capture in which a WITHDRAWN announcement carries its status on
// the END-OF-CLOCK sample, or a GENUINE one is PASV there on the clock before
// its T1.  Neither exists in the 654 retained fz2 captures.
// A direct REP redirect is the one fetch whose T1 opened without a registered
// announcement.  Its announcement age therefore remains zero for the whole
// cycle; an ordinary fetch necessarily starts with cdage >= 1.  The other
// eligible overlap is the final landing phase of a fetch.  `absorb=1`
// identifies that landing.  A no-wait landing still has an unripe queue and
// age <= 4; the first waited landing has made the queue ripe and reached age
// 5.  Older landings are the measured stale-tail counterexamples.  Publish
// only this existing phase state so the vector sequencer needs no new history
// latch on either side.
assign eu_direct_fetch = r_run && r_cur_fetch && (r_cdage == 3'd0);
assign eu_fetch_tail = (r_absorb_ttl == 2'd1) &&
                       ((!q_ripe && (r_dage <= 3'd4)) ||
                        (q_ripe && (r_dage == 3'd5)));
// THE 8F GHOST READ'S THREE PUBLISHED RAILS -- ON THE REGISTERED READY, NOT
// ON THE PIN.  §73 / R7', and it is this module's OWN discipline rather than a
// workaround: M2r (the header, verbatim) says "the CPU registers READY at the
// end of every clock", and every other READY consumer here already obeys it.
// The ONLY places the bare pin appears are the `ts` advance itself and
// `rd_data_edge`, §73's one declared carrier.  `5403671558` published these
// rails off the bare pin, which made them R7' carriers into the EU; that is
// what `sw/r7_lint.py` refuses.  Putting them where this module already puts
// READY costs NO flop and NO save-state address.  (The registered pin's
// save-state symbol is deliberately NOT spelled anywhere in this comment:
// `ss_lint` counts those names by text and requires exactly two per symbol, so
// naming one in prose is a third reference and a FAIL -- correctly.)
//
// THE FOURTH RAIL, `eu_rd_wait`, IS NOT HERE.  It has exactly one consumer in
// `5403671558` and that consumer is the ghost FEED, which this landing does
// not take: G6 measured the feed at 15.3 MHz on two draws with every worst
// path launching from the READY register
// (`docs/notes/ghost8f_results_2026-08-09.md` §9).
//
// During fetch T2/Tw the internal AD rail is fully precharged; later phases
// leave the undocumented 8F register-POP address fighting the stack rail.
assign eu_ghost_full = r_run && r_cur_fetch &&
                       ((r_ts == TS_T1) ||
                        ((r_ts == TS_T2) && !r_ready_prev) ||
                        (((r_ts == TS_T3) || (r_ts == TS_TW)) && !r_ready_prev));
// The two other observable points are existing ownership states, not ghost
// history.  At idle the internal address rail has discharged only to its
// byte-slice boundaries.  On a fetch T4 with two ripe bytes, an odd stack
// access has already launched its first byte before the stale rail arrives.
// These are sampled on the request edge, one state before the observer trace
// prints the resulting idle/T4 state.
assign eu_ghost_idle = r_run && r_cur_fetch && (r_ts == TS_T4);
assign eu_ghost_stack_first = r_run && r_cur_fetch &&
                              (r_ts == TS_T3) && r_ready_prev &&
                              (r_q_cnt >= 4'd2);

// M1/M2r: the eval instant.  See the header.
wire eval_inst = r_run && !r_evald &&
                 (r_cur_halt ? (r_dage >= 3'd2)
                           : ((r_dage >= 3'd3) && r_ready_prev));
// M2: ...and the status register is RELEASED at that instant (inclusive).
wire st_rel    = r_evald || eval_inst ||
                 (r_run && r_cur_noaddr && r_cur_odd &&
                  (r_ts >= TS_T2));
// M21: from the HALT's status release on there is no bus cycle left to
// arbitrate, so EVERY clock is an ordinary idle eval.
wire halt_free = r_run && r_cur_halt && r_evald;

// M13 / 11.4: the completion pulse the NEXT clock will carry.  `done_ctr` is
// the whole mechanism, so the pulse is known one clock ahead FROM THE REGISTERS
// -- it is not part of the next-state cone, and publishing it therefore closes
// no loop even though the EU's act decode reads it.
wire done_fire   = (r_done_ctr == 2'd1);
wire rd_done_nxt = done_fire && !r_done_wr;
wire wr_done_nxt = done_fire &&  r_done_wr;

// THE READ'S DATA EDGE.  `eu_rdata_n` / `eu_rd_done_n` are the DELIVERY -- the
// word reaching OPR at e+2 -- and there is one consumer that does not wait for
// it: the flag register (see v30u_eu.sv block (a), and interrupt_model.md,
// "POP PSW consumes the popped image at its read's data edge -- the new IE
// shows in the PS bits during the read's own T4").  This is that edge: the
// T3/Tw -> T4 advance IS the READY sample (see the `case (ts)` below), so it
// is the edge the read data latch closes on, and `cur_data` has held the word
// since the end of T2.
//
// Register-only + `ready`, exactly like `done_fire`, so publishing it closes no
// loop.  It deliberately does NOT carry this clock's `q_flush`: a flush is an
// EU output, and the only consumer is a micro-row that is STANDING BLOCKED on
// its own F interlock, which by construction is not the row that flushes.
wire rd_data_edge = r_run && !r_cur_wr && !r_cur_fetch && !r_cur_halt &&
                    r_cur_rd_last &&
                    ((r_ts == TS_T3) || (r_ts == TS_TW)) && ready;
// ...through the same byte rotator the landing uses, one clock earlier.
wire [15:0] rd_edge_val = r_rd_was_split
                          ? {r_cur_data[7:0], r_rd_first_hi}
                          : (r_cur_addr[0] ? {r_cur_data[7:0], r_cur_data[15:8]}
                                           : r_cur_data);
assign eu_rd_edge   = rd_data_edge;
assign eu_rd_edge_d = rd_edge_val;

// M3: the front byte is poppable when it is not one of the green ones.
wire [3:0] poppable = (r_grn_ttl != 2'd0) ? (r_q_cnt - {2'b0, r_grn_n}) : r_q_cnt;
assign q_ripe   = poppable != 4'd0;
assign q_byte   = r_q_mem[r_q_head];
assign q_cnt_o  = r_q_cnt;
assign halted_o = r_halted;


// F1: a fetch owns the QUEUE PORT from its T1 until its bytes are in.  It
// holds it THROUGH its completion eval (`!evald`); the landing clocks are
// `absorb_ttl`.  A DOOMED fetch pushes nothing and lets go at the eval.
wire qs_port_fetch = r_run && r_cur_fetch && !r_evald;
wire pop_now       = q_pop && q_ripe;
// F1, `e_from`: the queue port is not free on the FLUSH CLOCK ITSELF if a bus
// cycle still owns it -- and only a FETCH owns it, so a flush landing on the
// clock an EU read opens its T1 still takes the port at once.  From the next
// clock on the term is vacuous (`c >= e_from` always holds), which is why it
// is a term of the flush clock and not a flop.
wire e_from_block = q_flush && r_run && r_cur_fetch;
wire qs_e_now = (r_e_pend || q_flush ||
                (flush_pre && flush_direct)) &&
                !(q_flush && flush_rep &&
                  (flush_direct ||
                   (flush_pend && !flush_src_live &&
                    !(r_run && !r_cur_fetch && (r_ts < TS_T3))))) &&
                !pop_now && !e_from_block &&
                (r_absorb_ttl == 2'd0) && !qs_port_fetch &&
                // (c) a ready-but-not-started EU request owns the next slot
                // and the flush display waits for that request's STATUS
                // clock -- except on the flush clock itself.
                // F33 -- ...and "a ready-but-not-yet-started EU request" MEANS
                // the one this clock is posting.  The model tests `req_` LIVE
                // inside `record()`, and the row's `post()` has already run by
                // then (the body precedes the row's own `charge(1)`); the RTL
                // tested the REGISTER `r_rq_n`, which is one clock behind, so a
                // flush row that also posts saw an empty queue and took the QS
                // port at once.  `eu_post` is the EU's ordinary combinational
                // request line -- the same one `ann_kill` above reads.
                // MEASURED: `E8 idx 1` shows E on the push's ANNOUNCEMENT
                // clock (row 8), not on the flush row's own clock (row 7).
                (((r_rq_n == 2'd0) && !eu_post) || q_flush ||
                 (flush_pre && flush_direct) ||
                 (r_cmt_valid && !r_cmt_fetch) || (r_run && !r_cur_fetch));

assign qs = qs_e_now ? QS_EMPTY
          : pop_now  ? (q_first ? QS_FIRST : QS_SUBSEQ)
                     : QS_NONE;

//----------------------------------------------------------------------------
// THE EU CONTRACT (F7).  TWO NAMED VIEWS, EACH COMPUTED IN ONE PLACE.
//
//   `<x>`    -- THE REGISTER: the BIU's level DURING this clock.  The EU's
//               COMBINATIONAL act decode reads these, because the act it
//               drives is consumed by the BIU on the clock that names it.
//   `<x>_n`  -- THE NEXT LEVEL: what that register takes at this edge, read
//               straight off the next-state view above.  The EU's CLOCKED step
//               reads these, because that step produces the EU's state for the
//               clock this edge OPENS, and must see the BIU as it will then be.
//
// Neither view depends on the order in which the two modules' processes are
// evaluated -- which is the whole point (F7).  The `_n` group drives EU FLOPS
// only; no EU combinational output reads it, so it closes no loop and the BIU
// keeps a registered boundary in the direction the EU drives.
//----------------------------------------------------------------------------
assign eu_slot_busy   = r_slot_busy;
assign eu_slot_busy_n = slot_busy;
assign eu_access_active = r_run && !r_cur_fetch && !r_cur_halt;
assign eu_wr_done_n   = wr_done_nxt;
assign eu_wr_eval     = eval_inst && r_cur_wr && r_cur_rd_last;
// F31 -- OPR-OWNERSHIP IS ONE COUNTER, AND IT IS THE BIU'S.  `opr_held` IS the
// model's `BiuTimed::opr_held_`, condition for condition; the EU used to keep a
// SECOND count of the same event and test it against a release PULSE.  The
// published fact is now the model's own predicate -- `while (opr_held_ > 0)
// tick()` -- off the REGISTER, so it is a level during the clock the row runs
// on and the act decode and the clocked step read ONE expression (F11).
assign eu_opr_free    = (r_opr_held == 2'd0);
assign eu_rdata_n     = r_rd_land;
assign eu_rd_done_n   = rd_done_nxt;
// The 1BL retire lead (`wait_retire_lead`): the front byte is poppable NOW or
// will be on the next clock -- the green window has one clock left to run.
// Consumed by the clocked step alone, so it exists in the `_n` view only.
//
// WAVE 15 C1 -- AND IT IS PUBLISHED AS TWO LEVELS, BECAUSE THE ANSWER DEPENDS
// ON WHETHER THE EU POPS AND THE EU IS THE ONE WHO KNOWS.
//
// Walking every write to the three operands of this predicate, the dependence
// on the EU is exactly TWO BITS: `q_pop` (the decrement, ONE place) and
// `q_flush` (the zeroing).  A flush OVERWRITES the count, so on a flush the pop
// is irrelevant and there are THREE levels, not four -- and `q_flush` is not on
// the binding arc, so only the pop is split here.
//
// `q_cnt_np` is the count WITHOUT the pop, so both levels below are pure
// functions of the BIU's own registers (and `q_flush`).  It is the SAME
// function against two thresholds: "at least one" and "at least two".  The EU
// selects with `q_pop && q_ripe && !q_flush` -- two of its own outputs and a
// BIU REGISTER port it already has -- so its pop never leaves the EU, and the
// EU -> BIU -> EU combinational excursion this predicate used to make is gone.
//
// F7 IS UNCHANGED AND IS THE REASON THIS IS SHAPED SO: the step must see the
// queue AS IT WILL BE, pop included.  Severing that costs 181 goldens
// (`FA` 74 + `FB` 68 + `INT.FB` 39, all ONE_BYTE_LOGIC forms, which is
// `wait_retire_lead`'s only caller).  Nothing here severs it; it re-associates
// which side of the module boundary the selection happens on.
wire [3:0] q_cnt_np1  = q_cnt_np - 4'd1;
wire [3:0] poppable_n0 = (grn_ttl != 2'd0) ? (q_cnt_np  - {2'b0, grn_n}) : q_cnt_np;
wire [3:0] poppable_n1 = (grn_ttl != 2'd0) ? (q_cnt_np1 - {2'b0, grn_n}) : q_cnt_np1;
assign q_ripe_lead_n0 = (poppable_n0 != 4'd0) ||
                        ((grn_ttl == 2'd1) && (q_cnt_np  != 4'd0));
assign q_ripe_lead_n1 = (poppable_n1 != 4'd0) ||
                        ((grn_ttl == 2'd1) && (q_cnt_np1 != 4'd0));

`ifndef JTV30_SYNTHESIS
//--------------------------------------------------------------------------
// THE FALSIFIER.  The ORIGINAL expression is kept VERBATIM as a reference and
// compared every clock the EU samples -- the `V30_MUXED_AD` precedent, where
// the historical nine-way mux is kept as a sim-only reference compared every
// fabric clock.  Clause (1) is the identity itself; clause (2) is what makes
// the EU's local select formula sound, because the EU cannot see `pop_eff`.
//--------------------------------------------------------------------------
wire [3:0] poppable_n_ref = (grn_ttl != 2'd0) ? (q_cnt - {2'b0, grn_n}) : q_cnt;
wire q_ripe_lead_n_ref = (poppable_n_ref != 4'd0) ||
                         ((grn_ttl == 2'd1) && (q_cnt != 4'd0));
wire q_ripe_lead_n_comp = pop_eff ? q_ripe_lead_n1 : q_ripe_lead_n0;
always @(posedge clk) if (ce && !srst && !ss_we) begin
    if (q_ripe_lead_n_comp !== q_ripe_lead_n_ref)
        $fatal(1, "v30u_biu: WAVE 15 C1 IDENTITY VIOLATED at %0t -- composed=%b reference=%b  (pop_eff=%b q_cnt=%0d q_cnt_np=%0d grn_n=%0d grn_ttl=%0d)",
               $time, q_ripe_lead_n_comp, q_ripe_lead_n_ref,
               pop_eff, q_cnt, q_cnt_np, grn_n, grn_ttl);
    if (pop_eff !== (q_pop && q_ripe && !q_flush))
        $fatal(1, "v30u_biu: WAVE 15 C1 SELECT VIOLATED at %0t -- pop_eff=%b but q_pop=%b q_ripe=%b q_flush=%b.  The EU composes the select from those three, so they must agree.",
               $time, pop_eff, q_pop, q_ripe, q_flush);
end
`endif

assign ss_bus_quiet = !r_run && !r_cmt_valid && (r_rq_n == 2'd0) && !r_halt_pending;

//----------------------------------------------------------------------------
// PIN DRIVE.  The comparator stack samples AD twice per clock: mid-clock (the
// ADDRESS phase) and at the clock's end (the DATA phase).  `t1_half2` is the
// `ce_half`-enabled flop that switches a WRITE's AD15-0 from address to write
// data.  It flips at `ce_half`+1.0 fabric periods (it was +0.5 until
// 2026-08-13), which is strictly inside the free window, so the external
// T1-falling-edge address latch still sees the address -- and now sees it
// unambiguously rather than by NBA ordering on the same edge.
//----------------------------------------------------------------------------
wire disp_inta = display && r_cmt_noaddr;
wire cur_inta  = r_run && (r_ts == TS_T1) && r_cur_noaddr;
// M10 / F51 -- THE HALT PSEUDO-CYCLE HAS NO DATA PHASE.
//
// Every other cycle hands AD15-0 over at the end of T1: to the write data
// (`t1_half2`) or to the memory.  A HALT hands the bus to NOBODY, so the
// address it announced is never taken away from it and it stands on the pads
// for the whole pseudo-cycle -- A19-16 included, and A19-16 is `data_ps(2)`
// because that is what `note_halt` puts in the access's own `addr` (M10: the
// HALT display's upper nibble is a LIVE PS, not a constant).
//
// This replaces `halt_pin`, which rendered the HALT as though it DID have a
// data phase: it published `{4'h0, r_last_fetch_addr}` through `ad_oe_data`
// with both address enables gated OFF, so the upper nibble was undriven and
// the low lane was let go at the status release.  MEASURED IN FABRIC
// (sec.52.9, sec.53.1): golden `0x2AD8A` against the ucore's `0x0AD8A` on the
// display and its T1, and `0x29090` from T2 where the golden still shows
// `0x2AD8A`.  The socket control on the identical driver reproduces the golden
// 49/49, so it is the core and not the rig.
//
// F41's `!st_rel` term is SUBSUMED, not dropped: a woken fetch whose DISPLAY
// lands inside this cycle still publishes, because `display` precedes
// `halt_addr` in the pin mux and in `ad_oe_addr` below.
//
// F55 -- ...AND "IT STANDS ON THE PADS" IS **RETENTION**, NOT **DRIVE**.
//
// The paragraph above is right about what the pads SHOW and wrong about who
// puts it there.  This wire used to read `r_run && r_cur_halt`, which holds
// `ad_oe_addr` asserted for the WHOLE pseudo-cycle and republishes
// `r_cur_addr` on every clock of it.  A pad that is DRIVEN and a pad that is
// FLOATING at its last driven value are the same value by construction -- until
// a multi-clock announcement takes the pads in between and is then WITHDRAWN.
// Then the part shows the WITHDRAWN cycle's address and the re-driving HALT
// shows its own, and that is the whole of family E's address half: MEASURED on
// `s13-hltsweep-w2 HLT.INT idx 10/11` row 13 and `-w3 idx 12/13/14` row 15,
// and on the 30 S16 cells `w2 d10,d11` / `w3 d12,d13,d14` on all six programs.
// It is the SAME sentence as F53b one pin over -- a pad is loaded by a PHASE
// and held otherwise -- and `sim/biu_timed.cpp` already carries both (sec.80.A).
//
// WHY IT WAS INVISIBLE FOR SO LONG: `tb_v30_core.sv`'s composer is
// protocol-inferred and excludes a HALT-typed cycle from `core_ps_drive`, so
// the DEFAULT TB floats those clocks whatever the core does and scored the 35
// cells green ON THE INSTRUMENT'S AUTHORITY.  `system_large` keys on the
// core's own `AD_OE` port and does not; the fabric agrees with `system_large`
// on 1,654 of 1,654 cells (sec.80.B).
//
// So the address one-shot ends with the address PHASE, and `ad_oe_ps` below
// gains `!r_cur_halt` so that nothing else takes the pads either -- F51's
// "after its address phase it drives nothing", rendered as an enable and not
// as a value.  No flop is added, nothing outside the pin mux is touched.
// Falsifier: any capture in which a HALT pseudo-cycle's AD changes on a clock
// that is neither a display nor a T1 -- i.e. in which the pads are re-driven
// after the announcement.
wire halt_addr = r_run && r_cur_halt && (r_ts == TS_T1);

wire [19:0] flush_fast_addr = {flush_cs, 4'd0} + {4'd0, flush_ip};

assign bs = inta_preview ? BS_INTA
          : vector_follow_preview ? BS_MEMR
          : flush_fast     ? BS_CODE
          : display        ? r_cmt_bs
          : (r_run && !st_rel) ? r_cur_bs
                             : BS_PASV;

// M2: UBE is NOT part of the status register -- it changes ONE CLOCK AFTER
// the status does, so the DISPLAY clock keeps the old UBE.
//
// F53b -- ...AND UBE IS LOADED BY THE ADDRESS PHASE AND THEN HELD.  It is not
// re-driven by a cycle that is merely RUNNING.  The middle term used to be
// `r_run ? r_cur_ube_n`, which re-asserts the running cycle's UBE on every
// clock of its body; that is invisible for an ordinary cycle (the value it
// re-drives is the one the T1 already latched) and WRONG the moment an
// announcement that put its own UBE on the pin is WITHDRAWN -- the pads keep
// the withdrawn cycle's UBE, and the running HALT pseudo-cycle re-drove its
// own `1` over it.  That is ucsim-t sec.26.7.7's open item, seen from the RTL
// side: MEASURED on `s13-hltsweep-w2 HLT.INT idx 10/11` rows 12-13 and
// `-w3 idx 12/13/14` rows 14-15, where the chip holds `ube 0` from the
// withdrawn wake fetch and the ucore reverted to the HALT's `1`.
// Falsifier: a capture in which UBE changes on a clock that is neither a
// display at `cdage != 0` nor a T1.
assign ube_n = (display && (r_cdage != 3'd0)) ? r_cmt_ube_n
             : (r_run && (r_ts == TS_T1))     ? r_cur_ube_n
                                            : last_ube;

// M23: the address one-shot is fired by the DISPLAY and is ONE CLOCK LONG;
// where the bus made the T1 wait it has already expired and A19-16 is back on
// the segment status while A15-0 holds the address by pad retention.
//
// 2026-08-14: M23 is now a PHASE, not a value.  It used to be spelled as a
// `t1_addr` wire that substituted `data_ps(r_cur_seg)` into the address's top
// nibble; it is `bus_ph_hi`'s `!r_cur_late_t1` term below, which selects the
// SAME status nibble from `status_o`.  Nothing about the law moved.

// A segment-register write and the display of an already-committed prefetch
// share one physical address path.  The pending fetch is retargeted from the
// new CS on that clock; a fetch whose T1 is already running is not.
//
// P5' -- ...AND THE VALUE THE ADDER SEES IS THE **WIRED AND** OF THE OLD AND
// THE NEW CS, ON ALL SIXTEEN BITS.  A segment-register read taken WHILE THE
// REGISTER IS BEING WRITTEN is a precharged read bus with two things pulling
// on it -- the cell that still holds the old value and the write driver
// presenting the new one -- so the adder gets `new & old`.  There is no
// asymmetric bit and no delayed SET path: the CS[8] -> A12 rail this expression
// used to carry was that AND seen through a tranche that varied only CS[8].
//
// SILICON, fz2 FLASH #15 corpus, and the two seats agree on all 16 bits:
//   fz2c/406023 row 1230: new 59c9, old f171 -> chip fetch 5c946 = 5141:b536
//   fz2e/527051 row  156: new cddb, old fe6a -> chip fetch d5f06 = cc4a:9a66
//   59c9 & f171 == 5141   ·   cddb & fe6a == cc4a
//
// The 2026-08-06 SOCKET tranche this expression used to cite (four rows, all
// of them varying CS[8] alone) is CONSISTENT with the AND but cannot
// distinguish it from the one-bit rule, because that tranche's `old` CS value
// is recorded nowhere -- not in the comment it was written into and not
// anywhere in the tree.  It is therefore no longer quoted as the authority
// here; the two 16-bit silicon agreements are.
//
// FALSIFIER: any capture in which the retargeted fetch address implies a CS
// with a bit SET that is clear in `flush_cs` or clear in `flush_cs_old`.
//
// ⚠ WHAT THIS DOES NOT FIX, and it is four of the six measured seats: a CS-write
// row that STALLS holds `flush_cs_we` for the whole stall, and `flush_cs`
// during it is NOT the value that will be written (in fz2e/533028 it is the
// instruction's DISPLACEMENT).  The chip writes the register ONCE and takes the
// OLD CS for anything committed before that; the ucore acts on every clock of
// the level, here and at `fetch_lin` below.  No flop-free predicate in this
// module separates "the register is written THIS clock" from "a row that will
// write it is stalled" -- `flush_cs != flush_cs_old` is true throughout, and
// `r_cs_r` observes the change one clock too late.  The fix belongs to
// `v30u_eu.sv` (`wr_cs1` qualified by the row committing).  Seats, booked:
// fz2e/520062 @700, fz2e/528008 @628, fz2e/532012 @328, fz2e/533028 @881 --
// each one's chip fetch is built from `flush_cs_old` exactly.
// (docs/notes/fz2_p4p5_prereg_2026-08-10.md §2.2)
wire [15:0] cmt_cs_live = flush_cs & flush_cs_old;
wire [19:0] cmt_addr_live = {cmt_cs_live, 4'd0} +
                            {4'd0, r_cmt_prev_fp};
wire cmt_cs_retarget = flush_cs_we && r_cmt_valid && r_cmt_fetch;
wire [19:0] display_addr = cmt_cs_retarget ? cmt_addr_live : r_cmt_addr;

// F53 -- M23 ENFORCED ON THE **DISPLAY** SIDE OF THE SAME MUX, AND ON BOTH
// KINDS OF ADDRESS PHASE.
//
// M23's comment above states the law and the RTL enforced it only where the
// T1 was late.  `display` is cleared when its T1 opens (M2), so an announced
// cycle that must wait for a busy bus keeps `display` asserted for EVERY
// waiting clock, and `ad_o` republished the whole 20-bit address on all of
// them.  The one-shot was one clock long on one side of the mux and unbounded
// on the other.  Silicon: A19-16 carries the announced cycle's ADDRESS-PHASE
// value for exactly ONE clock -- the display clock, `r_cdage == 0` -- and
// `data_ps(seg)` on every clock after it until the T1.
//
// AN INTA HAS AN ADDRESS PHASE TOO; its value is simply ZERO (it announces no
// address).  So the same one-shot governs it, and the `20'h0` term below was
// the identical defect one cycle-type over: MEASURED on
// `s10-hltsweep-w0 HLT.INT idx 4/5` row 11 (`INTA T4`, golden nibble `6`,
// ucore `0`) and row 12 (a LATE `INTA T1`, golden `6`).  A NON-late INTA T1
// carries `0`, exactly as `t1_addr` carries the address there -- rows 17/18 of
// the same cell, and `-w2 idx 10` row 14.
//
// No flop is added and nothing outside the pin mux is touched.
// Falsifier: any capture whose A19-16 carries an address on two consecutive
// clocks of one announcement, or a segment status on the display clock itself.
//
// 2026-08-14: F53 too is now a PHASE.  Its three nibble wires (`disp_hi`,
// `dinta_hi`, `cinta_hi`) were three copies of ONE decision -- "is A19-16
// still in the address one-shot?" -- each carrying its own copy of the status
// value.  They are `bus_ph_hi`'s `(r_cdage == 3'd0)` and `!r_cur_late_t1`
// terms below, over ONE status operand.  The three copies survive VERBATIM in
// the sim-only reference at THE RECONSTRUCTION FALSIFIER, which is what proves
// the collapse changed nothing.

// THE PAIRING IS A MID-CLOCK FACT.  `sim/biu_timed.cpp` fills `cur_.data` from
// inside `mem_write`, which the EU calls DURING the clock, and the row that
// same tick() emits already carries the word (`r.ad_data = is_write ?
// cur_.data`).  So the AD data lanes must show the word THIS clock's pairing
// puts there -- the store whose data arrives on its own T1 (`50`: the `E` row
// posts the cycle and the post-`E` row pairs it) otherwise drives the stale
// register through the whole T1.
//
// Loop rule (sec.20.2 as corrected by C1): this is REGISTER-ONLY LOOKAHEAD.
// Its cone is `r_run`/`r_cur_*` plus the EU's combinational `eu_pair` /
// `eu_wdata`, which are functions of EU REGISTERS only, and `ad_o` is a pin
// that feeds nothing inside the core.  It never enters the next-state cone.
wire        pair_now   = eu_pair && r_run && r_cur_wr && r_cur_need;
wire [15:0] cur_data_o = pair_now
                       ? (r_cur_addr[0] ? {eu_wdata[7:0], eu_wdata[15:8]}
                                        : eu_wdata)
                       : r_cur_data;

//----------------------------------------------------------------------------
// THE DE-MUXED BUS.  Three operands, all of them already registers here.
//
// `bus_t1` is the running cycle's own T1; `bus_vfp_pub` is the instant the
// split-read follow-on's preview takes the bus.  In a MUXED build that instant
// is the T1 half (`t1_half2`), because the preview exists ONLY to get the
// follow-on address onto shared pins early; in a DE-MUXED build there are no
// shared pins and no half, so the preview is simply the whole clock.  THAT IS
// THE ONE PLACE THE TWO CONFIGURATIONS DIFFER, and it differs for the reason
// the mechanism exists.
//----------------------------------------------------------------------------
wire bus_t1 = r_run && (r_ts == TS_T1);

// `bus_half` -- THE T1 HALF, AT THE ONLY INSTANT ANYTHING READS IT.
//
// `t1_half2` is loaded at the cycle's `ce_half` with
// `(r_run && (r_ts == TS_T1)) || vector_follow_preview` -- registers (and one
// EU wire off registers) that do not move within a CPU clock -- and S-1 says
// at least one `ce_half` falls between consecutive `ce`s.  SO AT EVERY `ce`,
// `t1_half2` IS THAT EXPRESSION.  `ce` is the only instant the AD output latch
// below loads, so a de-muxed build needs no flop to know the phase: it
// evaluates the same expression.  ASSERTED, NOT ASSUMED -- see the `bus_half`
// equivalence check beside the `t1_half2` flop.
`ifdef V30_MUXED_AD
wire bus_half = t1_half2;
`else
wire bus_half = bus_t1 || vector_follow_preview;
`endif

wire bus_vfp_pub = vector_follow_preview && bus_half;

// `addr_o` -- THE LINEAR ADDRESS OF THE CYCLE THAT OWNS THE BUS.
// VALID FROM the announcement clock (where it carries the ANNOUNCED cycle's
// address) THROUGH the whole of that cycle's T1/T2/Tw/T3/T4 (where it carries
// the RUNNING cycle's).  It is never meaningless: with nothing running it
// holds the last running cycle's address, which is what the pads show by
// retention on the real part.  An INTA announces no address (the model's
// `Access::no_addr`) and it reads ZERO there -- that zero is the part's, not a
// placeholder.
assign addr_o = bus_vfp_pub ? eu_addr
              : flush_fast  ? flush_fast_addr
              : disp_inta   ? 20'h0
              : cur_inta    ? 20'h0
              : display     ? display_addr
                            : r_cur_addr;      // halt / T1 / the data phase

// `data_o` -- THE WRITE WORD OF THE CYCLE THAT OWNS THE BUS, in bus byte order
// (swapped on an odd address, above).  MEANINGFUL whenever the owning cycle is
// a write, from its T1 through T4.  On a read cycle it holds the previous
// write's word and is DECLARED MEANINGLESS -- the muxed view never publishes
// it there either, so nothing has ever depended on it.  No flop: `r_cur_data`
// is a register and the pairing term is the register-only lookahead above.
assign data_o = cur_data_o;

// `status_o` -- {md8080, psw_ie, seg}, the nibble A19-16 carries whenever it is
// not carrying an address.  MEANINGFUL for the whole of the owning cycle, and
// it follows the SAME owner the address does: the ANNOUNCED cycle's segment
// while a display holds the bus, the RUNNING cycle's otherwise.  (`disp_inta`
// outranks `cur_inta` outranks `display`, which is the mux's own order.)
assign status_o = data_ps((disp_inta || (display && !cur_inta)) ? r_cmt_seg
                                                               : r_cur_seg);

//----------------------------------------------------------------------------
// THE MULTIPLEXED VIEW, COMPOSED FROM THE THREE PORTS ABOVE.
//
// A19-16 carries the ADDRESS's top nibble during the address ONE-SHOT and the
// STATUS nibble otherwise; A15-0 carries the address low during an address
// phase and the WRITE DATA otherwise.  That sentence is the whole law and the
// two wires below are its two clauses -- M23 and F53 on the high lane, the T1
// turnaround on the low one.  The view owns NO OPERAND OF ITS OWN, so there is
// no second derivation that can drift from the ports.
//
// ⚠ IT IS COMPUTED IN EVERY CONFIGURATION, AND THAT IS A FINDING, NOT AN
// OVERSIGHT.  See THE AD OUTPUT LATCH below: F58 makes a HALT pseudo-cycle
// PUBLISH the latch, so the shared-pad drive is machine state with a
// functional consumer, not presentation.  A de-muxed core is the SAME MACHINE
// presented differently and must keep it.  What `V30_MUXED_AD` removes is the
// EXPOSURE -- the `ad_o`/`ad_oe_*` ports and the `AD`/`AD_OE` pins above them.
//----------------------------------------------------------------------------
`ifndef V30_MUXED_AD
wire [19:0] ad_o;                              // internal: the latch's input
wire        ad_oe_addr, ad_oe_ps, ad_oe_data;  // internal: which lane it loads
`endif

wire bus_ph_hi = bus_vfp_pub ? 1'b1
               : flush_fast  ? 1'b1
               : disp_inta   ? (r_cdage == 3'd0)          // F53, the INTA half
               : cur_inta    ? !r_cur_late_t1             // F53, a late INTA T1
               : display     ? (r_cdage == 3'd0)          // F53, the display
               : halt_addr   ? 1'b1                       // F51/F55
               : bus_t1      ? ((r_cur_wr && bus_half) || !r_cur_late_t1) // M23
                             : 1'b0;                      // the data phase

wire bus_ph_lo = (bus_vfp_pub || flush_fast || disp_inta || cur_inta ||
                  display || halt_addr) ? 1'b1
               : bus_t1 ? !(r_cur_wr && bus_half)         // the T1 turnaround
                        : 1'b0;                           // the data phase

assign ad_o = {bus_ph_hi ? addr_o[19:16] : status_o,
               bus_ph_lo ? addr_o[15:0]  : data_o};

// F55: `halt_addr` is now wholly subsumed by `bus_t1` in the enable below and
// is left named for what it selects in the composition above -- the HALT's T1
// publishes the whole address, where an ordinary late T1 shows the status.
assign ad_oe_addr = (flush_fast || display || bus_t1 || halt_addr) &&
                    !disp_inta && !cur_inta;
// F55 / F51: a HALT pseudo-cycle has no data phase, so the PS/data drive does
// not take the pads over when the address one-shot expires.  All three enables
// are LOW for the body of a HALT and the pads RETAIN.  (`ad_oe_data` already
// carries `!r_cur_halt`.)
assign ad_oe_ps   = (!ad_oe_addr && r_run && !r_cur_halt &&
                     (r_ts != TS_T1) && (r_ts != TS_TI)) ||
                    disp_inta || cur_inta;
assign ad_oe_data = bus_vfp_pub ||
                    (r_run && r_cur_wr && !r_cur_halt && !r_cur_noaddr &&
                     (r_ts != TS_TI) && !display);

assign rd_n = !(r_run && ((r_ts == TS_T2) || (r_ts == TS_T3) || (r_ts == TS_TW)) &&
                !r_cur_wr && !r_cur_halt);

// THE T1 AD HALF.  `negedge` -> `posedge` 2026-08-13: this was the design's
// LAST negedge-clocked flop, and it is now a plain posedge flop enabled by the
// same `ce_half`.  An enable is not a term, so the value still HOLDS between
// `ce_half`s -- the turnaround simply moves from `ce_half`+0.5 fabric periods
// to `ce_half`+1.0, which is strictly inside the free window C-PIN-1 names.
// The `ss_we` arm travels with it and keeps its save-state address, its bit
// and its meaning, so the save-state stream is unchanged.  (Naming that
// address here would be a THIRD textual reference and `ss_lint` counts them --
// it caught exactly that on the first draft of this comment.)
//
// It was proved instrument-identical on every contract-legal platform and
// REVERTED once, by a scorer running the core at `--ce-div 1` where the
// testbench asserted CE and CE_HALF on the same clock -- outside the core's
// own declared operating contract.  That instrument is fixed
// (`hdl/tb/ce_contract_check.sv`); this is the re-land.
// `docs/notes/t1_half2_posedge_prereg_2026-08-13.md` §2/§3 (hold windows,
// D-cone stability), `docs/notes/ce_contract_reland_prereg_2026-08-13.md`.
//
// 2026-08-14: THE FLOP IS MUXED-BUS MACHINERY AND LIVES UNDER `V30_MUXED_AD`
// WITH THE REST OF IT.  It has zero consumers in the next-state logic, so a
// de-muxed build simply does not have a turnaround to place -- nor a `ce_half`
// to place it with, that pin being this flop's only enable.
`ifdef V30_MUXED_AD
always @(posedge clk)
    if (ss_we && ss_addr == SSA_B_T1_HALF2) t1_half2 <= ss_wdata[0];
    else if (ce_half) t1_half2 <= (r_run && (r_ts == TS_T1)) ||
                                  vector_follow_preview;

`ifndef JTV30_SYNTHESIS
//----------------------------------------------------------------------------
// THE `bus_half` EQUIVALENCE.  The de-muxed configuration has no `ce_half` and
// no `t1_half2`; it reads the phase off the registers the flop is loaded from.
// That is only legitimate AT `ce`, and `ce` is the only instant the AD output
// latch loads -- so this is the exact clause that has to hold, and it is
// checked on every CE clock of every simulation leg the tree runs rather than
// argued from S-1.
//----------------------------------------------------------------------------
always @(posedge clk)
    if (ce && !srst &&
        (t1_half2 !== ((r_run && (r_ts == TS_T1)) || vector_follow_preview)))
        $fatal(1, "v30u_biu: bus_half EQUIVALENCE FAILED at %0t -- t1_half2 %b but (bus_t1 || vfp) %b at a CE instant.  The de-muxed configuration derives the T1 half from these registers and would disagree with the multiplexed one; see docs/notes/demux_bus_prereg_2026-08-14.md.",
               $time, t1_half2,
               ((r_run && (r_ts == TS_T1)) || vector_follow_preview));

//----------------------------------------------------------------------------
// THE RECONSTRUCTION FALSIFIER.
//
// The composition above replaced a nine-way value mux with two phase bits over
// three operands.  That is provably the same function -- and "provably" is not
// a gate.  So the NINE-WAY MUX IS KEPT VERBATIM as a simulation-only reference
// and compared against the composed pins on EVERY FABRIC CLOCK of every sim
// leg the tree runs.  A future edit that moves one and not the other stops the
// run where it happens rather than showing up as a score.
//
// WHY THIS FORM AND NOT "reconstruct from the ports and compare to `ad_o`":
// `ad_o` IS that reconstruction now, so such a check is a tautology.  This one
// compares the composition against the pin law that 169,000 golden cases,
// 17,350 lockstep forms and every bitstream to date were scored on.
//
// ⚠ ONE STATED HOLE: the compare is skipped while the reference carries an X.
// Two X-pessimistic expressions over the same registers may differ in X-ness
// without differing in value, and that is a pre-reset artefact, not a defect.
//
// NON-VACUITY: perturb ONE term of the composition and this fires.
// `docs/notes/demux_bus_prereg_2026-08-14.md` §4.
//----------------------------------------------------------------------------
wire [19:0] t1_addr_ref = r_cur_late_t1 ? {data_ps(r_cur_seg), r_cur_addr[15:0]}
                                        : r_cur_addr;
wire  [3:0] disp_hi_ref  = (r_cdage == 3'd0) ? display_addr[19:16]
                                             : data_ps(r_cmt_seg);
wire  [3:0] dinta_hi_ref = (r_cdage == 3'd0) ? 4'h0
                                             : data_ps(r_cmt_seg);
wire  [3:0] cinta_hi_ref = r_cur_late_t1 ? data_ps(r_cur_seg) : 4'h0;

wire [19:0] ad_o_ref = (vector_follow_preview && t1_half2) ? eu_addr
                     : flush_fast               ? flush_fast_addr
                     : disp_inta                ? {dinta_hi_ref, 16'h0}
                     : cur_inta                 ? {cinta_hi_ref, 16'h0}
                     : display                  ? {disp_hi_ref, display_addr[15:0]}
                     : halt_addr                ? r_cur_addr
                     : (r_run && (r_ts == TS_T1))  ? (r_cur_wr && t1_half2
                                                  ? {r_cur_addr[19:16], cur_data_o}
                                                  : t1_addr_ref)
                                               : {data_ps(r_cur_seg), cur_data_o};

always @(posedge clk)
    if ((^ad_o_ref !== 1'bx) && (ad_o !== ad_o_ref))
        $fatal(1, "v30u_biu: DE-MUX RECONSTRUCTION FAILED at %0t -- composed AD %05x, muxed law %05x (addr_o %05x data_o %04x status_o %01x hi %b lo %b).  The de-muxed ports and the multiplexed view have DRIFTED; see docs/notes/demux_bus_prereg_2026-08-14.md §4.",
               $time, ad_o, ad_o_ref, addr_o, data_o, status_o,
               bus_ph_hi, bus_ph_lo);
`endif
`endif

//============================================================================
// THE CLOCK
//============================================================================

integer i;
integer lfa_need;   // S9a: the pre-window fetch walk (backdoor preload)
reg [15:0] lfa_p;
reg [19:0] lfa_a;
// step (a) captures -- clock-c values the later steps must not re-read
reg        ne_now, kill_l, evi_l, hfree_l, pop_l, qse_l;
reg        pop_eff;    // WAVE 15 C1: `pop_l` AND the flush did not wipe it
reg  [1:0] sev_now;
reg        infl_now;
reg  [1:0] infl_n_now;
reg        set_oprfree;
// working
reg        ev_here, ev_latch, did_grant, gr_ok, rmw_yield;
reg  [4:0] occ;
reg  [1:0] land_ttl;
reg  [3:0] qi;
reg [19:0] fetch_lin;
reg  [1:0] rq_n_pre;
reg        set_grn, set_infl, set_absorb, set_noeval;
reg  [1:0] new_ttl;

//--------------------------------------------------------------------------
// THE RESET NEXT-STATE (U4 pass 3, second structural pass -- sec.52.3)
//--------------------------------------------------------------------------
// `srst` was an ARM of the next-state function above, so it sat in the same
// expression tree as the whole BIU and the whole EU chain that consumes this
// module's `_n` view.  Measured on the pass-3 fit: the design's ONLY violating
// paths launched at `system_large|c_reset_q` and `hps_axi_slave|cfg_use_core`
// -- one signal, `core_reset = c_reset_q | ~cfg_use_core` (system_large.sv:372)
// -- and ran `v30u_eu|wb_seg[0]~0` -> `v30u_biu|grn_n` -> `q_ripe_lead_n` ->
// the EU's twelve chain positions, 58.9 ns against 31.25 ns.  It could not be
// excepted: it LAUNCHES OUTSIDE the core, so no CE multicycle covers it.
//
// Given its own function the reset value is constants and the backdoor, the
// run view is provably independent of `srst`, and the bank selects.
reg            run_rst;
reg      [2:0] ts_rst;
reg      [2:0] cur_bs_rst;
reg     [19:0] cur_addr_rst;
reg     [15:0] cur_data_rst;
reg            cur_ube_n_rst;
reg            cur_odd_rst;
reg      [1:0] cur_seg_rst;
reg            cur_fetch_rst;
reg            cur_halt_rst;
reg            cur_noaddr_rst;
reg            cur_wr_rst;
reg            cur_need_rst;
reg            cur_rd_last_rst;
reg      [1:0] cur_pn_rst;
reg            cur_late_t1_rst;
reg            evald_rst;
reg      [1:0] sev_rst;
reg      [2:0] dage_rst;
reg            cmt_valid_rst;
reg      [2:0] cmt_bs_rst;
reg     [19:0] cmt_addr_rst;
reg     [15:0] cmt_data_rst;
reg            cmt_ube_n_rst;
reg            cmt_odd_rst;
reg      [1:0] cmt_seg_rst;
reg            cmt_fetch_rst;
reg            cmt_halt_rst;
reg            cmt_noaddr_rst;
reg            cmt_wr_rst;
reg            cmt_need_rst;
reg            cmt_rd_last_rst;
reg      [1:0] cmt_pn_rst;
reg      [2:0] cdage_rst;
reg     [15:0] cmt_prev_fp_rst;
reg            cmt_was_owed_rst;
reg     [15:0] last_fetch_addr_rst;
reg      [2:0] q_head_rst;
reg      [3:0] q_cnt_rst;
reg      [1:0] grn_n_rst;
reg      [1:0] grn_ttl_rst;
reg     [15:0] fetch_ptr_rst;
reg     [15:0] cs_r_rst;
reg            suspended_rst;
reg            halted_rst;
reg            halt_pending_rst;
reg            pf_owed_rst;
reg            pf_arm_rst;
reg      [1:0] infl_ttl_rst;
reg      [1:0] infl_n_rst;
reg      [1:0] absorb_ttl_rst;
reg            no_eval_rst;
reg            flush_eval_rst;
reg            e_pend_rst;
reg      [1:0] rq_n_rst;
reg            slot_busy_rst;
reg            slot_accept_rst;
reg      [1:0] opr_held_rst;
reg      [7:0] rd_first_hi_rst;
reg            rd_was_split_rst;
reg      [1:0] done_ctr_rst;
reg            done_wr_rst;
reg            rd_done_p_rst;
reg            wr_done_p_rst;
reg            opr_free_p_rst;
reg     [15:0] rd_val_rst;
reg     [15:0] rd_land_rst;
reg            ready_prev_rst;
reg      [7:0] q_mem_rst [0:5];
reg      [2:0] rq_bs_rst [0:1];
reg     [19:0] rq_addr_rst [0:1];
reg     [15:0] rq_data_rst [0:1];
reg            rq_ube_rst [0:1];
reg            rq_odd_rst [0:1];
reg      [1:0] rq_seg_rst [0:1];
reg            rq_noaddr_rst [0:1];
reg            rq_wr_rst [0:1];
reg            rq_need_rst [0:1];
reg            rq_last_rst [0:1];
reg            rq_late_rst [0:1];
reg            rq_ghost_rst [0:1];
reg            cmt_ghost_rst;
reg     [19:0] g_sp_rst;
reg     [19:0] g_bare_rst;
reg      [1:0] g_age_rst;
reg            g_row_q_rst;

integer i_rst;        // the reset function's own working values --
reg [15:0] lfa_p_rst;  // block-local, so the run function keeps its own
integer    lfa_need_rst;
reg [19:0] lfa_a_rst;
always_comb begin
    lfa_p_rst = 16'd0; lfa_need_rst = 0; lfa_a_rst = 20'd0; i_rst = 0;
    //-- preload, so an unassigned reset arm holds rather than latches
    run_rst = r_run;
    ts_rst = r_ts;
    cur_bs_rst = r_cur_bs;
    cur_addr_rst = r_cur_addr;
    cur_data_rst = r_cur_data;
    cur_ube_n_rst = r_cur_ube_n;
    cur_odd_rst = r_cur_odd;
    cur_seg_rst = r_cur_seg;
    cur_fetch_rst = r_cur_fetch;
    cur_halt_rst = r_cur_halt;
    cur_noaddr_rst = r_cur_noaddr;
    cur_wr_rst = r_cur_wr;
    cur_need_rst = r_cur_need;
    cur_rd_last_rst = r_cur_rd_last;
    cur_pn_rst = r_cur_pn;
    cur_late_t1_rst = r_cur_late_t1;
    evald_rst = r_evald;
    sev_rst = r_sev;
    dage_rst = r_dage;
    cmt_valid_rst = r_cmt_valid;
    cmt_bs_rst = r_cmt_bs;
    cmt_addr_rst = r_cmt_addr;
    cmt_data_rst = r_cmt_data;
    cmt_ube_n_rst = r_cmt_ube_n;
    cmt_odd_rst = r_cmt_odd;
    cmt_seg_rst = r_cmt_seg;
    cmt_fetch_rst = r_cmt_fetch;
    cmt_halt_rst = r_cmt_halt;
    cmt_noaddr_rst = r_cmt_noaddr;
    cmt_wr_rst = r_cmt_wr;
    cmt_need_rst = r_cmt_need;
    cmt_rd_last_rst = r_cmt_rd_last;
    cmt_pn_rst = r_cmt_pn;
    cdage_rst = r_cdage;
    cmt_prev_fp_rst = r_cmt_prev_fp;
    cmt_was_owed_rst = r_cmt_was_owed;
    last_fetch_addr_rst = r_last_fetch_addr;
    q_head_rst = r_q_head;
    q_cnt_rst = r_q_cnt;
    grn_n_rst = r_grn_n;
    grn_ttl_rst = r_grn_ttl;
    fetch_ptr_rst = r_fetch_ptr;
    cs_r_rst = r_cs_r;
    suspended_rst = r_suspended;
    halted_rst = r_halted;
    halt_pending_rst = r_halt_pending;
    pf_owed_rst = r_pf_owed;
    pf_arm_rst = r_pf_arm;
    infl_ttl_rst = r_infl_ttl;
    infl_n_rst = r_infl_n;
    absorb_ttl_rst = r_absorb_ttl;
    no_eval_rst = r_no_eval;
    flush_eval_rst = r_flush_eval;
    e_pend_rst = r_e_pend;
    rq_n_rst = r_rq_n;
    slot_busy_rst = r_slot_busy;
    slot_accept_rst = r_slot_accept;
    opr_held_rst = r_opr_held;
    rd_first_hi_rst = r_rd_first_hi;
    rd_was_split_rst = r_rd_was_split;
    done_ctr_rst = r_done_ctr;
    done_wr_rst = r_done_wr;
    rd_done_p_rst = r_rd_done_p;
    wr_done_p_rst = r_wr_done_p;
    opr_free_p_rst = r_opr_free_p;
    rd_val_rst = r_rd_val;
    rd_land_rst = r_rd_land;
    ready_prev_rst = r_ready_prev;
    for (i_rst = 0; i_rst < $size(r_q_mem); i_rst = i_rst + 1) q_mem_rst[i_rst] = r_q_mem[i_rst];
    for (i_rst = 0; i_rst < $size(r_rq_bs); i_rst = i_rst + 1) rq_bs_rst[i_rst] = r_rq_bs[i_rst];
    for (i_rst = 0; i_rst < $size(r_rq_addr); i_rst = i_rst + 1) rq_addr_rst[i_rst] = r_rq_addr[i_rst];
    for (i_rst = 0; i_rst < $size(r_rq_data); i_rst = i_rst + 1) rq_data_rst[i_rst] = r_rq_data[i_rst];
    for (i_rst = 0; i_rst < $size(r_rq_ube); i_rst = i_rst + 1) rq_ube_rst[i_rst] = r_rq_ube[i_rst];
    for (i_rst = 0; i_rst < $size(r_rq_odd); i_rst = i_rst + 1) rq_odd_rst[i_rst] = r_rq_odd[i_rst];
    for (i_rst = 0; i_rst < $size(r_rq_seg); i_rst = i_rst + 1) rq_seg_rst[i_rst] = r_rq_seg[i_rst];
    for (i_rst = 0; i_rst < $size(r_rq_noaddr); i_rst = i_rst + 1) rq_noaddr_rst[i_rst] = r_rq_noaddr[i_rst];
    for (i_rst = 0; i_rst < $size(r_rq_wr); i_rst = i_rst + 1) rq_wr_rst[i_rst] = r_rq_wr[i_rst];
    for (i_rst = 0; i_rst < $size(r_rq_need); i_rst = i_rst + 1) rq_need_rst[i_rst] = r_rq_need[i_rst];
    for (i_rst = 0; i_rst < $size(r_rq_last); i_rst = i_rst + 1) rq_last_rst[i_rst] = r_rq_last[i_rst];
    for (i_rst = 0; i_rst < $size(r_rq_late); i_rst = i_rst + 1) rq_late_rst[i_rst] = r_rq_late[i_rst];
    for (i_rst = 0; i_rst < $size(r_rq_ghost); i_rst = i_rst + 1) rq_ghost_rst[i_rst] = r_rq_ghost[i_rst];
    cmt_ghost_rst = r_cmt_ghost;
    g_sp_rst = r_g_sp;
    g_bare_rst = r_g_bare;
    g_age_rst = r_g_age;
    g_row_q_rst = r_g_row_q;

        //--------------------------------------------------------------------
        // RESET == the model's begin_case(), plus the backdoor injection.
        //--------------------------------------------------------------------
        run_rst  = 1'b0; ts_rst  = TS_TI;
        cur_bs_rst  = BS_PASV; cur_addr_rst  = 20'd0; cur_data_rst  = 16'd0;
        cur_ube_n_rst  = 1'b1; cur_seg_rst  = 2'd2; cur_fetch_rst  = 1'b0; cur_odd_rst = 1'b0;
        cur_halt_rst  = 1'b0; cur_noaddr_rst  = 1'b0; cur_wr_rst  = 1'b0;
        cur_need_rst  = 1'b0; cur_rd_last_rst  = 1'b1; cur_pn_rst  = 2'd0;
        cur_late_t1_rst  = 1'b0; evald_rst  = 1'b0; sev_rst  = 2'd0; dage_rst  = 3'd0;
        cmt_valid_rst  = 1'b0; cmt_bs_rst  = BS_PASV; cmt_addr_rst  = 20'd0;
        cmt_data_rst  = 16'd0; cmt_ube_n_rst  = 1'b1; cmt_seg_rst  = 2'd2; cmt_odd_rst = 1'b0;
        cmt_fetch_rst  = 1'b0; cmt_halt_rst  = 1'b0; cmt_noaddr_rst  = 1'b0;
        cmt_wr_rst  = 1'b0; cmt_need_rst  = 1'b0; cmt_rd_last_rst  = 1'b1;
        cmt_pn_rst  = 2'd0; cdage_rst  = 3'd0; cmt_prev_fp_rst  = 16'd0;
        cmt_was_owed_rst  = 1'b0;
        q_head_rst  = 3'd0; grn_n_rst  = 2'd0; grn_ttl_rst  = 2'd0;
        suspended_rst  = 1'b0; halted_rst  = 1'b0; halt_pending_rst  = 1'b0;
        pf_owed_rst  = 1'b0; pf_arm_rst  = 1'b1;
        infl_ttl_rst  = 2'd0; infl_n_rst  = 2'd0; absorb_ttl_rst  = 2'd0;
        no_eval_rst  = 1'b0; flush_eval_rst  = 1'b0; e_pend_rst  = 1'b0;
        rq_n_rst  = 2'd0;
        for (i_rst = 0; i_rst < 2; i_rst = i_rst + 1) begin
            rq_bs_rst[i_rst]  = BS_PASV; rq_addr_rst[i_rst]  = 20'd0; rq_data_rst[i_rst]  = 16'd0;
            rq_ube_rst[i_rst]  = 1'b1; rq_seg_rst[i_rst]  = 2'd2; rq_noaddr_rst[i_rst]  = 1'b0;
            rq_odd_rst[i_rst]  = 1'b0;
            rq_wr_rst[i_rst]  = 1'b0; rq_need_rst[i_rst]  = 1'b0; rq_last_rst[i_rst]  = 1'b1;
            rq_late_rst[i_rst] = 1'b0;
            rq_ghost_rst[i_rst] = 1'b0;
        end
        cmt_ghost_rst = 1'b0;
        g_sp_rst = 20'd0; g_bare_rst = 20'd0;
        g_age_rst = 2'd2; g_row_q_rst = 1'b0;
        slot_busy_rst  = 1'b0; slot_accept_rst  = 1'b0;
        opr_held_rst  = 2'd0; done_ctr_rst  = 2'd0; done_wr_rst  = 1'b0;
        rd_first_hi_rst = 8'd0; rd_was_split_rst = 1'b0;
        rd_done_p_rst  = 1'b0; wr_done_p_rst  = 1'b0; opr_free_p_rst  = 1'b0;
        rd_val_rst  = 16'd0; rd_land_rst = 16'd0;
        ready_prev_rst  = 1'b1;
        if (bkd_load) begin
            // The backdoor injects a RIPE queue at CS:IP with the fetch
            // pointer past it -- `queue_preload`'s post-state exactly.
            cs_r_rst       = bkd_cs;
            fetch_ptr_rst  = bkd_ip;
            q_cnt_rst      = {1'b0, bkd_qlen};
            for (i_rst = 0; i_rst < 6; i_rst = i_rst + 1) q_mem_rst[i_rst]  = bkd_queue[i_rst*8 +: 8];
            // S9a -- ...AND THE LAST OF THOSE PRE-WINDOW FETCHES IS AN ADDRESS
            // THE PART REMEMBERS.  `queue_preload` walks the injected bytes
            // with the real fetch geometry (a word at an even address, one
            // upper-lane byte at an odd one) and keeps the LAST fetch address,
            // because that is what a HALT display drives if the part halts
            // before making a fetch of its own -- the HALT law's "fetch
            // pointer - 2", stated as the address it is derived from.  Left at
            // zero, every HALT display in the injected corpus drove 0 (the
            // `(1, 'bus')` first-divergence of all three `HLT.*` forms).
            lfa_p_rst    = bkd_ip - {13'd0, bkd_qlen};
            lfa_need_rst = {29'd0, bkd_qlen};
            last_fetch_addr_rst = 16'd0;
            for (i_rst = 0; i_rst < 6; i_rst = i_rst + 1) begin
                if (lfa_need_rst > 0) begin
                    lfa_a_rst = {bkd_cs, 4'd0} + {4'd0, lfa_p_rst};
                    last_fetch_addr_rst = lfa_a_rst[15:0];
                    if (lfa_p_rst[0]) begin
                        lfa_p_rst    = lfa_p_rst + 16'd1;
                        lfa_need_rst = lfa_need_rst - 1;
                    end else begin
                        lfa_p_rst    = lfa_p_rst + 16'd2;
                        lfa_need_rst = lfa_need_rst - 2;
                    end
                end
            end
        end else begin
            // The synthesis reset flow: the vector fetch at FFFF0.
            cs_r_rst       = 16'hFFFF;
            fetch_ptr_rst  = 16'h0000;
            q_cnt_rst      = 4'd0;
            for (i_rst = 0; i_rst < 6; i_rst = i_rst + 1) q_mem_rst[i_rst]  = 8'h00;
            last_fetch_addr_rst  = 16'd0;
        end
end

always_comb begin
    //=== F7: the next-state view starts from the registers ===========
    run = r_run;
    ts = r_ts;
    cur_bs = r_cur_bs;
    cur_addr = r_cur_addr;
    cur_data = r_cur_data;
    cur_ube_n = r_cur_ube_n;
    cur_odd = r_cur_odd;
    cur_seg = r_cur_seg;
    cur_fetch = r_cur_fetch;
    cur_halt = r_cur_halt;
    cur_noaddr = r_cur_noaddr;
    cur_wr = r_cur_wr;
    cur_need = r_cur_need;
    cur_rd_last = r_cur_rd_last;
    cur_pn = r_cur_pn;
    cur_late_t1 = r_cur_late_t1;
    evald = r_evald;
    sev = r_sev;
    dage = r_dage;
    cmt_valid = r_cmt_valid;
    cmt_bs = r_cmt_bs;
    cmt_addr = r_cmt_addr;
    cmt_data = r_cmt_data;
    cmt_ube_n = r_cmt_ube_n;
    cmt_odd = r_cmt_odd;
    cmt_seg = r_cmt_seg;
    cmt_fetch = r_cmt_fetch;
    cmt_halt = r_cmt_halt;
    cmt_noaddr = r_cmt_noaddr;
    cmt_wr = r_cmt_wr;
    cmt_need = r_cmt_need;
    cmt_rd_last = r_cmt_rd_last;
    cmt_pn = r_cmt_pn;
    cdage = r_cdage;
    cmt_prev_fp = r_cmt_prev_fp;
    cmt_was_owed = r_cmt_was_owed;
    last_fetch_addr = r_last_fetch_addr;
    lfa_p = 16'd0; lfa_need = 0; lfa_a = 20'd0;   // the preload walk, below
    q_head = r_q_head;
    q_cnt = r_q_cnt;
    grn_n = r_grn_n;
    grn_ttl = r_grn_ttl;
    fetch_ptr = r_fetch_ptr;
    cs_r = r_cs_r;
    suspended = r_suspended;
    halted = r_halted;
    halt_pending = r_halt_pending;
    pf_owed = r_pf_owed;
    pf_arm = r_pf_arm;
    infl_ttl = r_infl_ttl;
    infl_n = r_infl_n;
    absorb_ttl = r_absorb_ttl;
    no_eval = r_no_eval;
    flush_eval = r_flush_eval;
    e_pend = r_e_pend;
    rq_n = r_rq_n;
    slot_busy = r_slot_busy;
    slot_accept = r_slot_accept;
    opr_held = r_opr_held;
    rd_first_hi = r_rd_first_hi;
    rd_was_split = r_rd_was_split;
    done_ctr = r_done_ctr;
    done_wr = r_done_wr;
    rd_done_p = r_rd_done_p;
    wr_done_p = r_wr_done_p;
    opr_free_p = r_opr_free_p;
    rd_val = r_rd_val;
    rd_land = r_rd_land;
    ready_prev = r_ready_prev;
    pair_odd = 1'b0;              // combinational scratch (M5b); no latch
    inta_halt_l = 1'b0;
    for (ri = 0; ri < 6; ri = ri + 1) q_mem[ri] = r_q_mem[ri];
    for (ri = 0; ri < 2; ri = ri + 1) begin
        rq_bs[ri] = r_rq_bs[ri];
        rq_addr[ri] = r_rq_addr[ri];
        rq_data[ri] = r_rq_data[ri];
        rq_ube[ri] = r_rq_ube[ri];
        rq_odd[ri] = r_rq_odd[ri];
        rq_seg[ri] = r_rq_seg[ri];
        rq_noaddr[ri] = r_rq_noaddr[ri];
        rq_wr[ri] = r_rq_wr[ri];
        rq_need[ri] = r_rq_need[ri];
        rq_last[ri] = r_rq_last[ri];
        rq_late[ri] = r_rq_late[ri];
        rq_ghost[ri] = r_rq_ghost[ri];
    end
    cmt_ghost = r_cmt_ghost;
    g_sp = r_g_sp;
    g_bare = r_g_bare;
    g_age = r_g_age;
    g_row_q = r_g_row_q;
    // the per-edge working temporaries (no latches in always_comb)
    ne_now = 1'b0; kill_l = 1'b0; evi_l = 1'b0;
    hfree_l = 1'b0; pop_l = 1'b0; qse_l = 1'b0; sev_now = 2'd0;
    pop_eff = 1'b0; q_cnt_np = 4'd0;
    infl_now = 1'b0; infl_n_now = 2'd0; set_oprfree = 1'b0;
    ev_here = 1'b0; ev_latch = 1'b0; did_grant = 1'b0;
    rmw_yield = 1'b0;
    gr_ok = 1'b0; occ = 5'd0; land_ttl = 2'd0; qi = 4'd0;
    fetch_lin = 20'd0; rq_n_pre = 2'd0;
    set_grn = 1'b0; set_infl = 1'b0; set_absorb = 1'b0;
    set_noeval = 1'b0; new_ttl = 2'd0;
    i = 0; pk = 0;

    if (ss_we) begin
        //--------------------------------------------------------------------
        // save-state WRITE decode (arm #1 of the exactly-twice discipline)
        //--------------------------------------------------------------------
        case (ss_addr)
            SSA_B_RUN:          run           = ss_wdata[0];
            SSA_B_TS:           ts            = ss_wdata[2:0];
            SSA_B_CUR_BS:       cur_bs        = ss_wdata[2:0];
            SSA_B_CUR_ADDR_LO:  cur_addr[15:0]   = ss_wdata;
            SSA_B_CUR_ADDR_HI:  cur_addr[19:16]  = ss_wdata[3:0];
            SSA_B_CUR_DATA:     cur_data      = ss_wdata;
            SSA_B_CUR_UBE_N:    cur_ube_n     = ss_wdata[0];
            SSA_B_CUR_SEG:      cur_seg       = ss_wdata[1:0];
            SSA_B_CUR_FETCH:    cur_fetch     = ss_wdata[0];
            SSA_B_CUR_HALT:     cur_halt      = ss_wdata[0];
            SSA_B_CUR_NOADDR:   cur_noaddr    = ss_wdata[0];
            SSA_B_CUR_WR:       cur_wr        = ss_wdata[0];
            SSA_B_CUR_NEED:     cur_need      = ss_wdata[0];
            SSA_B_CUR_RDLAST:   cur_rd_last   = ss_wdata[0];
            SSA_B_CUR_PN:       cur_pn        = ss_wdata[1:0];
            SSA_B_CUR_LATET1:   cur_late_t1   = ss_wdata[0];
            SSA_B_EVALD:        evald         = ss_wdata[0];
            SSA_B_SEV:          sev           = ss_wdata[1:0];
            SSA_B_DAGE:         dage          = ss_wdata[2:0];
            SSA_B_CMT_VALID:    cmt_valid     = ss_wdata[0];
            SSA_B_CMT_BS:       cmt_bs        = ss_wdata[2:0];
            SSA_B_CMT_ADDR_LO:  cmt_addr[15:0]   = ss_wdata;
            SSA_B_CMT_ADDR_HI:  cmt_addr[19:16]  = ss_wdata[3:0];
            SSA_B_CMT_DATA:     cmt_data      = ss_wdata;
            SSA_B_CMT_UBE_N:    cmt_ube_n     = ss_wdata[0];
            SSA_B_CMT_SEG:      cmt_seg       = ss_wdata[1:0];
            SSA_B_CMT_FETCH:    cmt_fetch     = ss_wdata[0];
            SSA_B_CMT_HALT:     cmt_halt      = ss_wdata[0];
            SSA_B_CMT_NOADDR:   cmt_noaddr    = ss_wdata[0];
            SSA_B_CMT_WR:       cmt_wr        = ss_wdata[0];
            SSA_B_CMT_NEED:     cmt_need      = ss_wdata[0];
            SSA_B_CMT_RDLAST:   cmt_rd_last   = ss_wdata[0];
            SSA_B_CMT_PN:       cmt_pn        = ss_wdata[1:0];
            SSA_B_CDAGE:        cdage         = ss_wdata[2:0];
            SSA_B_CMT_PREV_FP:  cmt_prev_fp   = ss_wdata;
            SSA_B_CMT_WAS_OWED: cmt_was_owed  = ss_wdata[0];
            SSA_B_LAST_FADDR:   last_fetch_addr  = ss_wdata;
            SSA_B_Q0:           q_mem[0]      = ss_wdata[7:0];
            SSA_B_Q1:           q_mem[1]      = ss_wdata[7:0];
            SSA_B_Q2:           q_mem[2]      = ss_wdata[7:0];
            SSA_B_Q3:           q_mem[3]      = ss_wdata[7:0];
            SSA_B_Q4:           q_mem[4]      = ss_wdata[7:0];
            SSA_B_Q5:           q_mem[5]      = ss_wdata[7:0];
            SSA_B_Q_HEAD:       q_head        = ss_wdata[2:0];
            SSA_B_Q_CNT:        q_cnt         = ss_wdata[3:0];
            SSA_B_GRN_N:        grn_n         = ss_wdata[1:0];
            SSA_B_GRN_TTL:      grn_ttl       = ss_wdata[1:0];
            SSA_B_FETCH_PTR:    fetch_ptr     = ss_wdata;
            SSA_B_CS:           cs_r          = ss_wdata;
            SSA_B_SUSPENDED:    suspended     = ss_wdata[0];
            SSA_B_HALTED:       halted        = ss_wdata[0];
            SSA_B_HALT_PEND:    halt_pending  = ss_wdata[0];
            SSA_B_PF_OWED:      pf_owed       = ss_wdata[0];
            SSA_B_PF_ARM:       pf_arm        = ss_wdata[0];
            SSA_B_INFL_TTL:     infl_ttl      = ss_wdata[1:0];
            SSA_B_INFL_N:       infl_n        = ss_wdata[1:0];
            SSA_B_ABSORB_TTL:   absorb_ttl    = ss_wdata[1:0];
            SSA_B_NO_EVAL:      no_eval       = ss_wdata[0];
            SSA_B_FLUSH_EVAL:   flush_eval    = ss_wdata[0];
            SSA_B_E_PEND:       e_pend        = ss_wdata[0];
            SSA_B_RQ_N:         rq_n          = ss_wdata[1:0];
            SSA_B_RQ0_BS:       rq_bs[0]      = ss_wdata[2:0];
            SSA_B_RQ0_ADDR_LO:  rq_addr[0][15:0]   = ss_wdata;
            SSA_B_RQ0_ADDR_HI:  rq_addr[0][19:16]  = ss_wdata[3:0];
            SSA_B_RQ0_DATA:     rq_data[0]    = ss_wdata;
            SSA_B_RQ0_UBE:      rq_ube[0]     = ss_wdata[0];
            SSA_B_RQ0_SEG:      rq_seg[0]     = ss_wdata[1:0];
            SSA_B_RQ0_NOADDR:   rq_noaddr[0]  = ss_wdata[0];
            SSA_B_RQ0_WR:       rq_wr[0]      = ss_wdata[0];
            SSA_B_RQ0_NEED:     rq_need[0]    = ss_wdata[0];
            SSA_B_RQ0_LAST:     rq_last[0]    = ss_wdata[0];
            SSA_B_RQ1_BS:       rq_bs[1]      = ss_wdata[2:0];
            SSA_B_RQ1_ADDR_LO:  rq_addr[1][15:0]   = ss_wdata;
            SSA_B_RQ1_ADDR_HI:  rq_addr[1][19:16]  = ss_wdata[3:0];
            SSA_B_RQ1_DATA:     rq_data[1]    = ss_wdata;
            SSA_B_RQ1_UBE:      rq_ube[1]     = ss_wdata[0];
            SSA_B_RQ1_SEG:      rq_seg[1]     = ss_wdata[1:0];
            SSA_B_RQ1_NOADDR:   rq_noaddr[1]  = ss_wdata[0];
            SSA_B_RQ1_WR:       rq_wr[1]      = ss_wdata[0];
            SSA_B_RQ1_NEED:     rq_need[1]    = ss_wdata[0];
            SSA_B_RQ1_LAST:     rq_last[1]    = ss_wdata[0];
            SSA_B_RQ_LATE: begin
                rq_late[0] = ss_wdata[0];
                rq_late[1] = ss_wdata[1];
            end
            SSA_B_SLOT_BUSY:    slot_busy     = ss_wdata[0];
            SSA_B_SLOT_ACC:     slot_accept   = ss_wdata[0];
            SSA_B_OPR_HELD:     opr_held      = ss_wdata[1:0];
            SSA_B_RD_FIRST_HI:  rd_first_hi   = ss_wdata[7:0];
            SSA_B_RD_WAS_SPLIT: rd_was_split  = ss_wdata[0];
            // F49 (U4): the four the flop census found UNMAPPED here.  The
            // three `*_odd` carry the split access's ODD BASE (the byte swap at
            // :1329); `rd_land` is A COMPLETED READ'S DATA on its way to
            // `eu_rdata_n`, so a restore without it loses a landed word.
            SSA_B_CUR_ODD:      cur_odd       = ss_wdata[0];
            SSA_B_CMT_ODD:      cmt_odd       = ss_wdata[0];
            SSA_B_RQ0_ODD:      rq_odd[0]     = ss_wdata[0];
            SSA_B_RQ1_ODD:      rq_odd[1]     = ss_wdata[0];
            SSA_B_RD_LAND:      rd_land       = ss_wdata;
            SSA_B_DONE_CTR:     done_ctr      = ss_wdata[1:0];
            SSA_B_DONE_WR:      done_wr       = ss_wdata[0];
            SSA_B_RD_DONE_P:    rd_done_p     = ss_wdata[0];
            SSA_B_WR_DONE_P:    wr_done_p     = ss_wdata[0];
            SSA_B_OPR_FREE_P:   opr_free_p    = ss_wdata[0];
            SSA_B_RD_VAL:       rd_val        = ss_wdata;
            SSA_B_READY_PREV:   ready_prev    = ss_wdata[0];
            // the 8F ghost read's LAUNCH decoration (v14)
            SSA_B_GHOST_SP_LO:   g_sp[15:0]    = ss_wdata;
            SSA_B_GHOST_SP_HI:   g_sp[19:16]   = ss_wdata[3:0];
            SSA_B_GHOST_BARE_LO: g_bare[15:0]  = ss_wdata;
            SSA_B_GHOST_BARE_HI: g_bare[19:16] = ss_wdata[3:0];
            SSA_B_GHOST_AGE:     g_age         = ss_wdata[1:0];
            SSA_B_GHOST_TAG: begin
                rq_ghost[0] = ss_wdata[0];
                rq_ghost[1] = ss_wdata[1];
                cmt_ghost   = ss_wdata[2];
                g_row_q     = ss_wdata[3];
            end
            default: ;
        endcase
    end else begin   // <- was `else if (srst)` then `else if (ce)`:
                     //    both selects are on the register bank now
        //====================================================================
        // (a) CAPTURE the clock-c predicates
        //====================================================================
        // THE GHOST READ'S AGE.  This runs FIRST, before the post and before
        // the eval, so that a request posted and granted on the SAME clock
        // (`dGR == 0`) reads the age this line just wrote.  That is the module's
        // own blocking-assignment discipline, the one `rq_*` already relies on.
        // The arm is the ROW'S RISING EDGE -- `upc_opc == 8'h8f &&
        // upc_loc == 4'd4` going current -- which is the law's own anchor and
        // not a re-derived one.  The counter free-runs afterwards and saturates
        // at 2; it is harmless when no ghost is outstanding, because only a
        // TAGGED request reads it.
        g_row_q = eu_ghost_row;
        if (eu_ghost_row && !r_g_row_q) begin
            g_age  = 2'd0;
            g_sp   = eu_ghost_sp;
            g_bare = eu_ghost_bare;
        end else if (g_age != 2'd2) begin
            g_age = g_age + 2'd1;
        end
        ne_now     = no_eval;
        kill_l     = ann_kill;
        evi_l      = eval_inst;
        hfree_l    = halt_free;
        pop_l      = pop_now;
        qse_l      = qs_e_now;
        sev_now    = evald ? sev : 2'd0;
        infl_now   = (infl_ttl != 2'd0);
        infl_n_now = infl_n;
        set_grn = 1'b0; set_infl = 1'b0; set_absorb = 1'b0;
        set_noeval = 1'b0; new_ttl = 2'd0;
        set_oprfree = 1'b0;
        // eu_done rides the eval: it lands at e+2, which is T4+1 at
        // zero waits and T4+2 whenever the cycle took any Tw.  The PULSE is
        // `done_fire` (see the declaration): a function of the REGISTERS
        // alone, which is why it can be published as `eu_*_done_n` without
        // going through this next-state cone.
        rd_done_p = rd_done_nxt; wr_done_p = wr_done_nxt;
        if (done_ctr != 2'd0) done_ctr = done_ctr - 2'd1;

        //====================================================================
        // (b) THE EU's OWN ACTS -- the model makes them at `clk_ == c`, i.e.
        //     before tick(c) runs, so they are visible to this clock's eval.
        //====================================================================

        rq_n_pre = rq_n;
        // the queue POP: a POINT SAMPLE riding this clock
        if (pop_l) begin
            q_head = (q_head == 3'd5) ? 3'd0 : q_head + 3'd1;
            // WAVE 15 C1 -- THE DECREMENT IS APPLIED AT THE END OF THIS BLOCK,
            // NOT HERE.  `q_cnt`'s cone is then POP-FREE all the way to the
            // publish, which is what lets THE EU CONTRACT below hand the EU two
            // pure-register levels instead of one level that depends on the
            // EU's own act.  The four places that READ `q_cnt` between here and
            // the end are compensated with `pop_eff`, and they are the whole
            // list (`occ` twice, `qi`, and the publish).  VALUE-IDENTICAL: the
            // block's own falsifier below `$fatal`s on the first clock it is
            // not.
            pop_eff = 1'b1;
        end
        if (qse_l) e_pend = 1'b0;

        // F2: the withdrawal
        if (kill_l) begin
            cmt_valid = 1'b0;
            fetch_ptr = cmt_prev_fp;
            pf_owed   = cmt_was_owed;   // un-granting un-consumes the request
        end
        // The display mux above exposes the retarget in THIS clock.  Carry
        // the same address into the committed cycle so its following T1 sees
        // the identical value.  Segment shifts cannot change byte parity, so
        // cmt_pn/fetch_ptr need no repair.
        if (flush_cs_we && cmt_valid && cmt_fetch) begin
            cmt_addr = {cmt_cs_live, 4'd0} + {4'd0, cmt_prev_fp};
            last_fetch_addr = cmt_addr[15:0];
        end
        if (eu_susp)   suspended = 1'b1;
        if (eu_resume) suspended = 1'b0;
        // SM3 s11 -- `boundary_no_pop()`'s `susp()`, and it is all that is
        // left of H1 in this module.  The recognition that PAYS the floor
        // also HOLDS THE PREFETCHER OFF: the chip grants the slot between the
        // floor and the acknowledge's own request to NOTHING, which is the
        // census's two idle clocks.  The condition is published by the EU
        // (`eu_bnd_post` = a retire whose IE gate HELD it); forcing it
        // unconditional was MEASURED at EVT 910 -> 897, so it is a real term.
        if (eu_bnd_take && eu_bnd_post) suspended = 1'b1;
        if (eu_unhalt) begin halted = 1'b0; halt_pending = 1'b0; end
        // M16 -- THE DECODE DOES NOT TAKE A COMMITTED FETCH BACK, AND THAT IS
        // A STATEMENT ABOUT *THIS* EDGE.  `note_halt` sets BOTH flags at once
        // in the model, but the two are read from opposite ends of `tick(c)`:
        // the DISPLAY block is at the top (it claims clock `c` itself, which
        // is why `eu_halt` leads), while `halted_` is read by the prefetch
        // eligibility at the END -- and the model's `note_halt` runs at
        // clk_ = pop+1, i.e. AFTER `tick(pop)` has already granted.
        //
        // So only `halt_pending` belongs here.  `halted` is applied below, past
        // the grant, and therefore first bites at the end of the DECODE clock:
        // "a fetch the eval at the end of the OPCODE POP clock already granted
        // runs to completion and the HALT display waits for it."  MEASURED,
        // U2 pass 5, and it is the block's first verification: `HLT.RES idx 1`
        // has the golden's CODE display / T1-T4 on rows 1-5 and the HALT only
        // on row 6, where this line refused the fetch outright.
        if (eu_halt)   halt_pending = 1'b1;

        // post(): the request enters the 2-deep backing store; only the cycle
        // that carries the EU's OWN request takes the single slot (M10).
        if (eu_post && (rq_n != 2'd2)) begin
            // M4 / M10: the 16-bit bus splits an unaligned word into TWO byte
            // cycles, and that split is ONE request to the EU -- the BIU
            // manufactures the second cycle itself and frees the slot at the
            // LAST of the two T1s (`rq_last`).
            rq_bs[rq_n[0]]     = eu_bs;
            rq_addr[rq_n[0]]   = eu_addr;
            rq_data[rq_n[0]]   = 16'd0;
            rq_ube[rq_n[0]]    = (eu_word || eu_addr[0]) ? 1'b0 : 1'b1;
            rq_odd[rq_n[0]]    = eu_addr[0];
            rq_seg[rq_n[0]]    = eu_seg;
            rq_noaddr[rq_n[0]] = (eu_bs == BS_INTA);
            rq_wr[rq_n[0]]     = (eu_bs == BS_MEMW) || (eu_bs == BS_IOW);
            rq_need[rq_n[0]]   = (eu_bs == BS_MEMW) || (eu_bs == BS_IOW);
            rq_last[rq_n[0]]   = !eu_split;
            // H3: retain the request's arrival class across the remainder of
            // the running cycle.  A T3-or-later RMW write has not reserved the
            // next arbitration point as early as the BCD/string controls do.
            rq_late[rq_n[0]]   = run && !cur_fetch && !cur_wr &&
                                  (ts >= TS_T3);
            // ...and WHETHER THIS IS THE 8F GHOST READ.  Only the request the
            // EU posts is tagged; the split partner the BIU manufactures below
            // is not, and keeps its posted address (the residue is named in
            // `ghost_launch_landing_prereg_2026-08-12.md` §7(b)).
            rq_ghost[rq_n[0]]  = eu_ghost_acc;
            rq_n            = rq_n + 2'd1;
            if (eu_split) begin
                rq_bs[1]     = eu_bs;
                rq_addr[1]   = eu_addr2;
                rq_data[1]   = 16'd0;
                rq_ube[1]    = eu_addr2[0] ? 1'b0 : 1'b1;
                rq_odd[1]    = eu_addr[0];   // the ACCESS's base, not this cycle's
                rq_seg[1]    = eu_seg2;
                rq_noaddr[1] = 1'b0;
                rq_wr[1]     = (eu_bs == BS_MEMW) || (eu_bs == BS_IOW);
                rq_need[1]   = (eu_bs == BS_MEMW) || (eu_bs == BS_IOW);
                rq_last[1]   = 1'b1;
                rq_late[1]   = run && !cur_fetch && !cur_wr &&
                               (ts >= TS_T3);
                rq_ghost[1]  = 1'b0;
                rq_n         = 2'd2;
            end
            slot_busy       = 1'b1;
            slot_accept     = 1'b0;
        end

        // M5b: the write-data register is loaded through an 8-bit rotator
        // controlled by A0 of the ACCESS -- ONE pass, and both cycles of a
        // split then drive that same rotated word.
        for (pk = 0; pk < 2; pk = pk + 1)
        if (eu_pair && ((pk == 0) || eu_pair2)) begin
            rd_val = eu_wdata;
            if (run && cur_need) begin
                if (pk == 0) pair_odd = cur_addr[0];
                cur_data = pair_odd ? {eu_wdata[7:0], eu_wdata[15:8]}
                                    : eu_wdata;
                cur_need = 1'b0;
                // 11.4: ...but only until the AD output latch takes the word
                // at T2.  A pairing that lands after that clock never holds.
                //
                // U2 pass 5 -- AND "AFTER THAT CLOCK" MEANS AFTER T2, NOT AFTER
                // T1 (ledger 35.2's booked residue, resolved).  The model's
                // guard is `if (!(r == &cur_ && run_ && ci_ > 1)) ++opr_held_;`
                // and `ci_` is 0=T1, 1=T2 (the release sits at `ci_ == 1` and
                // publishes `opr_free_clk_ = c + 1` = T3), so the hold IS taken
                // at T2 and only refused from T3 on.  Provably a no-op on the
                // current stimulus, which is why the census cannot see it: the
                // release below runs in this same edge and takes it straight
                // back, leaving only `set_oprfree` -- itself documented VACUOUS.
                // *Falsifier*: any pairing on a running write cycle's T2 whose
                // `opr_free_p` the save-state stream then carries.
                if (((ts == TS_T1) || (ts == TS_T2)) && (opr_held != 2'd3))
                    opr_held = opr_held + 2'd1;
            end else if (cmt_valid && cmt_need) begin
                if (pk == 0) pair_odd = cmt_addr[0];
                cmt_data = pair_odd ? {eu_wdata[7:0], eu_wdata[15:8]}
                                    : eu_wdata;
                cmt_need = 1'b0;
                if (opr_held != 2'd3) opr_held = opr_held + 2'd1;
            end else if ((rq_n != 2'd0) && rq_need[0]) begin
                if (pk == 0) pair_odd = rq_addr[0][0];
                rq_data[0] = pair_odd ? {eu_wdata[7:0], eu_wdata[15:8]}
                                      : eu_wdata;
                rq_need[0] = 1'b0;
                if (opr_held != 2'd3) opr_held = opr_held + 2'd1;
            end else if ((rq_n == 2'd2) && rq_need[1]) begin
                if (pk == 0) pair_odd = rq_addr[0][0];
                rq_data[1] = pair_odd ? {eu_wdata[7:0], eu_wdata[15:8]}
                                      : eu_wdata;
                rq_need[1] = 1'b0;
                if (opr_held != 2'd3) opr_held = opr_held + 2'd1;
            end
        end

        // flush(): the redirect.  ORDER MATTERS -- withdrawing a fetch rewinds
        // `fetch_ptr`, so the withdrawal (`kill_l`, above) precedes the load.
        if (q_flush) begin
            q_cnt = 4'd0; q_head = 3'd0; grn_n = 2'd0; grn_ttl = 2'd0;
            pop_eff = 1'b0;   // WAVE 15 C1: the flush OVERWRITES the
                              // count, so the pop's decrement is gone
                              // with it.  This is the one interaction
                              // between the two EU acts and it is
                              // `q_flush` wins.
            cs_r      = flush_cs;
            fetch_ptr = flush_ip;
            suspended = 1'b0;
            infl_ttl  = 2'd0;  infl_now = 1'b0;  // M7b: the accounting
            // M19: the flush RAISES the prefetcher's request.  It stands until
            // the bus takes it -- a later SUSP does not reset it.
            pf_owed = 1'b1;
            // M7: the sampled quantity is the QUEUE COUNTER, and the flush
            // zeroes it, so a latch taken at index 2 of a cycle the flush has
            // just invalidated cannot hold the redirect off.
            pf_arm = 1'b1;
            // M12: ...AND SO DOES EVERY OTHER LATCH THE COMPLETING CYCLE LEFT
            // BEHIND -- the reserved display slot, and the QS-port absorb
            // hold (released, but not before the flush's own clock).
            no_eval = 1'b0;  ne_now = 1'b0;
            absorb_ttl = 2'd0;
            // ...and DOOMED means doomed on either side of the announcement.
            if (run && cur_fetch)       cur_pn = 2'd0;
            if (cmt_valid && cmt_fetch) cmt_pn = 2'd0;
            flush_eval = 1'b1;
            // ...AND THE OWED EMPTY READS THE SAME RAIL THE DISPLAY DOES (D1).
            // The REP withdrawal decides its EMPTY in TWO places: `qs_e_now`
            // above, which suppresses the display on the flush clock when the
            // redirect takes the arbitration point that carries it, and HERE,
            // which decides whether an EMPTY the flush clock could not show is
            // OWED to the next free clock.  `flush_direct` is the rail that
            // says the direct point was taken, and it has been NARROWED TWICE
            // since this line was written -- `flush_nmi_young`, and then
            // `!flush_int_live` ("the asserted pin withdraws the direct
            // arbitration point on EITHER tail").  This site never received
            // either narrowing and still read `!flush_pend` alone, which is 1
            // on every REP-withdrawal flush clock the golden corpus contains,
            // so it reduced to plain `flush_rep` and DROPPED the announcement
            // instead of deferring it.
            //
            // It only shows when the flush clock cannot display EMPTY for an
            // UNRELATED reason -- a CODE fetch owning the queue status port
            // (`e_from_block` / `qs_port_fetch`) -- because only then does this
            // latch decide anything.  At w0 that never happens, which is why
            // 169,000 w0 goldens cannot see it.
            //
            // MEASURED, and the partition is exact: over 173,000 golden cases
            // there are 416 clocks with `q_flush && flush_rep`; on ALL of them
            // `flush_direct`, `flush_pend`, `flush_fast` and `flush_nmi_young`
            // are 0 and `flush_int_live` is 1.  The 301 that showed EMPTY on
            // the flush clock ALL PASS; the 115 that could not ALL FAIL, each
            // with exactly one bad cell, `qop` exp 'E' got '-'.
            //   v0.1 (169,000, all 347 forms): 56 flush clocks, 0 blocked
            //   w0evt 75 / 0 · w1evt 73 / 31 · w2evt 62 / 23
            //   w3evt 63 / 24 · w1evt-biased 87 / 37   (total / blocked)
            //
            // FALSIFIER: a REP withdrawal with `flush_direct` set on a clock
            // where the display was blocked, and where silicon shows no EMPTY
            // on any later clock.  `flush_fast` (which adds `flush_idle`) is
            // the tighter candidate and is DELIBERATELY NOT TAKEN: no golden
            // clock distinguishes them, so the smaller change is the evidenced
            // one.  `!flush_pend` is kept for the same reason.
            if (!qse_l && !(flush_rep && !flush_pend && flush_direct))
                e_pend = 1'b1;
        end
        //====================================================================
        // (c) END OF CLOCK: advance the running cycle
        //====================================================================
        ev_here  = 1'b0;
        ev_latch = 1'b0;
        if (run) begin
            // 11.4 -- THE OPR RELEASE DOES NOT STRETCH.  The store hands its
            // word to the AD output latch at T2 and OPR is free from T3, at
            // every wait level, while eu_done rides the eval.
            if ((ts == TS_T2) && cur_wr && (opr_held != 2'd0)) begin
                opr_held    = opr_held - 2'd1;
                set_oprfree = 1'b1;
            end
            // M7 / M17 -- the prefetch-eligibility test (and the HALT block)
            // is SAMPLED at a fixed cycle index (2 = T3) and LATCHED; the
            // completion eval only APPLIES what that clock decided.
            if (ts == TS_T3) begin
                occ = {1'b0, q_cnt} - {4'b0, pop_eff}   // WAVE 15 C1
                    + (cur_fetch ? {3'b0, cur_pn} : 5'd0)
                    + ((cmt_valid && cmt_fetch) ? {3'b0, cmt_pn} : 5'd0)
                    + (infl_now ? {3'b0, infl_n_now} : 5'd0);
                pf_arm = (occ <= 5'd4) && !halted;
            end

            if (evi_l) begin
                ev_here  = 1'b1;
                // M21 (second half): the HALT's eval has no index-2 latch to
                // apply -- it is an ORDINARY IDLE eval, read live.
                ev_latch = !cur_halt;
                evald    = 1'b1;
                sev      = 2'd1;
                // M2r: the completion eval's DISPLAY clock is not an eval pt.
                set_noeval = 1'b1;
            end
            if (hfree_l) ev_here = 1'b1;    // M21

            if (ts == TS_T4) begin
                //--------------------------------------------------------
                // THE LANDING.  All three windows are the SAME OFFSET from
                // the eval, seen from three places:
                //    ready    = e + 3   (M3, the byte is poppable)
                //    infl to  = e + 2   (M7b, the outstanding-fetch term)
                //    absorb   = e+1..e+2 (F1(b), the QS port)
                // `sev_now` is the distance from the eval to this T4, so
                // ONE number initialises all three.
                //--------------------------------------------------------
                land_ttl = (sev_now >= 2'd2) ? 2'd0 : (2'd2 - sev_now);
                if (cur_fetch && (cur_pn != 2'd0)) begin
                    qi = {1'b0, q_head} + q_cnt - {3'b0, pop_eff};  // WAVE 15 C1
                    if (qi >= 4'd6) qi = qi - 4'd6;
                    if (cur_pn == 2'd2) begin
                        q_mem[qi[2:0]] = cur_data[7:0];
                        qi = (qi == 4'd5) ? 4'd0 : qi + 4'd1;
                        q_mem[qi[2:0]] = cur_data[15:8];
                    end else begin
                        // an ODD-address single-byte fetch takes the UPPER lane
                        q_mem[qi[2:0]] = cur_data[15:8];
                    end
                    q_cnt   = q_cnt + {2'b0, cur_pn};
                    grn_n   = cur_pn;
                    infl_n  = cur_pn;
                    new_ttl = land_ttl;
                    set_grn = 1'b1; set_infl = 1'b1; set_absorb = 1'b1;
                end
                // S9a: the HALT pseudo-cycle is not an EU access at all -- it
                // never went through post(), so it must not complete one.
                if (!cur_fetch && !cur_halt) begin
                    done_wr = cur_wr;
                    // the deadline is e+2: one clock from this T4 at w0, two
                    // whenever the cycle took a Tw.  ONE number again.
                    //
                    // M4/M10: A SPLIT IS ONE ACCESS.  A WRITE reports both of
                    // its cycles -- `wr_pending_` is a count and the retire
                    // deadline is a max -- but a READ hands OPR over exactly
                    // once, on `rd_last`, because that is the cycle that
                    // completes the word (the composition two lines below).
                    // Arming on the first half delivers the half-word early:
                    // measured on 8B, the successor's pop came four clocks
                    // before the golden's.
                    // F57: the WRITE half only.  The READ's completion is
                    // stamped at the cycle's own EVAL -- see the F57 block
                    // after the T-state advance.
                    if (cur_wr)
                        done_ctr = (land_ttl == 2'd0) ? 2'd1 : land_ttl;
                end
                run = 1'b0;
                ts  = TS_TI;
            end else begin
                case (ts)
                    TS_T1: ts = TS_T2;   // the data phase opens on T2
                    TS_T2: begin
                        // The 16-bit system always presents the ALIGNED WORD
                        // on a read; UBE/A0 only decide which half is used.
                        if (!cur_wr && !cur_halt) cur_data = ad_i;
                        ts = TS_T3;
                    end
                    // The T3/Tw -> T4 advance IS the READY sample; the eval
                    // is that same sample one flop later (M2r).
                    TS_T3, TS_TW: begin
                        if (ready && !cur_wr && !cur_halt) cur_data = ad_i;
                        ts = ready ? TS_T4 : TS_TW;
                    end
                    default: ts = TS_T4;
                endcase
            end
            // The waited Tw -> T4 advance and the HALT dispatcher meet inside
            // this edge.  The registered pre-edge still says Tw, so capture
            // the WORKING phase after the advance.
            inta_halt_l = eu_halt_irq && run && cur_halt &&
                          (r_ts == TS_TW) && (ts == TS_T4) &&
                          (r_cdage == 3'd1) && cmt_valid && cmt_fetch;
            if (inta_halt_l) ev_here = 1'b0;
            //--------------------------------------------------------------
            // F57 -- A READ'S COMPLETION IS STAMPED AT THE CYCLE'S OWN EVAL.
            //
            // It sits HERE, after the T-state advance, because the advance is
            // what captures `cur_data = ad_i` at T2 -- and a cycle whose
            // DISPLAY WAITED has its eval AT T2 (M22: at w0 the eval instant
            // is counted from the display, `e_i = disp + 3 - T1`).
            //
            // The pulse lands at `e + 2` (`done_ctr = 2`), which is exactly
            // what the old T4 arm computed for every cycle whose T1 opens the
            // clock after its display -- w0 `e = T4-1` -> T4+1, waited
            // `e = T4` -> T4+2, both unchanged.  What it could NOT express is
            // `e + 2 < T4 + 1`, because a counter armed at T4 cannot fire
            // before T4+1; the old `(land_ttl == 0) ? 1 : land_ttl` clamp IS
            // that inability.  MEASURED: silicon's second acknowledge is
            // `display + 7` at every delay and the model's/ucore's was
            // `T1 + 6`; they part only where a T1 WAITED, which in this whole
            // corpus is the acknowledge after a woken HALT.
            //
            // NO NEW FLOP: `sev_now` already distinguishes "the eval is this
            // T4" from "the eval was earlier", so the two arms cannot both
            // fire, and the composition moves to a clock at which every
            // register it reads is already valid.  The model's edge is
            // `sim/biu_timed.cpp`, the `ci_ == eval_i` block.
            //--------------------------------------------------------------
            if (evi_l && !cur_fetch && !cur_halt && !cur_wr) begin
                if (!cur_rd_last) begin
                    rd_first_hi  = cur_data[15:8];
                    rd_was_split = 1'b1;
                end else begin
                    done_wr  = 1'b0;
                    done_ctr = 2'd2;
                    if (rd_was_split) begin
                        rd_val = {cur_data[7:0], rd_first_hi};
                        rd_was_split = 1'b0;
                    end else begin
                        rd_val = cur_addr[0]
                               ? {cur_data[7:0], cur_data[15:8]}
                               : cur_data;
                    end
                    rd_land = rd_val;
                end
            end
            // A T4-replaced first INTA owes its second acknowledge's display
            // seven clocks from that preview.  Between two non-split INTA
            // cycles the split-valid bit is otherwise unused; carry and spend
            // that one-bit debt here rather than adding state.
            if (evi_l && cur_noaddr && cur_odd)
                rd_was_split = 1'b1;
            // F3: the flush-only point commits the REDIRECT PREFETCH only.  A
            // pending EU request still owns the first slot and an EU access is
            // never granted at a T4, so with a request outstanding it does not
            // fire and both wait for the next normal eval.
            if (!run && cur_fetch && flush_eval && (rq_n == 2'd0))
                ev_here = 1'b1;
        end else if (!cmt_valid && !ne_now &&
                     !(flush_rep && flush_pend && !flush_staged_eval) &&
                     !eu_post_hold) begin
            ev_here = 1'b1;                       // end of an idle clock
        end
        if (inta_follow_preview) rd_was_split = 1'b0;
        if (vector_follow_preview) rd_was_split = 1'b0;
        if (inta_tail_replace) ev_here = 1'b1;
        //====================================================================
        // (d) THE EVAL: pick the next bus cycle
        //====================================================================
        did_grant = 1'b0;
        if (ev_here && !cmt_valid) begin
            flush_eval = 1'b0;    // F3's point is spent by any commit
            gr_ok = 1'b0;
            occ = {1'b0, q_cnt} - {4'b0, pop_eff}   // WAVE 15 C1
                + ((run && cur_fetch) ? {3'b0, cur_pn} : 5'd0)
                + (infl_now ? {3'b0, infl_n_now} : 5'd0);
            // H3: the ordinary short RMW read has one real collision class.
            // A write posted no earlier than T3 has not reserved this eval;
            // when the index-2 prefetch sample also says GO, the fetch takes
            // one slot between the same-address read and write. Requests that
            // arrived by T2 (the exact BCD controls) retain EU priority, and a
            // read stretched past one Tw retains it too.
            rmw_yield = (rq_n != 2'd0) && rq_late[0] && rq_wr[0] &&
                        (rq_bs[0] == BS_MEMW) && !cur_fetch && !cur_wr &&
                        (cur_bs == BS_MEMR) && cur_rd_last &&
                        (rq_addr[0] == cur_addr) && (dage <= 3'd6) &&
                        !(suspended && !pf_owed) &&
                        (ev_latch ? pf_arm : ((occ <= 5'd4) && !halted));
            if ((rq_n != 2'd0) && !rmw_yield) begin
                // M4: an EU access never preempts an in-flight cycle; it wins
                // the next eval.
                cmt_bs = rq_bs[0]; cmt_addr = rq_addr[0];
                // THE LAUNCH DECORATION, AND IT IS THE ONLY THING THAT MOVES.
                // `rq_addr[0]` IS the `dGR == 1` answer -- the wired AND the EU
                // posted -- so the mux has three inputs and only two of them
                // are new registers.  `cmt_ube_n`/`cmt_odd` stay the posted
                // ones (§7(c) of the pre-registration; every BARE value in the
                // measured population is even and nothing here tests it).
                cmt_ghost = rq_ghost[0];
                if (rq_ghost[0] && (g_age != 2'd1))
                    cmt_addr = (g_age == 2'd0) ? g_sp : g_bare;
                cmt_data = rq_data[0]; cmt_ube_n = rq_ube[0];
                cmt_odd = rq_odd[0];
                cmt_seg = rq_seg[0]; cmt_noaddr = rq_noaddr[0];
                cmt_wr = rq_wr[0]; cmt_need = rq_need[0];
                cmt_rd_last = rq_last[0];
                cmt_fetch = 1'b0; cmt_halt = 1'b0; cmt_pn = 2'd0;
                rq_bs[0] = rq_bs[1]; rq_addr[0] = rq_addr[1];
                rq_data[0] = rq_data[1]; rq_ube[0] = rq_ube[1];
                rq_odd[0] = rq_odd[1];
                rq_seg[0] = rq_seg[1]; rq_noaddr[0] = rq_noaddr[1];
                rq_wr[0] = rq_wr[1]; rq_need[0] = rq_need[1];
                rq_last[0] = rq_last[1];
                rq_late[0] = rq_late[1];
                rq_ghost[0] = rq_ghost[1];
                rq_n = rq_n - 2'd1;
                // M10: the slot's occupant now has the T1 that frees it -- the
                // LAST cycle of the access, so a split holds it across both.
                if (cmt_rd_last) slot_accept = 1'b1;
                gr_ok = 1'b1;
            end else if (suspended && !pf_owed) begin
                // F2 keeps SUSP at the eval; M19 -- but SUSP gates the RAISING
                // of a request, not one the flush already raised.
                gr_ok = 1'b0;
            end else begin
                // F56: the ONLY prefetch predicates are M7's index-2 arm,
                // M19's SUSP gate (above) and the request queue.  M6's
                // queue-landing block used to sit here and is DELETED.
                if ((eu_post_hold && !eu_post) ||
                    (ev_latch ? !pf_arm : ((occ > 5'd4) || halted)))
                    gr_ok = 1'b0;
                else begin
                    // The die has one segment-register source.  Fetches see
                    // the EU's live CS even when an undocumented/stalled
                    // sequence changes CS without reaching a flush; keeping
                    // a second BIU-only copy instead leaked the old segment.
                    fetch_lin = {flush_cs, 4'd0} + {4'd0, fetch_ptr};
                    cmt_bs = BS_CODE; cmt_addr = fetch_lin; cmt_data = 16'd0;
                    cmt_ghost = 1'b0;
                    cmt_ube_n = 1'b0; cmt_seg = 2'd2; cmt_noaddr = 1'b0;
                    cmt_odd = 1'b0;
                    cmt_wr = 1'b0; cmt_need = 1'b0; cmt_rd_last = 1'b1;
                    cmt_fetch = 1'b1; cmt_halt = 1'b0;
                    // word fetch at an even address (+2), single upper-lane
                    // byte at an odd one (+1)
                    cmt_pn = fetch_lin[0] ? 2'd1 : 2'd2;
                    cmt_prev_fp = fetch_ptr;
                    last_fetch_addr = fetch_lin[15:0];
                    fetch_ptr = fetch_ptr + {14'd0, cmt_pn};
                    cmt_was_owed = pf_owed;  // M22: ...given back if it expires
                    pf_owed = 1'b0;          // M19: the arbiter has taken it
                    gr_ok = 1'b1;
                end
            end
            if (gr_ok) begin
                if (!cmt_fetch) cmt_was_owed = pf_owed;
                cmt_valid = 1'b1;
                cdage     = 3'd0;
                did_grant = 1'b1;
            end
        end
        // A completion eval may select the just-posted first INTA in the same
        // edge that withdraws HALT's wake fetch.  The hold means RESERVE, not
        // RUN: put that commit back at the front of the existing request store.
        // The first free clock is the measured PASV gap; the saved INTA is
        // announced by the following ordinary idle arbitration.
        if (eu_halt_irq && cur_halt && (r_cdage == 3'd2) &&
            cmt_valid && cmt_noaddr &&
            !run && (rq_n != 2'd2)) begin
            rq_bs[1] = rq_bs[0]; rq_addr[1] = rq_addr[0];
            rq_data[1] = rq_data[0]; rq_ube[1] = rq_ube[0];
            rq_odd[1] = rq_odd[0]; rq_seg[1] = rq_seg[0];
            rq_noaddr[1] = rq_noaddr[0]; rq_wr[1] = rq_wr[0];
            rq_need[1] = rq_need[0]; rq_last[1] = rq_last[0];
            rq_late[1] = rq_late[0];
            rq_ghost[1] = rq_ghost[0];
            rq_bs[0] = cmt_bs; rq_addr[0] = cmt_addr;
            rq_data[0] = cmt_data; rq_ube[0] = cmt_ube_n;
            rq_odd[0] = cmt_odd; rq_seg[0] = cmt_seg;
            rq_noaddr[0] = cmt_noaddr; rq_wr[0] = cmt_wr;
            rq_need[0] = cmt_need; rq_last[0] = cmt_rd_last;
            rq_late[0] = 1'b0;
            rq_ghost[0] = cmt_ghost;
            rq_n = rq_n + 2'd1;
            slot_accept = 1'b0;
            cmt_valid = 1'b0;
        end
        // INTA has no address parity, so its mapped odd latch carries the
        // otherwise stateless T4-replacement provenance through display/T1.
        if (inta_preview && cmt_valid && cmt_noaddr)
            cmt_odd = 1'b1;

        //====================================================================
        // (e) tick(c+1)'s PRE-ROW BLOCK
        //====================================================================
        if (cmt_valid && !did_grant && (cdage != 3'd7))
            cdage = cdage + 3'd1;      // the age the NEXT clock will show

        // M22 -- AN ANNOUNCEMENT EXPIRES.  The register is written at the
        // GRANT and let go at the announced cycle's own release index counted
        // from the DISPLAY; a cycle that never OPENS a T1 never latches a wait
        // count, so that index is the ZERO-WAIT one (display + 3), and it may
        // not be given up before the clock the bus it is waiting for finishes
        // on.  Locally: age >= 3 AND the T1 would open now or on the next
        // clock (`!run` = the bus is free now; `T4` = it frees next clock).
        // ...AND IT UNDOES THE GRANT.
        if (cmt_valid && !did_grant && (cdage >= 3'd3) &&
            (!run || (ts == TS_T4))) begin
            cmt_valid = 1'b0;
            if (cmt_fetch) begin
                fetch_ptr = cmt_prev_fp;
                pf_owed   = cmt_was_owed;
            end else if (rq_n != 2'd2) begin
                // an EU access is not the BIU's to lose: back to the FRONT
                rq_bs[1] = rq_bs[0]; rq_addr[1] = rq_addr[0];
                rq_data[1] = rq_data[0]; rq_ube[1] = rq_ube[0];
                rq_odd[1] = rq_odd[0];
                rq_seg[1] = rq_seg[0]; rq_noaddr[1] = rq_noaddr[0];
                rq_wr[1] = rq_wr[0]; rq_need[1] = rq_need[0];
                rq_last[1] = rq_last[0];
                rq_late[1] = rq_late[0];
                rq_ghost[1] = rq_ghost[0];
                rq_bs[0] = cmt_bs; rq_addr[0] = cmt_addr;
                rq_data[0] = cmt_data; rq_ube[0] = cmt_ube_n;
                rq_odd[0] = cmt_odd;
                rq_seg[0] = cmt_seg; rq_noaddr[0] = cmt_noaddr;
                rq_wr[0] = cmt_wr; rq_need[0] = cmt_need;
                rq_last[0] = cmt_rd_last;
                // This request has already passed an arbitration point; a
                // later announcement expiry must not manufacture a second H3
                // yield from the original post phase.
                rq_late[0] = 1'b0;
                // AN UN-GRANTED GHOST IS STILL A GHOST.  Its `rq_addr[0]`
                // is now the DECORATED value, and that is harmless by
                // arithmetic: this path fires at `cdage >= 3`, so the
                // re-launch is at `g_age == 2` and the mux takes `g_bare`
                // without reading `rq_addr[0]` at all.  Losing the TAG
                // would not be harmless -- it would launch the decorated
                // address as if it were the AND.
                rq_ghost[0] = cmt_ghost;
                rq_n = rq_n + 2'd1;
                slot_accept = 1'b0;
            end
        end

        // HALT-to-INTA ownership beats the speculative wake fetch at the same
        // boundary where ordinary announcement expiry would rewind it.  The
        // request was never a bus cycle, so restore the prefetch pointer and
        // owed token exactly as the expiry path does.
        if (inta_halt_l && cmt_valid && cmt_fetch) begin
            cmt_valid = 1'b0;
            fetch_ptr = cmt_prev_fp;
            pf_owed   = cmt_was_owed;
            // The withdrawal clock is not a second arbitration point.  Reuse
            // the BIU's existing one-clock no-eval latch; the following idle
            // clock commits the already-posted INTA normally.
            set_noeval = 1'b1;
        end

        // S9b: the DISPLAY CLOCK AND THE T1 ARE TWO DIFFERENT THINGS, and the
        // only thing between them is whether the bus is free.
        //     display = eval + 1     T1 = max(display + 1, first free clock)
        if (!run && cmt_valid &&
            ((cdage != 3'd0) ||
             (flush_fast && did_grant && cmt_fetch) ||
             (vector_follow_preview && did_grant && !cmt_fetch))) begin
            run = 1'b1; ts = TS_T1;
            cur_bs = cmt_bs; cur_addr = cmt_addr; cur_data = cmt_data;
            cur_ube_n = cmt_ube_n; cur_seg = cmt_seg; cur_odd = cmt_odd;
            cur_fetch = cmt_fetch; cur_halt = cmt_halt;
            cur_noaddr = cmt_noaddr; cur_wr = cmt_wr; cur_need = cmt_need;
            cur_rd_last = cmt_rd_last; cur_pn = cmt_pn;
            cur_late_t1 = (flush_fast || vector_follow_preview) ? 1'b0
                        : (cdage != 3'd1) || (cmt_noaddr && cmt_odd);
            // The direct redirect has no displayed announcement, but its T1
            // is otherwise an ordinary on-time T1.  Seed the cycle age at the
            // same value so READY/eval/landing cadence remains unchanged.
            dage  = (flush_fast || vector_follow_preview) ? 3'd1 : cdage;
            evald = 1'b0; sev = 2'd0;
            cmt_valid = 1'b0;
            // M10: the bus has TAKEN the whole request -- the slot is free
            // from this clock, which is the clock the blocked row issues on.
            if (!cmt_fetch && cmt_rd_last && slot_accept) begin
                slot_busy   = 1'b0;
                slot_accept = 1'b0;
            end
            // S5: a store that reaches T1 without having been given data
            // drives whatever is STILL STANDING in OPR, rotated by its own A0.
            if (cur_need && cur_wr)
                cur_data = cur_odd ? {rd_val[7:0], rd_val[15:8]} : rd_val;
        end else if (run) begin
            if (dage != 3'd7) dage = dage + 3'd1;
        end

        // M16 (see above): the park itself, applied PAST the grant, so the
        // eval that has already run this edge kept its answer.
        if (eu_halt) halted = 1'b1;

        // S8/S9: the HALT status takes the register on the FIRST clock the
        // register is FREE -- the bus idle and not the eval's display slot.
        // MEASURED at w0/w1/w3 alike: one clock later than a granted cycle's
        // display, because a grant loads the register AT the eval and the HLT
        // row can only load it once the finishing cycle has let go.
        // F43 (SM3 sitting 6) -- ...AND THE DECISION TESTS THE WAKE VISIBLE ON
        // ITS OWN EDGE.  This block decides the display for clock `H` at the
        // edge ending `H-1`; `eu_unhalt` above cancels a display whose wake
        // fired at or before `H-1`, and M20's threshold-1 (`A - H >= -2`,
        // i.e. suppress iff `D <= H`) needs the `D == H` case too.  That is
        // `eu_unhalt_disp`, the same wake one stage further down the same pin
        // pipeline.  A term added to the existing test; nothing new is stored.
        if (halt_pending && !run && !cmt_valid && !set_noeval &&
            !eu_unhalt_disp) begin
            cmt_bs = BS_HALT; cmt_ghost = 1'b0;
            // S9b: the HALT display drives the address latch AS IT STANDS when
            // the cycle takes the register.  M10(T4): the upper nibble is a
            // LIVE PS, not a constant -- the chip carries IE on it.
            // F58: the latch as it stands, not a value of the HALT's own.
            // S9b's "AS IT STANDS when the cycle takes the register" was the
            // right sentence pointed at the wrong register.
            cmt_addr = {last_ad_hi, last_ad_lo};
            cmt_data = last_ad_lo;
            cmt_ube_n = 1'b1; cmt_seg = 2'd2; cmt_noaddr = 1'b0; cmt_odd = 1'b0;
            cmt_wr = 1'b0; cmt_need = 1'b0; cmt_rd_last = 1'b1;
            cmt_fetch = 1'b0; cmt_halt = 1'b1; cmt_pn = 2'd0;
            cmt_valid = 1'b1; cdage = 3'd0; cmt_was_owed = pf_owed;
            halt_pending = 1'b0;
        end

        //====================================================================
        // (f) AGE the relative counters into their clock-c+1 values
        //====================================================================
        ready_prev = ready;
        no_eval    = set_noeval;
        // `opr_free_clk_`, the model's SECOND wait_opr_free loop
        // (`while (clk_ < opr_free_clk_) tick()`).  It is VACUOUS and provably
        // so: `opr_free_clk_` is only ever set to `c+1` inside `tick()` for
        // clock `c`, which leaves `clk_ == c+1`, so the loop's guard is false
        // on entry in every reachable state.  The instant it names is already
        // carried by `opr_held`'s own decrement, which is what F31 publishes.
        // Kept as state because the model keeps it (and it is SS-mapped).
        opr_free_p = set_oprfree;
        if (set_grn)    grn_ttl    = new_ttl;
        else if (grn_ttl    != 2'd0) grn_ttl    = grn_ttl - 2'd1;
        if (set_infl)   infl_ttl   = new_ttl;
        else if (infl_ttl   != 2'd0) infl_ttl   = infl_ttl - 2'd1;
        if (set_absorb) absorb_ttl = new_ttl;
        else if (absorb_ttl != 2'd0) absorb_ttl = absorb_ttl - 2'd1;
        if (run && evald && (sev != 2'd3) && !evi_l) sev = sev + 2'd1;

    end

    //======================================================================
    // WAVE 15 C1 -- THE POP, APPLIED LAST.
    //======================================================================
    // `q_cnt_np` is the queue count this edge would take IF THE EU DID NOT POP
    // -- flush and landing included, pop excluded.  It is the basis THE EU
    // CONTRACT publishes both levels from, and it depends on NO EU act except
    // `q_flush`.  `q_cnt` itself keeps its exact former value, so the register
    // commit, `+utrace` and every other consumer below are unchanged.
    //
    // `pop_eff` is 0 on an `ss_we` clock by initialisation, so this arm is
    // vacuous there, exactly as the in-place decrement was.
    q_cnt_np = q_cnt;
    if (pop_eff) q_cnt = q_cnt - 4'd1;
end

//============================================================================
// THE REGISTERS.  One non-blocking commit of the next-state view above --
// which is what makes every export below order-independent (F7).
//
// ...AND THE ENABLE (U4 pass 3).  Every source below is preloaded from its own
// register at the top of the next-state function, so a CE-low commit would
// write each register back to itself: gating the bank is exactly equivalent,
// and it is the only form from which Quartus extracts a clock enable.
//============================================================================
always_ff @(posedge clk) if (ss_we || srst || ce) begin
    r_run <= (srst && !ss_we) ? run_rst : run;
    r_ts <= (srst && !ss_we) ? ts_rst : ts;
    r_cur_bs <= (srst && !ss_we) ? cur_bs_rst : cur_bs;
    r_cur_addr <= (srst && !ss_we) ? cur_addr_rst : cur_addr;
    r_cur_data <= (srst && !ss_we) ? cur_data_rst : cur_data;
    r_cur_ube_n <= (srst && !ss_we) ? cur_ube_n_rst : cur_ube_n;
    r_cur_odd <= (srst && !ss_we) ? cur_odd_rst : cur_odd;
    r_cur_seg <= (srst && !ss_we) ? cur_seg_rst : cur_seg;
    r_cur_fetch <= (srst && !ss_we) ? cur_fetch_rst : cur_fetch;
    r_cur_halt <= (srst && !ss_we) ? cur_halt_rst : cur_halt;
    r_cur_noaddr <= (srst && !ss_we) ? cur_noaddr_rst : cur_noaddr;
    r_cur_wr <= (srst && !ss_we) ? cur_wr_rst : cur_wr;
    r_cur_need <= (srst && !ss_we) ? cur_need_rst : cur_need;
    r_cur_rd_last <= (srst && !ss_we) ? cur_rd_last_rst : cur_rd_last;
    r_cur_pn <= (srst && !ss_we) ? cur_pn_rst : cur_pn;
    r_cur_late_t1 <= (srst && !ss_we) ? cur_late_t1_rst : cur_late_t1;
    r_evald <= (srst && !ss_we) ? evald_rst : evald;
    r_sev <= (srst && !ss_we) ? sev_rst : sev;
    r_dage <= (srst && !ss_we) ? dage_rst : dage;
    r_cmt_valid <= (srst && !ss_we) ? cmt_valid_rst : cmt_valid;
    r_cmt_bs <= (srst && !ss_we) ? cmt_bs_rst : cmt_bs;
    r_cmt_addr <= (srst && !ss_we) ? cmt_addr_rst : cmt_addr;
    r_cmt_data <= (srst && !ss_we) ? cmt_data_rst : cmt_data;
    r_cmt_ube_n <= (srst && !ss_we) ? cmt_ube_n_rst : cmt_ube_n;
    r_cmt_odd <= (srst && !ss_we) ? cmt_odd_rst : cmt_odd;
    r_cmt_seg <= (srst && !ss_we) ? cmt_seg_rst : cmt_seg;
    r_cmt_fetch <= (srst && !ss_we) ? cmt_fetch_rst : cmt_fetch;
    r_cmt_halt <= (srst && !ss_we) ? cmt_halt_rst : cmt_halt;
    r_cmt_noaddr <= (srst && !ss_we) ? cmt_noaddr_rst : cmt_noaddr;
    r_cmt_wr <= (srst && !ss_we) ? cmt_wr_rst : cmt_wr;
    r_cmt_need <= (srst && !ss_we) ? cmt_need_rst : cmt_need;
    r_cmt_rd_last <= (srst && !ss_we) ? cmt_rd_last_rst : cmt_rd_last;
    r_cmt_pn <= (srst && !ss_we) ? cmt_pn_rst : cmt_pn;
    r_cdage <= (srst && !ss_we) ? cdage_rst : cdage;
    r_cmt_prev_fp <= (srst && !ss_we) ? cmt_prev_fp_rst : cmt_prev_fp;
    r_cmt_was_owed <= (srst && !ss_we) ? cmt_was_owed_rst : cmt_was_owed;
    r_last_fetch_addr <= (srst && !ss_we) ? last_fetch_addr_rst : last_fetch_addr;
    r_q_head <= (srst && !ss_we) ? q_head_rst : q_head;
    r_q_cnt <= (srst && !ss_we) ? q_cnt_rst : q_cnt;
    r_grn_n <= (srst && !ss_we) ? grn_n_rst : grn_n;
    r_grn_ttl <= (srst && !ss_we) ? grn_ttl_rst : grn_ttl;
    r_fetch_ptr <= (srst && !ss_we) ? fetch_ptr_rst : fetch_ptr;
    r_cs_r <= (srst && !ss_we) ? cs_r_rst : cs_r;
    r_suspended <= (srst && !ss_we) ? suspended_rst : suspended;
    r_halted <= (srst && !ss_we) ? halted_rst : halted;
    r_halt_pending <= (srst && !ss_we) ? halt_pending_rst : halt_pending;
    r_pf_owed <= (srst && !ss_we) ? pf_owed_rst : pf_owed;
    r_pf_arm <= (srst && !ss_we) ? pf_arm_rst : pf_arm;
    r_infl_ttl <= (srst && !ss_we) ? infl_ttl_rst : infl_ttl;
    r_infl_n <= (srst && !ss_we) ? infl_n_rst : infl_n;
    r_absorb_ttl <= (srst && !ss_we) ? absorb_ttl_rst : absorb_ttl;
    r_no_eval <= (srst && !ss_we) ? no_eval_rst : no_eval;
    r_flush_eval <= (srst && !ss_we) ? flush_eval_rst : flush_eval;
    r_e_pend <= (srst && !ss_we) ? e_pend_rst : e_pend;
    r_rq_n <= (srst && !ss_we) ? rq_n_rst : rq_n;
    r_slot_busy <= (srst && !ss_we) ? slot_busy_rst : slot_busy;
    r_slot_accept <= (srst && !ss_we) ? slot_accept_rst : slot_accept;
    r_opr_held <= (srst && !ss_we) ? opr_held_rst : opr_held;
    r_rd_first_hi <= (srst && !ss_we) ? rd_first_hi_rst : rd_first_hi;
    r_rd_was_split <= (srst && !ss_we) ? rd_was_split_rst : rd_was_split;
    r_done_ctr <= (srst && !ss_we) ? done_ctr_rst : done_ctr;
    r_done_wr <= (srst && !ss_we) ? done_wr_rst : done_wr;
    r_rd_done_p <= (srst && !ss_we) ? rd_done_p_rst : rd_done_p;
    r_wr_done_p <= (srst && !ss_we) ? wr_done_p_rst : wr_done_p;
    r_opr_free_p <= (srst && !ss_we) ? opr_free_p_rst : opr_free_p;
    r_rd_val <= (srst && !ss_we) ? rd_val_rst : rd_val;
    r_rd_land <= (srst && !ss_we) ? rd_land_rst : rd_land;
    r_ready_prev <= (srst && !ss_we) ? ready_prev_rst : ready_prev;
    for (rj = 0; rj < 6; rj = rj + 1)
        r_q_mem[rj] <= (srst && !ss_we) ? q_mem_rst[rj] : q_mem[rj];
    for (rj = 0; rj < 2; rj = rj + 1) begin
        r_rq_bs[rj] <= (srst && !ss_we) ? rq_bs_rst[rj] : rq_bs[rj];
        r_rq_addr[rj] <= (srst && !ss_we) ? rq_addr_rst[rj] : rq_addr[rj];
        r_rq_data[rj] <= (srst && !ss_we) ? rq_data_rst[rj] : rq_data[rj];
        r_rq_ube[rj] <= (srst && !ss_we) ? rq_ube_rst[rj] : rq_ube[rj];
        r_rq_odd[rj] <= (srst && !ss_we) ? rq_odd_rst[rj] : rq_odd[rj];
        r_rq_seg[rj] <= (srst && !ss_we) ? rq_seg_rst[rj] : rq_seg[rj];
        r_rq_noaddr[rj] <= (srst && !ss_we) ? rq_noaddr_rst[rj] : rq_noaddr[rj];
        r_rq_wr[rj] <= (srst && !ss_we) ? rq_wr_rst[rj] : rq_wr[rj];
        r_rq_need[rj] <= (srst && !ss_we) ? rq_need_rst[rj] : rq_need[rj];
        r_rq_last[rj] <= (srst && !ss_we) ? rq_last_rst[rj] : rq_last[rj];
        r_rq_late[rj] <= (srst && !ss_we) ? rq_late_rst[rj] : rq_late[rj];
        r_rq_ghost[rj] <= (srst && !ss_we) ? rq_ghost_rst[rj] : rq_ghost[rj];
    end
    r_cmt_ghost <= (srst && !ss_we) ? cmt_ghost_rst : cmt_ghost;
    r_g_sp <= (srst && !ss_we) ? g_sp_rst : g_sp;
    r_g_bare <= (srst && !ss_we) ? g_bare_rst : g_bare;
    r_g_age <= (srst && !ss_we) ? g_age_rst : g_age;
    r_g_row_q <= (srst && !ss_we) ? g_row_q_rst : g_row_q;
end

`ifndef JTV30_SYNTHESIS
// The module's contracts, checked on the REGISTERED state -- the always_comb
// above settles more than once per clock, so an immediate assertion inside it
// would report transients (campaign risk #2 kept, instrument fixed).
//
// U2 pass 5 -- ...AND THEY ARE `assert ... else $error`, NOT A BARE `$error`.
// The save-state sweep (`--ss-sweep`, SS1) SCRAMBLES the whole stream with an
// LFSR before restoring it, and quiesces the design's contracts for that
// window with `$assertoff(0)` (tb_v30_core `ss_asserts_off`).  `$assertoff`
// governs ASSERTIONS; a bare `if (...) $error(...)` is an ordinary statement
// and is not quiesced, so every one of these fired on the scrambled state and
// took the run down -- which is the whole of the `--ss-sweep` failure booked
// in ledger 35.2 as "pre-existing".  It was never a design fault: it is the
// instrument, and `v30_biu.sv`'s class-5 block already had the right form.
always_ff @(posedge clk) if (!srst) begin
    assert (!(ce && eu_post && (r_rq_n == 2'd2)))
        else $error("v30u_biu: post dropped, request store full");
    assert (!(ce && eu_post && eu_split && (r_rq_n != 2'd0)))
        else $error("v30u_biu: split posted onto a non-empty request store");
    // ...and the HALT pseudo-cycle is EXEMPT, by M21's own arithmetic: its
    // status release sits at index 1 while its T4 is at `3 + waits`, so `sev`
    // legitimately reaches 3 at any wait level above zero.  The bound was
    // derived for cycles whose eval is at `last_i` or `last_i - 1` and it is
    // still asserted for every one of those.  MEASURED, and it is the whole of
    // `HLT.INT` / `HLT.RES` "SIM FAILED" at w1 and w3 -- the first time a woken
    // HALT was ever run under waits.  `sev`'s only consumer saturates anyway
    // (`land_ttl` is 0 for `sev_now >= 2`).
    assert (!(r_run && r_evald && !r_cur_halt && (r_sev > 2'd2)))
        else $error("v30u_biu: sev bound violated (%0d)", r_sev);
    assert (!(r_cmt_valid && (r_cdage == 3'd7)))
        else $error("v30u_biu: announcement age saturated");
    assert (r_q_cnt <= 4'd6)
        else $error("v30u_biu: queue overflow (%0d)", r_q_cnt);
    assert (!((r_grn_ttl != 2'd0) && ({2'd0, r_grn_n} > r_q_cnt)))
        else $error("v30u_biu: green byte count exceeds queue");
end
`endif


//----------------------------------------------------------------------------
// save-state READ mux (arm #2 of the exactly-twice discipline)
//----------------------------------------------------------------------------
always @(posedge clk) begin
    case (ss_addr)
        SSA_B_RUN:          ss_rdata <= {15'b0, r_run};
        SSA_B_TS:           ss_rdata <= {13'b0, r_ts};
        SSA_B_CUR_BS:       ss_rdata <= {13'b0, r_cur_bs};
        SSA_B_CUR_ADDR_LO:  ss_rdata <= r_cur_addr[15:0];
        SSA_B_CUR_ADDR_HI:  ss_rdata <= {12'b0, r_cur_addr[19:16]};
        SSA_B_CUR_DATA:     ss_rdata <= r_cur_data;
        SSA_B_CUR_UBE_N:    ss_rdata <= {15'b0, r_cur_ube_n};
        SSA_B_CUR_SEG:      ss_rdata <= {14'b0, r_cur_seg};
        SSA_B_CUR_FETCH:    ss_rdata <= {15'b0, r_cur_fetch};
        SSA_B_CUR_HALT:     ss_rdata <= {15'b0, r_cur_halt};
        SSA_B_CUR_NOADDR:   ss_rdata <= {15'b0, r_cur_noaddr};
        SSA_B_CUR_WR:       ss_rdata <= {15'b0, r_cur_wr};
        SSA_B_CUR_NEED:     ss_rdata <= {15'b0, r_cur_need};
        SSA_B_CUR_RDLAST:   ss_rdata <= {15'b0, r_cur_rd_last};
        SSA_B_CUR_PN:       ss_rdata <= {14'b0, r_cur_pn};
        SSA_B_CUR_LATET1:   ss_rdata <= {15'b0, r_cur_late_t1};
        SSA_B_EVALD:        ss_rdata <= {15'b0, r_evald};
        SSA_B_SEV:          ss_rdata <= {14'b0, r_sev};
        SSA_B_DAGE:         ss_rdata <= {13'b0, r_dage};
        SSA_B_CMT_VALID:    ss_rdata <= {15'b0, r_cmt_valid};
        SSA_B_CMT_BS:       ss_rdata <= {13'b0, r_cmt_bs};
        SSA_B_CMT_ADDR_LO:  ss_rdata <= r_cmt_addr[15:0];
        SSA_B_CMT_ADDR_HI:  ss_rdata <= {12'b0, r_cmt_addr[19:16]};
        SSA_B_CMT_DATA:     ss_rdata <= r_cmt_data;
        SSA_B_CMT_UBE_N:    ss_rdata <= {15'b0, r_cmt_ube_n};
        SSA_B_CMT_SEG:      ss_rdata <= {14'b0, r_cmt_seg};
        SSA_B_CMT_FETCH:    ss_rdata <= {15'b0, r_cmt_fetch};
        SSA_B_CMT_HALT:     ss_rdata <= {15'b0, r_cmt_halt};
        SSA_B_CMT_NOADDR:   ss_rdata <= {15'b0, r_cmt_noaddr};
        SSA_B_CMT_WR:       ss_rdata <= {15'b0, r_cmt_wr};
        SSA_B_CMT_NEED:     ss_rdata <= {15'b0, r_cmt_need};
        SSA_B_CMT_RDLAST:   ss_rdata <= {15'b0, r_cmt_rd_last};
        SSA_B_CMT_PN:       ss_rdata <= {14'b0, r_cmt_pn};
        SSA_B_CDAGE:        ss_rdata <= {13'b0, r_cdage};
        SSA_B_CMT_PREV_FP:  ss_rdata <= r_cmt_prev_fp;
        SSA_B_CMT_WAS_OWED: ss_rdata <= {15'b0, r_cmt_was_owed};
        SSA_B_LAST_UBE:     ss_rdata <= {15'b0, last_ube};
        SSA_B_LAST_FADDR:   ss_rdata <= r_last_fetch_addr;
        SSA_B_Q0:           ss_rdata <= {8'b0, r_q_mem[0]};
        SSA_B_Q1:           ss_rdata <= {8'b0, r_q_mem[1]};
        SSA_B_Q2:           ss_rdata <= {8'b0, r_q_mem[2]};
        SSA_B_Q3:           ss_rdata <= {8'b0, r_q_mem[3]};
        SSA_B_Q4:           ss_rdata <= {8'b0, r_q_mem[4]};
        SSA_B_Q5:           ss_rdata <= {8'b0, r_q_mem[5]};
        SSA_B_Q_HEAD:       ss_rdata <= {13'b0, r_q_head};
        SSA_B_Q_CNT:        ss_rdata <= {12'b0, r_q_cnt};
        SSA_B_GRN_N:        ss_rdata <= {14'b0, r_grn_n};
        SSA_B_GRN_TTL:      ss_rdata <= {14'b0, r_grn_ttl};
        SSA_B_FETCH_PTR:    ss_rdata <= r_fetch_ptr;
        SSA_B_CS:           ss_rdata <= r_cs_r;
        SSA_B_SUSPENDED:    ss_rdata <= {15'b0, r_suspended};
        SSA_B_HALTED:       ss_rdata <= {15'b0, r_halted};
        SSA_B_HALT_PEND:    ss_rdata <= {15'b0, r_halt_pending};
        SSA_B_PF_OWED:      ss_rdata <= {15'b0, r_pf_owed};
        SSA_B_PF_ARM:       ss_rdata <= {15'b0, r_pf_arm};
        SSA_B_INFL_TTL:     ss_rdata <= {14'b0, r_infl_ttl};
        SSA_B_INFL_N:       ss_rdata <= {14'b0, r_infl_n};
        SSA_B_ABSORB_TTL:   ss_rdata <= {14'b0, r_absorb_ttl};
        SSA_B_NO_EVAL:      ss_rdata <= {15'b0, r_no_eval};
        SSA_B_FLUSH_EVAL:   ss_rdata <= {15'b0, r_flush_eval};
        SSA_B_E_PEND:       ss_rdata <= {15'b0, r_e_pend};
        SSA_B_RQ_N:         ss_rdata <= {14'b0, r_rq_n};
        SSA_B_RQ0_BS:       ss_rdata <= {13'b0, r_rq_bs[0]};
        SSA_B_RQ0_ADDR_LO:  ss_rdata <= r_rq_addr[0][15:0];
        SSA_B_RQ0_ADDR_HI:  ss_rdata <= {12'b0, r_rq_addr[0][19:16]};
        SSA_B_RQ0_DATA:     ss_rdata <= r_rq_data[0];
        SSA_B_RQ0_UBE:      ss_rdata <= {15'b0, r_rq_ube[0]};
        SSA_B_RQ0_SEG:      ss_rdata <= {14'b0, r_rq_seg[0]};
        SSA_B_RQ0_NOADDR:   ss_rdata <= {15'b0, r_rq_noaddr[0]};
        SSA_B_RQ0_WR:       ss_rdata <= {15'b0, r_rq_wr[0]};
        SSA_B_RQ0_NEED:     ss_rdata <= {15'b0, r_rq_need[0]};
        SSA_B_RQ0_LAST:     ss_rdata <= {15'b0, r_rq_last[0]};
        SSA_B_RQ1_BS:       ss_rdata <= {13'b0, r_rq_bs[1]};
        SSA_B_RQ1_ADDR_LO:  ss_rdata <= r_rq_addr[1][15:0];
        SSA_B_RQ1_ADDR_HI:  ss_rdata <= {12'b0, r_rq_addr[1][19:16]};
        SSA_B_RQ1_DATA:     ss_rdata <= r_rq_data[1];
        SSA_B_RQ1_UBE:      ss_rdata <= {15'b0, r_rq_ube[1]};
        SSA_B_RQ1_SEG:      ss_rdata <= {14'b0, r_rq_seg[1]};
        SSA_B_RQ1_NOADDR:   ss_rdata <= {15'b0, r_rq_noaddr[1]};
        SSA_B_RQ1_WR:       ss_rdata <= {15'b0, r_rq_wr[1]};
        SSA_B_RQ1_NEED:     ss_rdata <= {15'b0, r_rq_need[1]};
        SSA_B_RQ1_LAST:     ss_rdata <= {15'b0, r_rq_last[1]};
        SSA_B_RQ_LATE:      ss_rdata <= {14'b0, r_rq_late[1], r_rq_late[0]};
        SSA_B_SLOT_BUSY:    ss_rdata <= {15'b0, r_slot_busy};
        SSA_B_SLOT_ACC:     ss_rdata <= {15'b0, r_slot_accept};
        SSA_B_OPR_HELD:     ss_rdata <= {14'b0, r_opr_held};
        SSA_B_RD_FIRST_HI:  ss_rdata <= {8'b0, r_rd_first_hi};
        SSA_B_RD_WAS_SPLIT: ss_rdata <= {15'b0, r_rd_was_split};
        SSA_B_CUR_ODD:      ss_rdata <= {15'b0, r_cur_odd};      // F49
        SSA_B_CMT_ODD:      ss_rdata <= {15'b0, r_cmt_odd};      // F49
        SSA_B_RQ0_ODD:      ss_rdata <= {15'b0, r_rq_odd[0]};    // F49
        SSA_B_RQ1_ODD:      ss_rdata <= {15'b0, r_rq_odd[1]};    // F49
        SSA_B_RD_LAND:      ss_rdata <= r_rd_land;               // F49
        SSA_B_DONE_CTR:     ss_rdata <= {14'b0, r_done_ctr};
        SSA_B_DONE_WR:      ss_rdata <= {15'b0, r_done_wr};
        SSA_B_RD_DONE_P:    ss_rdata <= {15'b0, r_rd_done_p};
        SSA_B_WR_DONE_P:    ss_rdata <= {15'b0, r_wr_done_p};
        SSA_B_OPR_FREE_P:   ss_rdata <= {15'b0, r_opr_free_p};
        SSA_B_RD_VAL:       ss_rdata <= r_rd_val;
        SSA_B_READY_PREV:   ss_rdata <= {15'b0, r_ready_prev};
`ifdef V30_MUXED_AD
        SSA_B_T1_HALF2:     ss_rdata <= {15'b0, t1_half2};
`endif
        // ⚠ WITHOUT `V30_MUXED_AD` THE FLOP DOES NOT EXIST, this address falls
        // to `default` and reads 0, and a de-muxed build is therefore a
        // DIFFERENT SAVE-STATE STREAM by construction.  It is not
        // stream-compatible with the rig's and must not be loaded into one.
        // `SS_VERSION` is deliberately NOT bumped: the map is unchanged in the
        // configuration that has the flop, which is the one every gate scores.
        SSA_B_LAST_AD_HI:   ss_rdata <= {12'b0, last_ad_hi};
        SSA_B_LAST_AD_LO:   ss_rdata <= last_ad_lo;
        SSA_B_GHOST_SP_LO:  ss_rdata <= r_g_sp[15:0];
        SSA_B_GHOST_SP_HI:  ss_rdata <= {12'b0, r_g_sp[19:16]};
        SSA_B_GHOST_BARE_LO:ss_rdata <= r_g_bare[15:0];
        SSA_B_GHOST_BARE_HI:ss_rdata <= {12'b0, r_g_bare[19:16]};
        SSA_B_GHOST_AGE:    ss_rdata <= {14'b0, r_g_age};
        SSA_B_GHOST_TAG:    ss_rdata <= {12'b0, r_g_row_q, r_cmt_ghost,
                                         r_rq_ghost[1], r_rq_ghost[0]};
        default:            ss_rdata <= 16'h0000;
    endcase
end

// `last_ube` is pad retention, not a decision: it tracks the pin.
always @(posedge clk) begin
    if (ss_we && ss_addr == SSA_B_LAST_UBE) last_ube <= ss_wdata[0];
    // begin_case() leaves the retained pin at 0, not 1: `last_ube_` is
    // pad retention of an undriven output, and the model's own initial
    // value is what the comparator stack's idle rows carry.
    else if (srst) last_ube <= 1'b0;
    else if (ce)   last_ube <= ube_n;
end

// THE AD OUTPUT LATCH.
//
// ⚠ 2026-08-14, AND IT IS WHY THE MULTIPLEXED VIEW IS COMPUTED IN EVERY
// CONFIGURATION: this latch has a FUNCTIONAL CONSUMER.  Its two registers feed
// `cmt_addr`/`cmt_data` of the HALT pseudo-cycle's announcement in step (e),
// so the shared-pad drive is MACHINE STATE and not presentation, and a core
// that presented a de-muxed bus while dropping it would be a different machine
// from the one silicon measured.  `V30_MUXED_AD` therefore removes the PORTS
// (`ad_o`/`ad_oe_*` here, `AD`/`AD_OE` on the top) and NOT this.  The de-muxed
// build still computes what the core would drive on the shared pads; it simply
// does not have any.
//
// F58 -- THE HALT PSEUDO-CYCLE ANNOUNCES NOTHING OF ITS OWN.
//
// `last_ad_*` is the AD OUTPUT LATCH, split into exactly the two lanes the two
// output enables already split it into: A19-16 is loaded whenever the core
// drives A19-16 (`ad_oe_addr || ad_oe_ps`) and AD15-0 whenever it drives
// AD15-0 (`ad_oe_addr || ad_oe_data`).  It is pad retention on the DRIVE side,
// the same sentence as `last_ube` above one bus over, and it stores nothing
// the die does not already have to have.
//
// WHAT IT IS FOR.  The HALT display used to publish
// `{data_ps(2'd2), last_fetch_addr}` -- a value of its own, sourced from the
// prefetcher.  MEASURED on silicon, 1,189 HALT pseudo-cycles over the 725
// retained fz2 captures, chip leg only: the HALT publishes the value the AD
// output latch ALREADY HOLDS, on both lanes, 1,189 of 1,189 with no exception.
// The two rules agree exactly when the last bus cycle before the HALT was a
// CODE fetch -- because then the last value the core drove on AD15-0 IS the
// last fetch address -- and that is 1,164 of the 1,189, which is why the HLT
// sweeps, whose program is the one byte `F4`, cannot tell them apart and why
// this stood for the whole ucore campaign.  The 25 sites where the last cycle
// was a data cycle (MEMW 12, MEMR 9, IOW 4) are exactly the 25 HALT displays
// of the 24 `B1` seeds in the fuzz-v2 failure ledger, with nothing left over.
//
// It is NOT F55, which is landed and is not disturbed here: F55 is about who
// holds the pads for the BODY of the pseudo-cycle (nobody -- all three enables
// are low and the pads retain), and this is about the value published in the
// pseudo-cycle's own ADDRESS PHASE, which the core does drive and silicon does
// drive with it.
//
// Falsifier: a capture whose HALT display or HALT T1 carries a value the core
// had not itself last driven on that lane -- in particular any HALT whose
// AD15-0 is the DATA of a preceding READ (which the memory drove, not the
// core), or whose A19-16 is not the preceding cycle's segment status.
// Second falsifier, on the RENDERING rather than the law: this latch is read
// by the display decision from its REGISTERED value, so a HALT display whose
// immediately preceding clock is the only clock of a WITHDRAWN announcement
// would publish one announcement too far back.  No such site exists in the
// 1,189; if one is ever captured, the read has to move, not the law.
always @(posedge clk) begin
    if (ss_we && ss_addr == SSA_B_LAST_AD_HI) last_ad_hi <= ss_wdata[3:0];
    // THE RESET VALUE IS THE PRE-WINDOW WALK'S, NOT ZERO.  A golden whose
    // capture window OPENS on a HALT has no in-window cycle to have driven the
    // pads, and S9a's backdoor preload already reconstructs the pre-window
    // state for exactly this reason (`last_fetch_addr_rst`).  Seeding these two
    // lanes from it makes the window's first clock carry what the part carried
    // into it.  The walk models FETCHES, which is the case in which the old
    // rule and this one agree (prereg sec.1.2), so the seed is the old
    // behaviour exactly and only the in-window evolution is new.
    // MEASURED: without this, `check_core --opcodes all` reads 168,858/169,000
    // -- HLT.INT 150/200, HLT.NMI 155/200, HLT.RES 153/200, every one of the
    // 142 first diverging at ROW 1 on `bus`, with arch 200/200 throughout.
    else if (srst) last_ad_hi <= data_ps(2'd2);
    else if (ce && (ad_oe_addr || ad_oe_ps)) last_ad_hi <= ad_o[19:16];
end
always @(posedge clk) begin
    if (ss_we && ss_addr == SSA_B_LAST_AD_LO) last_ad_lo <= ss_wdata;
    else if (srst) last_ad_lo <= last_fetch_addr_rst;   // see LAST_AD_HI above
    else if (ce && (ad_oe_addr || ad_oe_data)) last_ad_lo <= ad_o[15:0];
end

//----------------------------------------------------------------------------
// `+utrace` -- THE ATTRIBUTION CHANNEL (verification only, ucore stage U1).
//
// The campaign's ranked risk #1 is the pumped-clock inversion: the model
// STALLS by ticking inside `pop()` / `post()` / `wait_*()`, while the RTL
// stalls by NOT firing a condition.  When a lockstep run diverges, the row
// stream says WHEN and this says WHY -- one `u` row per clock naming the
// eval-instant terms and the QS-port arbiter's inputs, next to the model's own
// V30SIM_EVALTRACE `ET` / `QT` lines.  Guarded out of synthesis, and gated on
// the plusarg so a normal run is byte-identical without it.
//----------------------------------------------------------------------------
`ifndef JTV30_SYNTHESIS
logic utrace_en;
integer utrace_clk;
initial begin
    utrace_en = $test$plusargs("utrace");
    utrace_clk = 0;
end
always @(posedge clk) begin
    if (srst) utrace_clk <= 0;
    else if (ce) begin
        if (utrace_en)
            // clk | eval/QS strobes | the terms that gate them
            /* verilator lint_off WIDTHEXPAND */
            $display("u %0d ts=%0d run=%0d dage=%0d rdyp=%0d ev=%0d evald=%0d sev=%0d cmt=%0d cdage=%0d fetch=%0d ca=%05x cd=%04x pn=%0d occ=%0d arm=%0d infl=%0d absorb=%0d grn=%0d,%0d q=%0d owed=%0d susp=%0d halt=%0d ne=%0d fe=%0d epend=%0d qse=%0d pop=%0d rq=%0d lfa=%04x",
                     utrace_clk, ts, run, dage, ready_prev, eval_inst,
                     evald, sev, cmt_valid, cdage, cur_fetch, cur_addr, cur_data,
                     cur_pn,
                     q_cnt + ((run && cur_fetch) ? {2'b0, cur_pn} : 4'd0)
                           + ((cmt_valid && cmt_fetch) ? {2'b0, cmt_pn} : 4'd0)
                           + ((infl_ttl != 2'd0) ? {2'b0, infl_n} : 4'd0),
                     pf_arm, infl_ttl, absorb_ttl, grn_n,
                     grn_ttl, q_cnt, pf_owed, suspended, halted,
                     no_eval, flush_eval, e_pend, qs_e_now, pop_now, rq_n,
                     last_fetch_addr);
            /* verilator lint_on WIDTHEXPAND */
        utrace_clk <= utrace_clk + 1;
    end
end

//----------------------------------------------------------------------------
// `+padtrace` -- THE PAD-DRIVE ATTRIBUTION.  The TB composes the observed AD
// from a PROTOCOL-INFERRED drive mask (float retention), so what the module
// actually drives on a clock the protocol calls "inside a HALT cycle" is not
// visible in the `r` stream at all.  The HLT-sweep residue is exactly that
// question, so the terms get their own line: one row per clock naming the
// three pad enables and the value on `ad_o`, next to the `u` line's eval
// terms.  Guarded out of synthesis and gated on the plusarg.
//----------------------------------------------------------------------------
logic padtrace_en;
integer padtrace_clk;
initial begin
    padtrace_en = $test$plusargs("padtrace");
    padtrace_clk = 0;
end
always @(posedge clk) begin
    if (srst) padtrace_clk <= 0;
    else if (ce) begin
        if (padtrace_en)
            $display("P %0d ad=%05x oe_addr=%0d oe_ps=%0d oe_data=%0d disp=%0d strel=%0d haltaddr=%0d curhalt=%0d ts=%0d bs=%0d cmtaddr=%05x",
                     padtrace_clk, ad_o, ad_oe_addr, ad_oe_ps, ad_oe_data,
                     display, st_rel, halt_addr, r_cur_halt, r_ts, bs,
                     r_cmt_addr);
        padtrace_clk <= padtrace_clk + 1;
    end
end
`endif

wire _unused = &{1'b0, eu_word, ad_i[15:0], bkd_queue[47:0]};

endmodule
