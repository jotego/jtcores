`ifdef SYNTHESIS
`define JTV30_SYNTHESIS
`elsif ALTERA_RESERVED_QIS
`define JTV30_SYNTHESIS
`endif

// SPDX-FileCopyrightText: 2026 Andrea Bogazzi
// Date: 18-10-2026
//============================================================================
//
//  v30u_eu - the ucore execution unit: micro-sequencer, loader march,
//            datapath and ALU.
//
//  THIS MODULE IS A TRANSLITERATION OF sim/exec_impl.h + sim/loader_impl.h +
//  sim/alu.cpp.  The governance rule (hdl/rtl/ucore/README.md) is that the
//  model is the SPEC: an RTL-vs-sim divergence is a bug HERE.
//
//  --- THE INVERSION (campaign risk #1) -------------------------------------
//
//  The model PUMPS the clock: the interpreter calls `charge(n)` / `pop()` /
//  `wait_read()` and the BIU ticks underneath it.  The RTL cannot do that, so
//  the interpreter is re-expressed as a state machine whose state is
//  "the step of the model's program that occupies THIS clock":
//
//    * every port the BIU samples (`q_pop`, `eu_post`, `eu_pair`, `q_flush`,
//      `eu_susp`, `eu_halt`) is a COMBINATIONAL function of EU REGISTERS ONLY
//      -- the state, the micro-row word standing on `upc`, and the datapath.
//      The model makes those acts "at clk_ == c, before tick(c)"; the RTL BIU
//      consumes them in its step (b) at the edge ending c.  Same instant.
//    * `charge(n)` becomes "this state occupies n clocks".
//    * every `while (...) tick()` becomes a STALL: the state is re-entered
//      and its acts are withheld.  There are five, and they are named:
//
//        stall_q       a queue byte is demanded and not ripe        (M8)
//        stall_opr     the F / OPR interlock                        (11.4/M13)
//        stall_slot    the EU's ONE bus-request slot is busy        (M10)
//        stall_retire  the retire deadline: a store owes its data   (7.7)
//        stall_pin     the 1BL retire lead / a halted part          (S9a)
//
//    * a model step that charges NOTHING (consuming a pre-popped opcode, the
//      pure-decode logic) is a ZERO-COST state: it is executed inside the same
//      edge that computed it, by the bounded chain loop below.  The loop is
//      how "several model steps ride one clock" is expressed.
//
//  --- THE SEQUENCER --------------------------------------------------------
//
//  upc = {page[2:0], opc[7:0], loc[3:0]}, 15 bits (U0 finding F1), and it is
//  the architectural SS-mapped flop: the two tables stand combinationally on
//  it (see v30u_ucrom.sv), so a restore has no hidden BRAM-address state.
//  `loc` is a 4-bit counter inside the opcode's 16-row block and CARRIES into
//  the opcode byte (ledger: IMUL 00B3 -> 0218).
//
//  --- CE DISCIPLINE --------------------------------------------------------
//
//  Nothing clocked runs unless `srst` or `ce`; reset is ungated so `bkd_load`
//  fires regardless of CE.  There is no negedge process in the EU.
//
//  U4 pass 3 -- WHERE `ce` IS.  The module is a NEXT-STATE FUNCTION
//  (`always @*`, producing `<reg>_n`) plus a REGISTER BANK
//  (`always_ff @(posedge clk) if (ss_we || srst || ce)`).  `ce` appears in the
//  commit and NOWHERE ELSE, which is the whole reason for the shape: written
//  the other way -- one clocked block whose third arm was `else if (ce)` --
//  Quartus extracted no clock enable, threaded `ce` through the EU's 61-level
//  cone to every flip-flop's DATA input, clocked the registers every SYS clock
//  and made the multicycle exception the divided CPU clock earns FALSE
//  (ledger sec.51.7).  The behaviour is identical either way and the full ladder
//  was re-scored to say so; the NETLIST is not.
//
//============================================================================

module v30u_eu #(
`ifdef JTV30_SYNTHESIS
    parameter string HEXDIR = "rtl/ucore/"
`else
    parameter string HEXDIR = "hdl/rtl/ucore/"
`endif
) (
    input             clk,
    input             ce,
    // THE PHASE SPLIT (WAVE 2, 2026-09-08): the CPU clock's half-cycle enable,
    // which is where STAGE 1 of the next-state cone is captured.  See THE PHASE
    // SPLIT below.  It is an UNCONDITIONAL port of `v30_core` for this reason
    // -- `V30_MUXED_AD` governs the bus shape, and this is core clocking.
    input             ce_half,
    input             srst,

    // queue port
    input       [7:0] q_byte,
    input             q_ripe,
    input             q_ripe_lead_n0, // ...ripe NEXT clock if NO pop
    input             q_ripe_lead_n1, // ...and if this clock's own pop happens
    input       [3:0] q_cnt,
    output            q_pop,
    output            q_first,
    output            q_flush,
    output            flush_pre,
    output            flush_rep,
    output            flush_stage,
    output            flush_pend,
    output            flush_nmi,
    output            flush_int_live,
    output     [15:0] flush_cs,
    output     [15:0] flush_cs_old,
    output            flush_cs_we,
    output     [15:0] flush_ip,

    // bus requests
    output            eu_post,
    output            eu_post_hold,
    output            eu_halt_irq,
    output            eu_vector_post,
    output      [2:0] eu_bs,
    output     [19:0] eu_addr,
    output     [19:0] eu_addr2,     // split: the second cycle's own address
    output            eu_split,
    output      [1:0] eu_seg,
    output      [1:0] eu_seg2,
    output            eu_word,
    // THE 8F GHOST READ IS DECORATED AT **LAUNCH**, NOT AT POST.  The EU
    // publishes the two DRIVERS' own composed addresses and the fact that its
    // micro-row is standing; the BIU ages that and picks at the T1.  See the
    // block at `ghost_bus_off` below and `v30u_biu.sv`'s `g_age`.
    output            eu_ghost_row,   // the ghost read's micro-row is current
    output            eu_ghost_acc,   // ...and THIS clock's access is its own
    output     [19:0] eu_ghost_sp,    // driver 1: SS:SP, the row's stack drive
    output     [19:0] eu_ghost_bare,  // driver 2: SS:stale, the retained rail
    input             eu_slot_busy,
    input             eu_slot_busy_n,
    input             eu_access_active,
    input             eu_direct_fetch,
    input             eu_fetch_tail,
    input             eu_ghost_full,
    input             eu_ghost_idle,
    input             eu_ghost_stack_first,
    output            eu_pair,
    output            eu_pair2,     // the pairing fills TWO reserved cycles
    output     [15:0] eu_wdata,
    input      [15:0] eu_rdata_n,
    input             eu_rd_done_n,
    input             eu_rd_edge,   // the read's DATA EDGE (T3/Tw -> T4)
    input      [15:0] eu_rd_edge_d,
    input             eu_wr_done_n,
    input             eu_wr_eval,
    input             eu_opr_free,   // F31: the LEVEL `opr_held == 0`

    // prefetch control
    output            eu_susp,
    output            eu_resume,
    output            eu_halt,
    output            eu_unhalt,
    // F43 (SM3 sitting 6): the SAME wake, tapped ONE STAGE further down the
    // SAME pin pipeline, for the reader whose decision edge leads its own
    // clock -- the BIU's HALT display.  No new state: `int_p[1]` against
    // `int_p[2]`, exactly as `irq_rep_chn` reads a chained REP boundary
    // against `irq_rep_1st`.
    output            eu_unhalt_disp,
    input             halted,

    // SM3 sitting 11: what is left of H1's recognition floor.  The floor
    // itself is now one term on this module's own IE gate and holds no state;
    // these two lines carry the PREFETCHER SUSPEND that rides it.
    output            eu_bnd_take,  // a recognition boundary IS taken this clock
    output            eu_bnd_post,  // ...it is a retire, and the IE gate HELD it

    // machine state the pins carry
    output            psw_ie,
    output            md8080,

    // pins
    input             pin_int,
    input             pin_nmi,
    input             pin_poll_n,

    // backdoor
    input             bkd_load,
    input     [223:0] bkd_regs,
    output    [223:0] dbg_regs,
    output            dbg_first_pop,
    output            dbg_pend,

    // save-state
    input       [8:0] ss_addr,
    input      [15:0] ss_wdata,
    input             ss_we,
    output reg [15:0] ss_rdata
);

import v30_ss_pkg::*;

`include "pla3_tables.svh"

//============================================================================
// ENCODINGS
//============================================================================

// rows.h bus-status encodings -- the comparator stack's own
localparam bit [2:0] BS_INTA = 3'd0, BS_IOR = 3'd1, BS_IOW = 3'd2,
                     BS_MEMR = 3'd5, BS_MEMW = 3'd6, BS_PASV = 3'd7;

// sim/state.h register indices == the microcode Source1/Dest1 field values
localparam bit [2:0] R_AW = 3'd0, R_CW = 3'd1, R_DW = 3'd2, R_BW = 3'd3,
                     R_SP = 3'd4, R_BP = 3'd5, R_IX = 3'd6, R_IY = 3'd7;
localparam bit [1:0] SR_ES = 2'd0, SR_CS = 2'd1, SR_SS = 2'd2, SR_DS = 2'd3;
localparam bit [2:0] SEG_ZERO = 3'd4;   // physical == offset (vector fetch)

// OperandRef::Kind
localparam bit [1:0] OK_NONE = 2'd0, OK_REG = 2'd1, OK_SREG = 2'd2,
                     OK_MEM = 2'd3;

// sim/state.h PSW bits
localparam int FCY = 0, FP = 2, FAC = 4, FZ = 6, FS = 7,
               FBRK = 8, FIE = 9, FDIR = 10, FV = 11;
localparam bit [15:0] PSW_WRITABLE = 16'h0FD5;
localparam bit [15:0] PSW_FORCED   = 16'hF002;
localparam bit [15:0] ARITH_MASK   = 16'h0000 | (16'd1 << FCY) | (16'd1 << FP)
                                   | (16'd1 << FAC) | (16'd1 << FZ)
                                   | (16'd1 << FS) | (16'd1 << FV);

// sim/state.h AluOp
localparam bit [4:0] A_ADD=5'h00, A_OR=5'h01, A_ADC=5'h02, A_SBB=5'h03,
                     A_AND=5'h04, A_SUB=5'h05, A_XOR=5'h06, A_CMP=5'h07,
                     A_ROL=5'h08, A_ROR=5'h09, A_RCL=5'h0A, A_RCR=5'h0B,
                     A_SHL=5'h0C, A_SHR=5'h0D, A_SHL6=5'h0E, A_SAR=5'h0F,
                     A_ROL12=5'h10, A_DIV=5'h12, A_MUL=5'h13, A_ADJD=5'h14,
                     A_ADJA=5'h15, A_OPC=5'h16, A_BIT=5'h17,
                     A_INC=5'h18, A_DEC=5'h19, A_NOT=5'h1A, A_NEG=5'h1B,
                     A_INC2=5'h1C, A_DEC2=5'h1D, A_ABS=5'h1E, A_PASS=5'h1F;

// ucrom.h MicroType
localparam bit [1:0] TY_ALU = 2'd0, TY_JMP = 2'd1, TY_CTL = 2'd2;

// exec_impl.h Cond
localparam bit [3:0] C_C=4'd0, C_NC=4'd1, C_Z=4'd2, C_NZ=4'd3, C_OP8B=4'd4,
                     C_CNTZ=4'd5, C_L=4'd6, C_OP8=4'd7, C_ALWAYS=4'd8,
                     C_SIGN=4'd9, C_O=4'd10, C_NS=4'd11, C_REP=4'd12,
                     C_BUSY=4'd13, C_INTR=4'd14, C_OPC=4'd15;

// exec_impl.h Ictl / Ectl
localparam bit [3:0] I_ENDEM=4'd0, I_CITF=4'd1, I_MFC=4'd2, I_MFS=4'd3,
                     I_BCDINIT=4'd4, I_CLRCYV=4'd6, I_SETCYV=4'd7, I_SUSP=4'd8,
                     I_FLUSH=4'd9, I_SIGNTGL=4'd12, I_BCDNZ=4'd13,
                     I_FARJMP=4'd14;
localparam bit [2:0] E_MEMR=3'd1, E_MEMW=3'd2, E_INTATAIL=3'd3, E_INTA=3'd5,
                     E_WRITEBACK=3'd6;

// RepKind / RepTest
localparam bit [2:0] REP_NONE=3'd0, REP_E=3'd1, REP_NE=3'd2, REP_C=3'd3,
                     REP_NC=3'd4;
localparam bit [1:0] TEST_NONE=2'd0, TEST_Z=2'd1, TEST_CY=2'd2;

//============================================================================
// STATE
//============================================================================

// --- the architectural file ------------------------------------------------
reg [15:0] gpr [0:7];
reg [15:0] sreg [0:3];
reg [15:0] pc;
reg [15:0] psw;
reg [15:0] tmpa, tmpb, tmpc;
// The EA adder's TWO RAILS are retained beside the microcode tmp registers.
// Only undocumented register-form LEA observes them -- `8D` at mod == 3
// issues no EA calculation of its own, so its row-1 SIGMA -> R transfer adds
// whatever the address adder was last given.
//
// THE A RAIL.  An EA calculation loads it with the FIRST addend, and ordinary
// tmpa writes refresh it afterwards -- so by the time a following LEA reads
// it, it normally holds the last datum the intervening instruction moved and
// NOT an address.  That is silicon's behaviour and not an approximation of
// it: `MOV [3010h],AH ; LEA SI,DI` reads 0x3010 + 0x1111 (AW), i.e. the
// displacement from the B rail and the moved datum from this one.
reg [15:0] ea_residue;
// THE B RAIL.  An EA calculation loads it on EVERY form, with the SECOND
// ADDEND: the index register where the form has one and nothing is added
// after it, the displacement otherwise, and ZERO where there is nothing to
// add.  `_valid` records that the rail STILL HOLDS what the EA calculation
// put there -- that no tmpb write has replaced it since.  It does NOT mean
// "the EA had a register pair"; that is what it used to mean, and silicon
// refuted it (21 directed socket probes, 2026-09-20:
// docs/notes/suite_divergence_results_2026-09-20.md sec.6.2 and
// docs/notes/ea_qualifier_results_2026-09-20.md).
reg [15:0] ea_pair_rhs;
reg        ea_pair_valid;
reg [15:0] opr;
reg [15:0] ind;
reg [15:0] count;
reg  [7:0] pfxcnt;
reg [15:0] stat;
reg        sign_neg;
reg  [3:0] bit_n;

// --- THE OPERAND-WIDTH TAGS (sim/state.h::Machine::tmp_byte / opr_byte) -----
// The micro-ALU's flag taps -- and the iterative unit's carry chain -- sit at
// 8 or 16 bits, and WHICH is a property of the OPERAND the ALU was handed, not
// of the instruction's w-bit.  Every datapath rail either presents a 16-bit
// datum or presents an 8-bit one in the low lane with something FOREIGN in the
// upper one; these bits latch which, beside the register that took it.
// `al_byte` USED TO LIVE HERE and is RETIRED -- see `al_width_byte` below.
reg        tmpa_byte, tmpb_byte, tmpc_byte;
reg        opr_byte;

// --- the latched micro-ALU (sim/state.h::AluLatch) -------------------------
reg  [4:0] al_op;
reg  [1:0] al_tmp;
reg        al_eaconst;
reg [15:0] al_eaval;
reg  [1:0] al_adjust;      // 0 none, 1 ADJD, 2 ADJA
reg  [1:0] al_adjtmp;
reg        al_bitarm;
reg  [3:0] al_bitn;
reg        al_spent;

// --- the micro-PC ----------------------------------------------------------
reg  [2:0] upc_page;
reg  [7:0] upc_opc;
reg  [3:0] upc_loc;

// --- prefix / pre-decode latches -------------------------------------------
reg        seg_override;
reg  [1:0] seg_ovr;
reg  [2:0] rep_kind;
reg        lock_pfx;
reg  [7:0] opc_reg;
reg        op8, imm8;
reg  [4:0] opc_base;
reg        opc_from_modrm;
reg  [2:0] modrm_reg;
reg  [3:0] xop;
reg  [1:0] rep_test;
reg        rep_pol;
reg        bus_word;
reg        opc8080;
reg        mode8080;
reg        intr_pending;
reg        eu_halted;

// --- the interrupt recognition (U2 pass 5; docs/facts/interrupt_model.md) ---
// The pins reach the decision through flops, and THAT is the whole mechanism:
// the ucore does NOT render `timed_runner.cpp`'s `D = max(B, A + pipe)`, which
// the third Codex review (ledger C5) showed to be an artefact of the REPLAY
// driver -- nothing in hardware can hold a boundary for a pin that has not
// asserted yet.  What is left is causal and small: pipeline the INT LEVEL,
// edge-latch NMI, and test the MATURED event at each boundary.
reg  [3:0] int_p;          // pin_int:  int_p[k] is the level of clock c-1-k
reg  [4:0] nmi_p;          // pin_nmi, one deeper (the latch is an EDGE)
reg        nmi_latch;      // set at edge+3, so it reads true from edge+4
reg  [3:0] ie_p;           // psw[FIE] through the SAME three flops
reg        rep_chain;      // ...this REP boundary is a CHAINED one (>= 2)
reg        irq_shadow;     // a segment-register write skips ONE boundary
reg        bnd_armed;      // this `S_OPC_POP` is an instruction boundary
reg        irq_sel_nmi;    // the kind, latched AT the boundary
reg        irq_sel_brk;    // ...and the THIRD kind: the single-step trap
reg        unhalt_pend;    // the NMI wake's `unhalt()`, owed to the entry clock
reg        irq_fast_inta; // first INTA may consume a standing CODE collision
reg        irq_halt_entry;// HALT wake owes one IRQ-dispatch handoff clock

// --- the BRK/TF single-step trap (§86; the law is §84.3 / §85.2b) ----------
// THE ARM DOES NOT SEE A `TF` THAT ROSE TOO RECENTLY, and it is an ARM, not a
// gate: a bit SAMPLED at one instruction boundary and TAKEN at the NEXT.
//
//   "At every instruction boundary the machine first TAKES the trap if the arm
//    bit is set (and the entry clears it), and then SAMPLES `TF` into the arm
//    bit.  A PREFIX BYTE ENDS AN INSTRUCTION BOUNDARY."   -- §84.1, verbatim
//
// MEASURED against silicon on a directed board cell built for it (§85.2b):
// the floor is **3 clocks**, 121,890 rows at 0 row-diffs, with no other value
// in [1,7] within four orders of magnitude.  §84.7's PURE GATE -- "take at the
// first boundary at which TF has been up for at least N clocks" -- is REFUTED
// by that cell's two SATURATED controls (`popfmemr`/`popfmul`, whose first
// boundary sits 13 and 25 clocks past the rise): the chip STILL waits one more
// boundary there, so the fitting `N` sets are {5,6,7} against {26,27,28} and
// no `N` exists.  That is an arm bit, and it is measured.
//
// NOTHING HERE NAMES AN OPCODE.  §84.1 wrote the POPF/IRET asymmetry as an
// opcode rule; §84.3 re-read it as ONE FLOOR (007A and 01EA are both
// `OPR -> FLAGS  F E` rows with identical geometry -- what differs is CLOCKS,
// because `9D` retires AT its own flag write and `CF` flushed the queue at
// 01E8), and the cell's `iret`/`popfnone` pair MEASURES the consequence:
// phase 2 against phase 3 at both wait levels, which only a clock floor gets.
// THE DEPTH IS **4**, AND IT IS THE MEASURED FLOOR OF **3** -- the difference
// is a COORDINATE, and it is the one `ie_p` already pays.  The model stamps the
// rise in `sample_ie()`, called at the TOP of `tick()`, so a PSW bit that is up
// during clock `c` is stamped `rise = c`; block (a) here freezes `brk_now` from
// the same register at the same instant and it reaches `brk_p[0]` one flop
// later.  MEASURED, engine vs engine on the cell's own sleds:
// `rise_sim = rise_rtl + 1` on 8 of 8 first rises (`popfnone`/`popfclc`/
// `popfmul`/`iret` x w0, w3), so the model's `c >= rise + 3` IS this module's
// `c >= rise + 4`.  It is the same offset that makes the INT gate read
// `ie_p[2]` -- three flops -- where the model's `kIeFloor` is 2.
//
// AND SILICON SAYS SO INDEPENDENTLY.  §85's cell re-scored with this core as
// the engine, per clock over its 30 retained captures, at every candidate
// depth in [1,7]:
//     1: 71,304   2: 71,304   3: 33,941   **4: 0**   5: 14,630
//     6: 43,762   7: 61,033          (121,860 rows each)
// One value is EXACT and nothing else is within four orders of magnitude --
// the same shape, on the same captures, that gave the model its 3.
//
// `V30_BRK_FLOOR` is the INSTRUMENT KNOB that made that table possible and
// nothing else: a compile-time define with the landed value as its default, no
// gate sets it, and the synthesised design carries exactly `BRK_FLOOR` flops.
// (The model's is `V30SIM_BRKFLOOR`; this is the same instrument, RTL side.)
//   *Falsifier*: any capture on which a depth other than 4 scores fewer
//   row-diffs against silicon than 4 does.
`ifndef V30_BRK_FLOOR
 `define V30_BRK_FLOOR 4
`endif
localparam int BRK_FLOOR = `V30_BRK_FLOOR;
reg [BRK_FLOOR-1:0] brk_p;  // psw[FBRK] through the SAME flops as `ie_p`
reg        brk_arm;        // THE ARM.  One flop, and it crosses boundaries.
reg        brk_smp;        // ...a boundary's F pop rode the PREVIOUS clock

// operand latches M / R / WB
reg  [1:0] m_kind, r_kind, wb_kind;
reg  [2:0] m_idx,  r_idx,  wb_idx;
reg [15:0] m_ea,   r_ea,   wb_ea;
reg  [2:0] m_seg,  r_seg,  wb_seg;
reg        m_byte, r_byte, wb_byte;

// --- the write-data pairing latch (exec_impl.h::Pending) --------------------
reg        pend_active;
reg [15:0] pend_off;
reg  [2:0] pend_seg;
reg        pend_byte;
reg        pend_io;
reg        opr_fresh;
// §87.A -- THE OPR-VALID INTERLOCK.  Has ANYTHING put a value into `opr` since
// this decode started?  The decoder's operand pre-read (`ld_preread`), a
// completed micro-row read delivered out of `rdq`, or a `-> OPR` transfer.
// It is NOT `opr_fresh`, which is the WRITE-PAIRING latch ("OPR carries a word
// a store has not taken yet") and is cleared by the pairing; conflating the two
// moves every paired store.  See `opr_starved` beside `f_wait`.
reg        opr_loaded;

// --- the bus interlock bookkeeping (the EU's half) -------------------------
reg [15:0] rdq0, rdq1;     // completed reads awaiting OPR delivery
reg  [1:0] rdq_n;
reg  [1:0] rd_pending;     // posted reads (rd_last) not yet completed
// ...AND THE WIDTH TAG RIDES IN THE SAME SLOTS.  A byte cycle fills only one
// lane, so the word it delivers into OPR is a BYTE datum and OPR's upper lane
// holds the bus's other byte -- foreign, exactly the `rb16` sibling-lane case.
// `eu_rdata_n` carries no such tag: "the bus has NO RESULT TAGS -- it returns
// words in order" (the 8F discard, below), and THAT ordering is what makes one
// bit per slot sufficient.  The bit is written where the read is POSTED
// (`rdp*`, in issue order), shifted into the completed-read store's slot at the
// same completion that writes `rdq*`, and popped into `opr_byte` at the same
// delivery that writes `opr`.  No new structure: the two stores the EU already
// keeps are one bit wider.
reg        rdp0_byte, rdp1_byte;  // posted-read record, oldest first
reg        rdq0_byte, rdq1_byte;  // completed-read store, oldest first
reg        ghost_rd_discard; // displaced tail completion after a mod3 POP read
reg  [1:0] rd_done_cnt;    // completed, not yet consumed by an F row
reg        rd_age0;        // the oldest completion pulsed on THIS clock
reg        iend_owed;      // F22: the post-`E` row owes the successor its reset
reg  [2:0] rst_ctr;        // F25: the reset dispatch's four clocks
reg [15:0] tsel;           // F29: the LIVE tmp an arming row reads
reg  [7:0] pe_opc_reg;     // F23: the opcode context the post-`E` row runs on
reg        pe_opc8080;
reg        pe_op8;         // ...INCLUDING the operand width (pass-3 review D1)
reg  [7:0] pe_pfxcnt;      // ...and the prefix count (F22's registered residue)
reg  [1:0] wr_out;         // posted write CYCLES not yet done

// --- the opcode latch ------------------------------------------------------
reg        opc_valid;
reg  [7:0] opc_byte;
reg        pop_is_first;

// --- the loader's working set ----------------------------------------------
reg  [7:0] ld_b;
reg [13:0] ld_pla;
reg        ld_ext;
reg  [2:0] ld_page;
reg        ld_hasrm;
reg  [7:0] ld_rm;
reg [15:0] ld_disp;
reg  [7:0] ld_dlo;
reg        ld_grpd;
reg        ld_byte;
reg        ld_preread;
reg        ld_ripe_prev;   // M8's `pen`: was the byte poppable BEFORE demand?

// --- the sequencer ---------------------------------------------------------
reg  [5:0] st;
reg  [1:0] chg;            // remaining charge clocks of the current step
reg        ending;         // the E row has run; the post-E row is next
reg  [1:0] rowq;           // queue bytes this row has already taken
reg        row_posted;     // this row's bus cycle has been posted
reg        row_paired;     // ...and its data handed over
reg [15:0] rloop_n;        // R-loop iterations still owed
reg        suppress_commit;
reg        first_pop_seen;
reg  [7:0] rowb0, rowb1;   // the queue bytes this row has taken
reg        poste;          // the post-E row's work is owed to the NEXT clock

//----------------------------------------------------------------------------
// STATES.  A state occupies one clock unless marked ZERO-COST, in which case
// it is executed inside the edge that reached it (the chain loop).
//----------------------------------------------------------------------------
localparam bit [5:0]
    S_OPC_POP   = 6'd0,   // pop the instruction's first byte (an F)
    S_TAKE_OPC  = 6'd1,   // ZERO-COST: consume the pre-popped opcode
    S_DECODE    = 6'd2,   // ZERO-COST: the prefix test
    S_DECODE2   = 6'd3,   // ZERO-COST: width / 1BL / ModR/M fan-out
    S_PFX_CHG   = 6'd4,   // a prefix's own second clock
    S_EXT_CHG1  = 6'd5,   // 0F: charge(1) before the second byte
    S_EXT_POP   = 6'd6,   // 0F: the real opcode, popped as an S
    S_1BL_LEAD  = 6'd7,   // wait_retire_lead ALONE (the write is at S_DECODE2)
    S_MODRM     = 6'd8,   // pop the ModR/M byte (opcode+1)
    S_D8_A      = 6'd9,   // opcode+2: no byte demanded
    S_D8_B      = 6'd10,  // opcode+3: the disp8 (M8's `pen`)
    S_D16_LO    = 6'd11,  // opcode+2
    S_D16_A     = 6'd12,  // opcode+3: no byte demanded
    S_D16_HI    = 6'd13,  // opcode+4: the high byte (M8's `pen`)
    S_EA_CHG    = 6'd14,  // mod != 3, no displacement: the EA-compute clock
    S_EA_CALC   = 6'd15,  // ZERO-COST: the address adder
    S_NORM_CHG  = 6'd16,  // no ModR/M: the opcode+1 clock
    S_BIND      = 6'd17,  // ZERO-COST: group dispatch, OPC select, binding
    S_PRERD     = 6'd18,  // the pre-decode operand read + wait_opr
    S_GRPD_CHG  = 6'd19,  // the second-byte group's extra clock
    S_ENTER     = 6'd20,  // ZERO-COST: enter the micro-sequence
    S_ROW       = 6'd22,  // a micro-row's own clock
    S_ROW_CHG   = 6'd23,  // the taken-JMP / FARJMP redirect bubble
    S_RLOOP     = 6'd24,  // one iterative step per clock
    S_EPOP      = 6'd25,  // the E row's successor pop, deferred
    S_TAIL      = 6'd26,  // ZERO-COST: run_micro's tail
    S_TAIL_W    = 6'd27,  // ...its F interlock + emit_pending
    S_TAIL_POP  = 6'd28,  // ...and its deferred opcode pre-pop
    S_INSTR_END = 6'd29,  // ZERO-COST: step() returns
    S_HALTED    = 6'd30,  // the part is parked
    S_RESET     = 6'd31,  // F25: the internal reset dispatch, 4 clocks
    S_IRQ_D     = 6'd32,  // the recognised boundary's ONE decision clock
    S_1BL_CHG   = 6'd33;  // ...and the 1BL form's own trailing charge(1)

// THE NINE STATES A ZERO-COST HAND-OVER CAN LEAVE THE CHAIN STANDING IN.
// Every OTHER arm's predecessors set `stop`, so no other state can occupy a
// chain position >= 1 -- the property v30u_eu_step.svh's 24 `chain == 4'd0`
// guards rest on, and the one this fails safe against.
//
// A FUNCTION AND NOT A WIRE, and that is F11b's trap for the fourth time: `st`
// is written with BLOCKING assignments inside the chain, so a `wire` off it
// carries the PRE-EDGE state and the test would ask about position 0's state
// at position 1.  Measured as written: 392/4164.
function automatic logic st_zero_ok(input [5:0] s);
    st_zero_ok = (s == S_TAKE_OPC) || (s == S_DECODE) || (s == S_DECODE2)
              || (s == S_EA_CALC)  || (s == S_BIND)   || (s == S_ENTER)
              || (s == S_TAIL)     || (s == S_TAIL_POP)
              || (s == S_INSTR_END);
endfunction

//============================================================================
// THE COMPOSITION (campaign risk #1, second half) -- F7, see the ledger
//============================================================================
// The BIU publishes TWO NAMED VIEWS of every quantity this module consumes
// (v30u_biu's "THE EU CONTRACT" block), and WHICH ONE to read is decided by
// WHERE the value is used, not by what a simulator happens to schedule:
//
//   * the COMBINATIONAL ACT DECODE below (`q_pop`, `eu_post`, `eu_pair`,
//     `q_flush`, `eu_susp`, `eu_halt`) reads the REGISTERED view -- `q_ripe`,
//     `q_byte`, `eu_slot_busy`, `eu_wr_done`, `eu_opr_free`.  An act is
//     consumed by the BIU on the clock that names it, so it must be decided
//     from the BIU's level DURING that clock;
//
//   * THE CLOCKED STEP reads the `_n` view -- `eu_slot_busy_n`,
//     `eu_rd_done_n`, `eu_wr_done_n`, `eu_rdata_n`,
//     `q_ripe_lead_n`, and the `*_n` stall wires derived from them.  That step
//     produces the EU's state for the clock this edge OPENS and must therefore
//     see the BIU as it will be then.
//
//   * `q_ripe` / `q_byte` are read by the clocked step in the REGISTERED view
//     and that is not an exception: the byte the step consumes is the one the
//     BIU handed over on the clock that is ending, which is the clock the pop
//     rode.  Everything else the step consults is the BIU it is stepping into.
//
// Nothing here depends on process order, and no `_n` signal reaches a
// combinational output of this module, so the EU->BIU direction stays a
// registered boundary and closes no loop.  REFUTED, and kept refuted: LATCHING
// the levels in this module -- that puts every pop one clock late (B8 500->123)
// because a latch delays the whole view instead of naming the two.

//============================================================================
// THE MICRO-ROW STANDING ON `upc`
//============================================================================
// L1 -- THE DECODE IS TAKEN ON THE EDGE THAT MAKES ITS ADDRESS.
//
// `ucdecode`'s address is {upc_page, upc_opc, upc_loc[3:2]} -- THIRTEEN BITS,
// every one of them a register in the one bank below, committed by the one
// condition `if (ss_we || srst || ce)`.  So the decode of the micro-address the
// bank is ABOUT TO COMMIT can be read on the edge that commits it, and the
// value standing on the table's output at every clock is then, BY
// CONSTRUCTION, the value the combinational read would have produced on that
// clock.  `dec_addr_next` (assigned beside THE COMMIT, below) is character for
// character the selection the bank applies to `upc_*`, so:
//
//    * the bank commits at c  ->  upc_*(c) is what dec_addr_next was formed
//      from at c-1, and dec_q(c) is `ucdecode` of that same value;
//    * the bank does not commit at c  ->  neither upc_* nor dec_q moves.
//
// THIS IS NOT RETIMING ACROSS A CLOCK.  It is taking a lookup on the edge that
// already determines its input -- the ghost relocation's own g_sp/g_bare
// pattern (capture at the defining event, consume registered) -- and it moves
// no pin on any clock.  It is also not the BANNED M10K conversion: an M10K puts
// the ROM's OUTPUT one clock LATE, which costs a cycle; this puts the LOOKUP
// one clock EARLY and the output on time.  THE COMMIT block's own comment
// already named it: *"upc_page_n / upc_opc_n / upc_loc_n exist as wires as a
// free consequence -- the only thing a registered microcode ROM ever needed."*
//
// WHY: `docs/notes/adcone_anatomy_2026-08-13.md`.  On CONTROL seed 5 the
// binding path is `upc_opc[7] -> nec_bus|ad_in_q[14]`, 25.031 ns of data path,
// and `ucdecode` is 4.770 ns / 5 of its 29 cells; over the top 60 paths into
// the observation registers it is on 60 of 60 at 4.691 ns per appearance.  It
// is single-cycle there because the rig's sampler is free-running (E-1 is
// deleted); it is FOUR cycles on the D pin below (the 4/3 CE multicycle), and
// the same move takes `ucdecode` AND `ucrom` off the existing
// `upc -> ucdecode -> ucrom -> chain -> upc_n` path.
//
// ⚠ THE ONE CLOCK WHERE IT IS NOT IDENTICAL, NAMED IN ADVANCE: before the
// first commit.  `dec_q` powers up 0, so `dec_valid` is 0 and `row_nop` is 1 --
// the model's NOP-CTL substitution, the safe direction -- where the
// combinational read would give `ucdecode[0]`, which F44's own probe proves is
// non-zero.  Every harness asserts `srst` before it observes anything and
// `srst` forces the commit.  Falsifier: the whole pin-sensitive ladder.
//
// NO SDC EDIT IS NEEDED OR TAKEN: `dec_q` is declared here, so its post-fit
// node is `...|v30u_eu:u_eu|dec_q[*]`, which `nec_test.sdc`'s $v30u_regs glob
// already selects, and it is `ce`-gated exactly as every other EU register.
wire [12:0] dec_addr_next;          // assigned beside THE COMMIT, below
wire        dec_valid_next;
wire  [8:0] dec_bank_next;
reg   [9:0] dec_q;
wire        dec_valid = dec_q[9];
wire  [8:0] dec_bank  = dec_q[8:0];
wire [28:0] s1w_row;

v30u_ucrom #(
    .HEXDIR ( HEXDIR )
) u_ucrom (
    .dec_addr (dec_addr_next),
    .dec_valid(dec_valid_next),
    .dec_bank (dec_bank_next),
    .rom_addr ({dec_bank, upc_loc[1:0]}),
    .rom_word (s1w_row)
);

// sw/ucore_tables.py::MicroOp -- the field positions, verbatim
wire [4:0] r_s1   = s1w_row[28:24];
wire [4:0] r_d1   = s1w_row[23:19];
wire [3:0] r_s2   = s1w_row[18:15];
wire [1:0] r_d2   = s1w_row[14:13];
wire       r_f    = ~s1w_row[12];
wire       r_w    = ~s1w_row[11];
wire       r_e    = ~s1w_row[10];
wire [1:0] r_type = s1w_row[9] ? TY_CTL : (s1w_row[8] ? TY_JMP : TY_ALU);
wire [4:0] s1w_r_aluop= s1w_row[7:3];
wire [1:0] s1w_r_alutmp = s1w_row[2:1];
wire       r_r    = s1w_row[0] && (r_type == TY_ALU);
wire [3:0] s1w_r_cond = s1w_row[7:4];
wire [3:0] s1w_r_loc  = s1w_row[3:0];
wire [3:0] r_ictl = s1w_row[9:6] & 4'hF;   // {row[9]=1 marks CTL}: ictl = row[8:5]
wire [2:0] r_ectl = s1w_row[4:2];
wire [1:0] r_sr   = s1w_row[1:0];

// The CTL field split, taken literally from the reference parse:
//     ictl = (bits >> 5) & 15 ; ectl = (bits >> 2) & 7 ; sr = bits & 3
wire [3:0] c_ictl = s1w_row[8:5];
wire [2:0] c_ectl = s1w_row[4:2];
wire [1:0] c_sr   = s1w_row[1:0];

wire       r_farjmp = (r_type == TY_CTL) && (c_ictl == I_FARJMP);
wire [4:0] s1w_r_farloc = {c_ectl, c_sr};
wire       r_nopmove = (r_s1 == 5'h1F) && (r_d1 == 5'h1F);
wire       r_hasconst = (r_s1 == 5'h17);
wire [5:0] r_constval = {r_s2, r_d2};
// A FARJMP row aliases Ext:SR as its target, so it has no bus cycle.
wire [2:0] r_ect = r_farjmp ? 3'd7 : c_ectl;

// unmapped micro-address: the model substitutes a NOP CTL row
wire       row_nop = !dec_valid;
wire [4:0] s1w_e_s1    = row_nop ? 5'h1F : r_s1;
wire [4:0] s1w_e_d1    = row_nop ? 5'h1F : r_d1;
wire [3:0] s1w_e_s2    = row_nop ? 4'hF  : r_s2;
wire [1:0] s1w_e_d2    = row_nop ? 2'd3  : r_d2;
wire       s1w_e_f     = row_nop ? 1'b0  : r_f;
wire       s1w_e_w     = row_nop ? 1'b0  : r_w;
wire       s1w_e_e     = row_nop ? 1'b0  : r_e;
wire       e_r     = row_nop ? 1'b0  : r_r;
wire [1:0] s1w_e_type  = row_nop ? TY_CTL : r_type;
wire [3:0] s1w_e_ictl  = row_nop ? 4'hF  : c_ictl;
wire [2:0] s1w_e_ectl  = row_nop ? 3'd7  : r_ect;
wire [1:0] e_sr    = row_nop ? 2'd3  : c_sr;
wire       s1w_e_farjmp= row_nop ? 1'b0  : r_farjmp;
wire       s1w_e_nopmv = row_nop ? 1'b1  : r_nopmove;
wire       e_hasc  = row_nop ? 1'b0  : r_hasconst;

wire s1w_e_is_rloop = (s1w_e_type == TY_ALU) && e_r;
wire s1w_e_have1 = !s1w_e_nopmv;
wire s1w_e_have2 = !e_hasc && ((s1w_e_s2 != 4'd15) || (s1w_e_d2 != 2'd3));

// The 0F21 negative/no-carry result rail advances the E hand-over to row 5 and inhibits
// the stale architectural writeback that would otherwise ride that shortened
// path.  A non-negative 0F21 capture and four 0F23 captures all retain the
// ordinary row-6 hand-over, so the condition is the ALU sign rail, not an
// opcode-wide timing shortcut.
wire s1w_ext4s_early_e = (upc_page == 3'd4) && (upc_opc == 8'h21) &&
                     (upc_loc == 4'd5) && stat[FS] && !stat[FCY];
wire s1w_ext4s_early_wblock = (upc_page == 3'd4) && (upc_opc == 8'h21) &&
                          (upc_loc == 4'd3) && s1w_sig_flags[FS] && !s1w_sig_flags[FCY];
// On the shortened path row 6 is the post-E overlap.  On the ordinary path it
// is the E row itself and `poste` is still clear, which makes this distinction
// state-free.
wire s1w_ext4s_early_post = poste && (upc_page == 3'd4) &&
                        (upc_opc == 8'h21) && (upc_loc == 4'd6);
wire s1w_ext4s_arch_d1 = (s1w_e_d1 <= 5'd4) || (s1w_e_d1 == 5'd15) ||
                     (s1w_e_d1 == 5'd18) || (s1w_e_d1 == 5'd19) ||
                     (s1w_e_d1 >= 5'd24);

//============================================================================
// SEGMENT / WIDTH HELPERS
//============================================================================
// sim/biu_timed.cpp::seg_code -- sim Sreg ES,CS,SS,DS = 0,1,2,3; the S4:S3 pin
// code is ES,SS,CS,DS = 0,1,2,3.  kSegZero and I/O drive the "no segment"
// code, which is the same encoding as CS.
function automatic [1:0] seg_code(input [2:0] s);
    case (s)
        3'd0: seg_code = 2'd0;   // ES
        3'd1: seg_code = 2'd2;   // CS
        3'd2: seg_code = 2'd1;   // SS
        3'd3: seg_code = 2'd3;   // DS
        default: seg_code = 2'd2;
    endcase
endfunction

// exec_impl.h::sr_is_io -- SR == IO selects the I/O space only for the port /
// block-I/O opcode classes.
wire row_io  = (e_sr == 2'd1) && ((xop == 4'hF) || (xop == 4'h6));
// exec_impl.h::sr_segment
wire [2:0] row_seg = (e_sr == 2'd0) ? 3'd0
                   : (e_sr == 2'd1) ? SEG_ZERO
                   : (e_sr == 2'd2) ? 3'd2
                   : (m_kind == OK_MEM) ? m_seg
                   : (r_kind == OK_MEM) ? r_seg
                   : (seg_override ? {1'b0, seg_ovr} : 3'd3);
// Bus width follows OP8b unless Ext [-03-] has forced WORD (ledger A37).
wire row_bbyte = op8 && !bus_word;

wire [15:0] seg_val = (row_seg == SEG_ZERO) ? 16'h0000 : sreg[row_seg[1:0]];
wire [19:0] row_phys = {seg_val, 4'd0} + {4'd0, ind};

//============================================================================
// STALLS (the five named wires)
//============================================================================
// A row's F interlock: which HALF applies is the direction of the row's own
// touch (exec_impl.h::deliver_read).  A row that READS OPR waits for the read
// that fills it; a row that only LOADS OPR waits only for a store to give OPR
// back.
wire s1w_row_reads_opr = (s1w_e_s1 == 5'd6);

// wait_next_read(extra): the next outstanding EU read, in order.
//
// `|| eu_rd_done_n` is F11a's rule on the READ side, and it was missing.  The
// WRITE side already reads its completion as REGISTER-ONLY LOOKAHEAD
// (`retire_ok_n`'s `eu_wr_done_n`, published from `r_done_ctr`/`r_done_wr`),
// because `wait_bus`'s deadline is a clock, not a flag: the row runs ON the
// completion clock.  `wait_next_read` is the same deadline -- the model waits
// `while (clk_ < rd_done_q_.front())` and runs AT that clock -- so the read
// side must read the same lookahead.  Without it the EU's own `rd_done_cnt`
// only rises on the clock AFTER the completion and every `F` row that waits on
// a read runs one clock late (`58 idx 0`: the successor's F pop at row 14
// where the golden has it at row 13; the whole POP/RET/direct-address family).
// The consumer sees the count already incremented because block (a) runs
// BEFORE the chain in the same edge.
wire nr_have   = (rd_done_cnt != 2'd0) || eu_rd_done_n;
wire s1w_nr_wait   = !nr_have && (rd_pending != 2'd0);
// ...and `extra` (wait_opr's +1) bites only when the completion is on THIS
// clock -- otherwise the deadline is already past.
wire nr_extra_block = nr_have && rd_age0;

// wait_opr_free: the store lets go of OPR at its own T2+1 (11.4, fixed index).
// F7: the same term in the two views -- the plain name for the act decode, the
// `_n` name for the clocked step.  ONE expression each, differing only in which
// BIU view it reads.
// F31 -- THE HOLD IS THE BIU'S COUNT, AND THERE IS ONLY ONE VIEW OF IT.
//
// The EU used to keep its OWN `opr_owned` counter of the stores it had paired
// and test it against the BIU's release PULSE.  That is F11's named error --
// one event, two reconstructions -- and it was wrong in both of its parts:
//
//  * the pulse view.  `opr_free_now_n` read `eu_opr_free_n`, the release
//    computed DURING the T2 clock, so the `F` row completed at the end of T2.
//    The model's release instant is `opr_free_clk_ = T2 + 1` and the row runs
//    ON that clock, i.e. T3.  Every non-OPR-reading `F` row therefore ran one
//    clock early, which is the whole multi-cycle-push family: `60`'s ROM
//    alternates `SIGMA -> IND CTL MEMW SS` with `<reg> -> OPR F CTL`, and the
//    idle `Ti` the golden shows between consecutive stores IS that clock.
//    (`60` was green on push #1 only, and only by accident: the FARJMP bubble
//    after 023B put the clock back.)
//  * the count.  The model's `++opr_held_` is CONDITIONAL --
//    `if (!(r == &cur_ && run_ && ci_ > 1))`, a fact about the BIU's own
//    running cycle -- and the EU cannot see it, so an EU-side count can never
//    be faithful.  `opr_owned += (pend_split ? 2 : 1)` also over-counted a
//    split against the pulse test: ALL 96 odd-SP `60` cases failed and ALL 104
//    even-SP cases passed.
//
// So the counter is the BIU's `opr_held` (which IS `BiuTimed::opr_held_`) and
// the published fact is the model's own predicate off the REGISTER.  One
// expression, both views -- the act decode and the clocked step cannot drift.
//
// C4 (THE THIRD CODEX REVIEW) -- ...AND M13's 8080 ARM WAS NEVER RENDERED.
// `wait_opr_free()` opens with `if (md8080_ && *md8080_) { wait_bus(); return; }`
// -- "in 8080 EMULATION MODE the store does not let go until it has RETIRED.
// In native mode the store hands its word to the AD output latch at T2 and OPR
// is free from T3 (11.4, the FIXED index 2 that does NOT stretch).  With MD set
// the release is the store's own eu_done -- the completion eval + 2, the
// deadline `wait_bus()` already carries -- so it STRETCHES with the eval like
// every other eval-keyed quantity."  The EU had NO mode term at all, in this
// rendering OR in the pulse rendering F31 replaced, so this is PRE-EXISTING and
// not F31's -- but F31 made this the one place it can live.  `wait_bus`'s
// deadline is `retire_ok_n`, so the arm is the SPEC's own line, verbatim.
//
// UNREACHABLE ON THE CURRENT STIMULUS and therefore UNVERIFIED BY IT: `mode8080`
// is set only by an `MFC` row, and the 8080 loader / BRKEM path is ledger R4,
// unimplemented.  The census proves the no-op (G3 164,787 either way, zero forms
// moved), which is D1's shape -- a latent correctness fix whose score does not
// move.  *Falsifier*: the first 8080-mode store the ucore executes, which is
// R4's own gate; that is where this arm gets its verification, not here.
// wait_bus (the retire deadline): every posted store, then its e+2.  ONE view
// only -- `eu_wr_done_n` is registered logic (see the BIU's `done_fire`), so
// the act decode may read it, and act and step MUST read the same thing: they
// are the same event seen from two sides (F11).
wire s1w_retire_ok_n = (wr_out == 2'd0) ||
                   ((wr_out == 2'd1) && eu_wr_done_n);

// W7 -- THE MFS FRAME STORE RELEASES AT ITS COMPLETION EVAL.  The consumer is
// the semantic row `CS -> OPR, SIGMA -> IND, F, JMP CNTZ`: it immediately
// follows the `MFS + MEMW SS` row, then the ROM runs MFC, 01F8 and the next
// MEMW issue.  Letting the fixed T3 release win erased those ROM clocks when
// the write stretched; waiting through retire added two invented clocks.  The
// completion pulse leaves the three real intervening rows to set the gap.
// This names the row's controls, not its ROM address or an opcode.
wire mfs_frame_release = (st == S_ROW) && s1w_e_f &&
                         (s1w_e_type == TY_JMP) && (s1w_r_cond == C_CNTZ) &&
                         s1w_e_have1 && (s1w_e_s1 == 5'd1) && (s1w_e_d1 == 5'd6);
wire eval_ok_n = (wr_out == 2'd0) ||
                 ((wr_out == 2'd1) && eu_wr_eval);
wire s1w_opr_free_now = mode8080          ? s1w_retire_ok_n
                  : mfs_frame_release ? eval_ok_n
                                      : eu_opr_free;

// §87.A -- THE ILLEGAL-FORM STALL.  `nr_wait` waits for the next OUTSTANDING
// read; when nothing is outstanding it is 0 and the row runs.  But the `F`
// interlock is a WAIT, and a wait needs something to wait for: a row that
// SOURCES OPR is waiting for the read that FILLS OPR, and if nothing has filled
// it since this decode began (`opr_loaded`) AND nothing is outstanding or
// completed, that wait has no terminator.  The EU parks on the row forever.
//
// It is NOT a halt: no `HLT` row ran, `eu_halted` stays clear, the HALT status
// is never driven and the PREFETCHER IS NOT FROZEN -- the BIU goes on fetching
// until the queue is full and then sits `PASV` with `qs = 0`, which is exactly
// the 957-3,906-row idle tail silicon shows (`ucore_provenance.md` §86.F).
//
// The rule NAMES NO OPCODE.  Swept over the whole opcode space -- native and
// `0F`, every ModR/M `reg`, `mod == 3` and memory, 8,192 forms -- it fires on
// `62` CHKIND, `C4` LES, `C5` LDS and the `FE`/`FF` group at `/3` and `/5`, all
// at `mod == 3`, and on NOTHING else: those are the forms whose first row takes
// the pre-read word out of OPR while a second word is still being fetched, and
// `mod == 3` is exactly the case where the decoder issues no pre-read at all.
// `FF /7` at `mod == 3` (2,477 `v20suite` goldens) does NOT fire -- its row
// `M -> OPR` WRITES the register -- and neither does `8D` LEA, which is why the
// archived FSM core's `S_HALT` wedge was right on `62`/`C4`/`C5` and a BUG on
// LEA (`tests/v30/mod3_illegal/metadata.json`).
//
// *Falsifier*: any golden case, in any suite, that reaches this wire (a golden
// is a captured chip record, and a stalled chip records no case); or a form
// outside the seven that stalls on silicon; or one of the seven that does not.
wire opr_starved = s1w_row_reads_opr && !opr_loaded && !nr_have &&
                   (rd_pending == 2'd0) && (rdq_n == 2'd0);

// ONE view: the `_n` twin is gone with the pulse it read (F31).  `nr_wait` is
// register-only lookahead (F18/F11a) and is legal in the act decode.
wire f_wait = s1w_row_reads_opr ? (s1w_nr_wait || opr_starved || !s1w_opr_free_now)
                            : !s1w_opr_free_now;

// BUSY is the 9B POLL_N pin, sampled through the same 3-deep pin pipeline the
// INT level goes through (biu_timed.h::poll_busy, "AND IT IS THE SAME 3-DEEP
// PIN PIPELINE").  U2 pass 5: the pipeline is REAL now, and its RESET VALUE is
// the pin -- a shift register that has been clocked since power-on holds the
// level it has been seeing, and `poll_busy()` reads a STATICALLY LOW POLL_N as
// "not busy" on clock 0 (`if (!(ev_pins_ & 4)) return false;`).  Reset to all
// ones instead made the first three clocks read BUSY, which is exactly the
// `POLL.LO` half that failed at row 3.
reg [2:0] poll_pipe;
wire s1w_poll_busy = poll_pipe[2];

//----------------------------------------------------------------------------
// THE RECOGNITION (interrupt_model.md's two laws, and nothing else)
//----------------------------------------------------------------------------
// "the boundary decision runs during the would-pop cycle B and sees the pin
// level of cycle B-3" -- so the INT LEVEL and the IE GATE go through the same
// three flops, which is also why there is no separate EI shadow flag.
// "NMI latch: set 3 cycles after the pin edge; latest catching edge = B-4".
//
// EVERY read of these registers from inside the clocked step goes through
// these wires: block (a) shifts the pipelines with BLOCKING assignments at the
// top of the edge, so the REGISTERS already hold the NEXT clock's view while
// the wires still hold THIS clock's (F11b's trap, and the whole module's
// convention).
wire s1w_irq_pin_int = int_p[2];                       // the pin at c-3
// SM3 SITTING 11 -- THE GATE READS IE TWICE, AND THE SECOND READ IS THE LIVE
// ONE.  `ie_p[2]` alone says only "IE was up three clocks ago"; a `CLI` since
// then does not take it back, so the recognition fires at a boundary where the
// architectural IE is CLEAR and pushes a PSW with IE = 0.  MEASURED on the
// socket (`sm3_s11_prereg_2026-08-04.md` §4, S3/S4/S5): on `CLI;POPF;NOP;NOP`
// and `CLI;STI;NOP;NOP` the chip takes the boundary after the CLI **0 times in
// 24 delays at every wait level**, and on `CLI;POPF` -- where that boundary is
// the only one IE ever reaches -- it takes NO ENTRY AT ALL in 24 of 24, while
// the same sled on the **NMI** pin acknowledges 24 of 24.  This core scored
// 3 / 5 / 24 of those, all of them at the forbidden boundary.
//   *Falsifier*: a maskable acknowledge on silicon whose PUSHED PSW has IE = 0.
// A request sampled on the same clock IE rises is retained in the existing
// `intr_pending` latch (block (a)) until this floor matures.  The latch has a
// second, older use for REP withdrawal, so only a non-REP context feeds it
// into this ordinary-boundary path; REP consumes it through C_INTR instead.
//
// fuzz-v2 family C2 -- **AND `!ie_p[3]` IS "UNTIL THIS FLOOR MATURES".**  The
// sentence above was written by `7647e604e0` and the implementation did not
// keep it: `intr_pending` is cleared ONLY by an interrupt entry, so the
// retention outlived the three-clock floor by however long the next boundary
// took to arrive.  MEASURED (`docs/notes/fz2_c2_amend_2026-08-10.md` §C2-1.3,
// `sw/fz2_c2_rescore.py`): over all 252 INT-stimulus fz2 captures the latch is
// load-bearing on exactly NINE clocks, and the ONLY column that separates the
// two silicon AGREES from the seven CORE-ONLYs is how far the read sits from
// the arm -- **2 and 3 clocks where silicon takes it, and 5, 215 and 289 on
// three where it does not.**  `ie_p[3]` is IE four clocks ago, so a latch
// armed at clock `A` is readable at `A+1 … A+3` and dead from `A+4`: exactly
// the floor, and the same idiom `eu_bnd_post` below already uses for "the IE
// gate is what held this boundary".
//
// WHAT THIS DELIBERATELY DOES **NOT** DO.  It does not close the four seats at
// `run - arm == 2` (`fz2c/405002` `fz2c/405013` `fz2c/405072` `fz2e/512056`),
// because `fz2c/404040` -- where SILICON RUNS THE ACKNOWLEDGE, seven clocks
// after its own pin fell -- is identical to them on every coordinate in the
// recognition path.  Separating those needs a directed board cell on the
// IE-rise / pin-fall race, and there is not one.  §C2-1.3 names all nine rows.
//   *Falsifier*: a capture in which the chip runs an acknowledge whose
//   recognition can only be carried by a latch armed more than three clocks
//   earlier -- i.e. `run - arm >= 4` with the chip agreeing.
wire irq_int_lvl = (int_p[2] ||
                    (intr_pending && (rep_kind == REP_NONE) && !ie_p[3])) &&
                   ie_p[2] && psw[FIE];
wire s1w_irq_nmi_lvl = nmi_latch;
wire irq_any     = s1w_irq_nmi_lvl || irq_int_lvl;
// A REP iteration boundary samples at the SAME depth below its own decision
// EDGE (interrupt_model.md, "REP abort": pin@edge-4) and reads the LIVE IE,
// not the pipelined one -- but its edge is NOT the loop row's clock, and the
// two anchors the SPEC records are one clock apart:
//
//   "the boundary-1 decision edge sits at a fixed opcode-pop+7 ... its flush
//    is invariant at pop+16 = edge+9.  Chained boundaries (>= 2) are
//    write-accept-anchored: decision at the accept edge, flush at accept+9."
//
// The `JMP REP` row stands at opcode-pop+6, so the FIRST boundary's edge is
// the row's clock + 1 (tap c-3) and a CHAINED one's is + 2 (tap c-2) -- the
// chained element's own store is still PENDING at the loop row, so its accept
// is one clock further out.  MEASURED over the 56 `INT.F3AA` mid-string
// aborts: the golden's flush is at pop+16 in ALL 35 one-element aborts and at
// the last write's T1 + 8 (= accept + 9) in ALL 21 chained ones.
//
// This is why a SINGLE tap depth has no clean fit (U2 pass 5 recorded the scan
// as a negative result: [0] 174, [1] 178, [2] 179, [3] 175) -- the two
// boundaries want DIFFERENT depths, because they are anchored to different
// edges.  Nothing here is fitted: both taps are `edge - 4`.
wire s1w_irq_rep_1st = s1w_irq_nmi_lvl || (int_p[2] && psw[FIE]);   // edge = c+1
wire s1w_irq_rep_chn = s1w_irq_nmi_lvl || (int_p[1] && psw[FIE]);   // edge = c+2

//============================================================================
// THE ROW'S DEMANDS
//============================================================================
// A queue byte: Source1 [-07-] (Q) and Source2 [-05-] (Q).
wire s1w_row_q1 = s1w_e_have1 && (s1w_e_s1 == 5'd7);
wire s1w_row_q2 = s1w_e_have2 && (s1w_e_s2 == 4'd5);
wire [1:0] s1w_row_qn = {1'b0, s1w_row_q1} + {1'b0, s1w_row_q2};
wire s1w_row_need_q  = (st == S_ROW) && ({1'b0, rowq} < s1w_row_qn);

// The bus rows.  [-06-] commits OPR to the r/m operand only when that operand
// is memory (the 8F mod==3 ghost).
// F28 -- A ROW SUPPRESSES ITS OWN WRITE-BACK.  `suppress_commit` is set INSIDE
// v30u_eu_row.svh, on the very row whose `[-06-]` it cancels (CMP: the ALU does
// not drive the result bus), so the act decode must reconstruct it rather than
// read the register a clock behind.  Without it `38`/`39`/`80.7` posted a store
// that never happened, `pend_after` deferred the successor's pop, and the F
// landed one clock late.
wire suppress_now = (s1w_e_s1 == 5'd20) && !s1w_sig_commits &&
                    (s1w_e_d1 == 5'd19) && (m_kind == OK_MEM);
wire row_wb_mem  = (wb_kind == OK_MEM) && !suppress_commit && !suppress_now;
wire row_is_read = (s1w_e_type == TY_CTL) && (s1w_e_ectl == E_MEMR);
wire s1w_row_is_wr   = (s1w_e_type == TY_CTL) && (s1w_e_ectl == E_MEMW);
wire s1w_row_is_wb   = (s1w_e_type == TY_CTL) && (s1w_e_ectl == E_WRITEBACK) && row_wb_mem;
wire s1w_row_is_inta = (s1w_e_type == TY_CTL) && (s1w_e_ectl == E_INTA);
wire s1w_row_bus     = row_is_read || s1w_row_is_wr || s1w_row_is_wb || s1w_row_is_inta;

// THE 8F GHOST **READ**, AND ONLY THE READ.  The ghost FEED
// (`ghost_rd_feed`, `ghost_rd_ready`, `eu_rd_wait`, the `S_PRERD`
// `ghost_preread_*` arms, `eu_ghost_preview`) and the PF_LOST decoder hold
// (`opc_rm_valid`, `opc_rm_byte`) are NOT here, and their save-state codes
// 0x17A-0x17D stay VACANT.  Both are booked UNLANDABLE-AS-DESIGNED with the
// block characterised, not the mechanism condemned:
// `docs/notes/ghost8f_results_2026-08-09.md` §9 measured the FULL family at
// **15.3 MHz on two draws** with every worst setup path launching from the
// READY register, and the netlist route it printed begins
// `c_ready_q -> eu_rd_edge -> ghost_preread_epop -> q_demand -> ...`, whose
// first hop after the pin is a FEED construct.  The hold is dead without the
// feed by construction: its only setter is gated on `ghost_rd_ready`.
//
// WHAT REMAINS RIDES REGISTERED STATE ONLY.  With the feed absent
// `eu_rd_edge` -- §73's ONE declared live-READY carrier -- has no ghost
// consumer at all, and `S_PRERD` / `S_MODRM` are untouched by this landing.
//
// A register-bound POP has no ModR/M address to compute, but its discarded
// stack-read row still reaches the bus.  Row 0058 copies the standing SIGMA
// value into tmpa; using that retained scratch value reproduces the measured
// ghost address for the closed histories, while the still-divergent histories
// remain evidence that the die's stale-address source is not yet universalized.
// The same row geometry is shared by ordinary POP-register paths, so the
// undocumented 8F page and its absent memory operand are both part of the
// select.
wire s1w_ghost_read_stale_alu = (upc_page == 3'd0) && (upc_opc == 8'h8f) &&
                            row_is_read && (row_seg == 3'd2) &&
                            (m_kind == OK_REG) && (wb_kind == OK_REG) &&
                            s1w_e_have1 && (s1w_e_s1 == 5'd28) && (s1w_e_d1 == 5'd5) &&
                            s1w_e_have2 && (s1w_e_s2 == 4'd12) && (s1w_e_d2 == 2'd1);
// The ghost's own micro-row is still standing while the loader's pre-decode
// read for the successor runs.  That overlap is what puts the stale word-lane
// and segment rails on the successor's access below.
wire ghost_preread_tail = (st == S_PRERD) && (upc_page == 3'd0) &&
                           (upc_opc == 8'h8f) && (upc_loc == 4'd4) &&
                           ghost_rd_discard;

// the access this row asks for.  Its OFFSET is `ind_now`, which is the row's
// OWN IND write when it has one -- see "THE ROW'S OWN TRANSFERS" below, next
// to the source muxes it needs.
wire [2:0] s1w_acc_seg   = s1w_row_is_wb ? wb_seg : row_seg;
// PF_LOST reaches the successor's bus-space select as well as its stale
// address.  On the measured REP-prefixed E4 successor the I/O rail is absent,
// so the otherwise identical read is a word memory cycle at offset 0042.
wire       ghost_lost_io = row_io && (upc_page == 3'd1) &&
                           (upc_opc == 8'he4) && (pe_opc_reg == 8'h8f);
wire       s1w_acc_byte  = s1w_row_is_wb ? wb_byte : (row_bbyte && !ghost_lost_io);
wire       s1w_acc_io    = s1w_row_is_wb ? 1'b0 : (row_io && !ghost_lost_io);
wire [15:0] acc_segv = (s1w_acc_seg == SEG_ZERO) ? 16'h0000 : sreg[s1w_acc_seg[1:0]];

// The PRE-DECODE operand read (loader_impl.h): the operand the sequence
// READS, and only that one.
wire        pr_use_m = (m_kind == OK_MEM);
wire  [2:0] pr_seg   = pr_use_m ? m_seg : r_seg;
wire [15:0] pr_ea    = pr_use_m ? m_ea   : r_ea;
wire        s1w_pr_byte  = pr_use_m ? m_byte : r_byte;
wire [19:0] pr_phys  = {sreg[pr_seg[1:0]], 4'd0} + {4'd0, pr_ea};
wire        pr_split = !s1w_pr_byte && pr_phys[0];
// A PF_LOST overlap on an odd pre-read leaves the normal segment rail on its
// first byte and the default data-segment rail on its second.  The BIU already
// stores each split half independently; publish both rails with the two
// addresses rather than adding any transaction history.
wire  [2:0] pr_seg2  = (ghost_preread_tail && pr_split) ? 3'd3 : pr_seg;
wire [19:0] pr_phys2 = {sreg[pr_seg2[1:0]], 4'd0} + {4'd0, pr_ea + 16'd1};

// The staged write in the pairing latch (exec_impl.h::Pending).
wire [15:0] pend_segv = (pend_seg == SEG_ZERO) ? 16'h0000 : sreg[pend_seg[1:0]];
wire [19:0] pend_phys = pend_io ? {4'd0, pend_off}
                                : ({pend_segv, 4'd0} + {4'd0, pend_off});
wire       pend_split = !pend_byte && pend_phys[0];

//============================================================================
// THE ALU
//============================================================================
function automatic [15:0] szp(input [16:0] r, input bbyte);
    logic [15:0] f;
    logic p;
    begin
        f = 16'd0;
        if (bbyte ? (r[7:0] == 8'd0) : (r[15:0] == 16'd0)) f[FZ] = 1'b1;
        if (bbyte ? r[7] : r[15]) f[FS] = 1'b1;
        p = ^r[7:0];
        if (!p) f[FP] = 1'b1;              // even parity -> P = 1
        szp = f;
    end
endfunction

// alu_opc_select
//
// F23 -- ...AND THE OPCODE LATCH THE `ALU OPC` MUX READS.  `opc_reg` is not
// RESET by the successor's decode, it is OVERWRITTEN (S_DECODE2, `opc_reg =
// ld_b`), so F22's deferral cannot reach it: by the post-`E` row's clock the
// EU already held the SUCCESSOR's opcode and every `ALU OPC` row resolved
// against it.  The whole accumulator-immediate block picked the operation the
// injected `90` selects -- index 2, ADC -- which is why `14` (ADC AL,imm8) was
// the ONE form of its group that passed and `24` (AND) came out as an add.
//
// The decoder's opcode latch loads at the END of its own clock; the post-`E`
// row reads it BEFORE that.  So the row's own opcode context travels with F8's
// debt: 9 bits, captured where `poste` is raised.
// D1 (SECOND CODEX REVIEW, §32) -- and `op8` travels with them.  F23 shadowed
// nine bits and claimed that was the row's whole opcode context; it was not.
// S_DECODE2 OVERWRITES `op8` on edge `c` exactly as it overwrites `opc_reg`
// (`v30u_eu_step.svh`'s `op8 = ld_byte`), and the post-`E` row reads it in
// three places: `SIGNTGL`'s `tmpb[7]` vs `tmpb[15]`, `dir*sz` as a Source1,
// and the ALU width's CLAUSE 2 (`al_width_byte`'s ABS arm; this used to be
// `al_byte = op8`, the blanket rule, and that was the REP CL==0 defect).
// Ten bits, not nine.
// F22 SETTLED (pass 4) -- ...and `pfxcnt` travels with them, for the SAME
// reason, which is the reason the residue existed at all.
//
// F22 and F23/D1 are ONE mechanism seen from two sides -- "the post-`E` row
// runs on the machine it belongs to" -- and which RENDERING a field takes is
// decided by exactly one question: DOES THE SUCCESSOR'S DECODE CHAIN WRITE
// THIS FIELD ON EDGE `c`?
//
//   no  -> DEFER the successor's reset past the discharge (`iend_late`).  The
//          register still holds the predecessor's value when the row reads it,
//          so no copy is needed.
//   yes -> the value must TRAVEL, because the register has already moved on.
//
// `pfxcnt` is the ONE field that is in both sets: `loader_decode`'s prologue
// RESETS it and S_DECODE's prefix arm WRITES it (`pfxcnt = pfxcnt + 1`).
// Deferring its reset was therefore wrong in both directions at once --
//   * the post-`E` row read `pfxcnt + 1` (the successor prefix's increment
//     stacked on the predecessor's count), and
//   * the deferred reset then landed on edge `c+1` and DESTROYED that
//     increment, so the successor ran its whole instruction with `pfxcnt = 0`.
// The second is the one that matters: `pfxcnt` is read on exactly ONE ROM row
// in the whole part -- `0225 PFXCNT -> tmpa`, the REPX withdrawal's
// `PC := PC - PFXCNT - 1` rewind -- and a `REP` string is BY CONSTRUCTION
// reached through a prefix.  Under whole-program replay every mid-string
// interrupt would have resumed at the opcode instead of at the first prefix,
// i.e. the 8086 lost-prefix bug the V30's ROM exists to avoid.
//
// So `pfxcnt` leaves the deferred set and joins the debt: the reset is back in
// S_INSTR_END's immediate block (the successor's prologue, where the model puts
// it) and the post-`E` row reads the copy.  The debt is EIGHTEEN bits.
// *Falsifier*: any other ROM row that reads PFXCNT, or any edge-`c` decode-chain
// write to one of `iend_late`'s remaining fields.
wire [7:0] opc_reg_eff = poste ? pe_opc_reg : opc_reg;
wire       opc8080_eff = poste ? pe_opc8080 : opc8080;
wire       s1w_op8_eff     = poste ? pe_op8     : op8;
wire [7:0] pfxcnt_eff  = poste ? pe_pfxcnt  : pfxcnt;
wire [2:0] opc_sel = opc_from_modrm ? modrm_reg : opc_reg_eff[5:3];
function automatic [4:0] opc8080_map(input [2:0] s);
    case (s)
        3'd0: opc8080_map = A_ADD;
        3'd1: opc8080_map = A_ADC;
        3'd2: opc8080_map = A_SUB;
        3'd3: opc8080_map = A_SBB;
        3'd4: opc8080_map = A_AND;
        3'd5: opc8080_map = A_XOR;
        3'd6: opc8080_map = A_OR;
        default: opc8080_map = A_CMP;
    endcase
endfunction
wire [4:0] alu_opc_sel = opc8080_eff ? opc8080_map(opc_sel)
                                     : (opc_base + {2'b0, opc_sel});

wire [4:0] eff_op = (al_op == A_OPC) ? alu_opc_sel : al_op;
// the operation the row NOW standing latches (exec_impl.h's `new_op`)
wire [4:0] s1w_nxt_op = (s1w_r_aluop == A_OPC) ? alu_opc_sel : s1w_r_aluop;
wire is_iter = ((eff_op >= A_ROL) && (eff_op <= A_SAR)) ||
               (eff_op == A_ROL12) || (eff_op == A_DIV) || (eff_op == A_MUL);

wire [15:0] tmps [0:3];
assign tmps[0] = tmpa;
assign tmps[1] = tmpb;
assign tmps[2] = tmpc;
assign tmps[3] = 16'd0;
// the same three, read by the row that LATCHES BIT / ABS
wire [15:0] tmps_lat [0:3];
assign tmps_lat[0] = tmpa;
assign tmps_lat[1] = tmpb;
assign tmps_lat[2] = tmpc;
assign tmps_lat[3] = 16'd0;

//============================================================================
// THE ALU'S WIDTH IS THE WIDTH OF THE OPERANDS IT IS HANDED -- EXCEPT FOR THE
// MULTIPLY/DIVIDE UNIT'S OPERAND CONDITIONING, WHICH IS THE INSTRUCTION'S.
//
//     A 16-BIT OPERATION NEEDS TWO 16-BIT OPERANDS.  The ALU works at BYTE
//     width when EITHER of the two it is handed carries only eight
//     significant bits -- OR WHEN THE OPERATION IS ABS.
//
// `al_byte = op8` -- the instruction's w-bit, which stood here -- IS THE
// DEFECT, and ITS FLOP IS RETIRED (save-state code 9'h11A is now a hole).
// The REP entry test is ONE ROW BANK SHARED between the byte and the word
// forms (`docs/V20UC.TXT:186`, `001.1010010?.00 <rep> A4,A5`), so 0094's
// `CX -> tmpb | ALU PASS tmpb` computed Z over the LOW EIGHT BITS of CX on a
// byte string op: `REP MOVSB` with CX = 0x0100 read zero and ran ZERO TIMES.
// The 29-bit ROM row has no width field, so the row cannot be the source.
// JCXZ's 0140 is the SAME row shape and was right only by the accident of its
// w-bit.  (sim/alu.h carries the derivation and the four refuted rivals; the
// C++ leg is `be4eb2c32f`.)
//
// CLAUSE 2 -- ABS is the multiply/divide unit's operand conditioning, and that
// unit's width is the INSTRUCTION's by construction (8x8->16 or 16x16->32;
// 16/8 or 32/16).  What licenses the clause is CONFINEMENT, checked against
// the artifact independently of any score: `[-1E-]` occurs in EXACTLY THREE
// ROWS in the whole ROM -- 0184 (F6/F7 /5 IMUL), 0198 (F6/F7 /7 IDIV) and
// 0292 (69,6B IMULI) -- all of them that path, and 0198 being the DIVIDE entry
// is what makes it a statement about the shared iterative unit rather than
// about multiply.  *FALSIFIER*: any ABS row outside the multiply/divide path
// refutes it outright.  The test is on `eff_op`, the RESOLVED operation, since
// `ALU OPC` reaches ABS through `opc_base = INC` plus a ModR/M reg of 6.  It
// reads `op8_eff`, the same post-`E` rendering `eff_op` itself reads, and it
// is the same bit the ABS ARM already reads for its sign capture
// (`v30u_eu_row.svh`'s `sign_neg_n`), so magnitude and sign now come from one
// place instead of two.
//
// NOTHING LATCHES THE WIDTH, and it MUST NOT: `80/81/83` latch `ALU OPC tmpa`
// at 003E and only load port A with the r/m operand at 003F, ONE ROW LATER.
// It is read combinationally, at the instant the consuming row evaluates, from
// the tag of the register the port takes its operand from.  Port A is ALWAYS
// tmpb (a fixed read port, so its tag is always in the OR); port B is the
// register the row's `Tmp` field names, where `Tmp == 3` selects the hardwired
// ZERO rail -- a 16-bit constant, not a register, so WORD.  One OR of two tag
// bits: no operation decode and no port selection.
//============================================================================
wire al_tag_b = (al_tmp == 2'd0) ? tmpa_byte
              : (al_tmp == 2'd1) ? tmpb_byte
              : (al_tmp == 2'd2) ? tmpc_byte : 1'b0;
wire s1w_al_width_byte = (eff_op == A_ABS) ? s1w_op8_eff : (tmpb_byte || al_tag_b);

// The datapath is 16 bits ALWAYS for the ADD-class ops; `byte` selects only
// where the flag taps sit (ledger, "ALU width").
wire ev_byte = s1w_al_width_byte && (eff_op != A_INC2) && (eff_op != A_DEC2);
wire [15:0] port_a = tmpb;
wire [15:0] port_b_raw = tmps[al_tmp];
wire [15:0] port_b = al_bitarm ? (port_b_raw & (16'd1 << al_bitn))
                               : port_b_raw;
wire [15:0] a_m = ev_byte ? {8'd0, port_a[7:0]} : port_a;
wire [15:0] b_m = ev_byte ? {8'd0, port_b[7:0]} : port_b;
wire        cin = psw[FCY];

// --- the BCD adjust unit ---------------------------------------------------
wire [15:0] adj_src = tmps[al_adjtmp];
wire [7:0]  adj_al  = adj_src[7:0];
wire adj_lo  = (adj_al[3:0] > 4'd9) || psw[FAC];
wire adj_hi  = (al_adjust == 2'd1) &&
               (((adj_al[7:4] > 4'd9) || psw[FCY]) ||
                ((adj_al[7:4] == 4'd9) && (adj_al[3:0] > 4'd9) && !psw[FAC]));
wire [7:0] adj_corr = (adj_lo ? 8'h06 : 8'h00) + (adj_hi ? 8'h60 : 8'h00);
wire adj_sub = (eff_op == A_SUB);
wire [8:0] adj_sum = adj_sub ? ({1'b0, adj_al} - {1'b0, adj_corr})
                             : ({1'b0, adj_al} + {1'b0, adj_corr});
wire [7:0] adj_val8 = (al_adjust == 2'd2) ? {4'd0, adj_sum[3:0]} : adj_sum[7:0];
wire [7:0] adj_ahi = adj_src[15:8];
wire [7:0] adj_bhi = port_b[15:8];
wire [7:0] adj_rhi = adj_sub ? (adj_ahi - adj_bhi - {7'd0, adj_sum[8]})
                             : (adj_ahi + adj_bhi + {7'd0, adj_sum[8]});
wire [15:0] adj_flags = szp({9'd0, adj_sum[7:0]}, 1'b1)
                      | (16'd1 << FCY) & {16{(al_adjust == 2'd2) ? adj_lo : adj_hi}}
                      | (16'd1 << FAC) & {16{adj_lo}}
                      | (16'd1 << FV) & {16{adj_sub
                          ? (((adj_al ^ adj_corr) & (adj_al ^ adj_sum[7:0])) & 8'h80) != 8'h00
                          : ((~(adj_al ^ adj_corr) & (adj_al ^ adj_sum[7:0])) & 8'h80) != 8'h00}};

// --- the combinational ops -------------------------------------------------
reg [16:0] ar_full;      // 17-bit so the carry-out is visible
reg [16:0] ar_m;
reg [15:0] ev_val;
reg [15:0] ev_flags;
reg [15:0] ev_mask;
reg        ev_commits;

wire [16:0] add_m = {1'b0, a_m} + {1'b0, b_m} +
                    {16'd0, ((eff_op == A_ADC) ? cin : 1'b0)};
wire [16:0] sub_m = {1'b0, a_m} - {1'b0, b_m} -
                    {16'd0, ((eff_op == A_SBB) ? cin : 1'b0)};
wire [15:0] add_f = port_a + port_b + {15'd0, ((eff_op == A_ADC) ? cin : 1'b0)};
wire [15:0] sub_f = port_a - port_b - {15'd0, ((eff_op == A_SBB) ? cin : 1'b0)};
wire add_cy = ev_byte ? add_m[8] : add_m[16];
wire sub_cy = ev_byte ? sub_m[8] : sub_m[16];
wire add_ac = (a_m[4] ^ b_m[4] ^ add_m[4]);
wire sub_ac = (a_m[4] ^ b_m[4] ^ sub_m[4]);
wire add_ov = ev_byte ? ((~(a_m[7] ^ b_m[7])) & (a_m[7] ^ add_m[7]))
                      : ((~(a_m[15] ^ b_m[15])) & (a_m[15] ^ add_m[15]));
wire sub_ov = ev_byte ? ((a_m[7] ^ b_m[7]) & (a_m[7] ^ sub_m[7]))
                      : ((a_m[15] ^ b_m[15]) & (a_m[15] ^ sub_m[15]));
wire [15:0] inc_m = b_m + 16'd1;
wire [15:0] dec_m = b_m - 16'd1;
wire inc_ac = (b_m[4] ^ 1'b0 ^ inc_m[4]) | (b_m[3:0] == 4'hF);
wire dec_ac = (b_m[3:0] == 4'h0);
wire inc_ov = ev_byte ? (b_m[7:0] == 8'h7F) : (b_m == 16'h7FFF);
wire dec_ov = ev_byte ? (b_m[7:0] == 8'h80) : (b_m == 16'h8000);
wire [15:0] neg_m = 16'd0 - b_m;

always @* begin
    ar_full = 17'd0;
    ar_m    = 17'd0;
    ev_val  = 16'd0;
    ev_flags= 16'd0;
    ev_mask = 16'd0;
    ev_commits = 1'b1;
    case (eff_op)
        A_ADD, A_ADC: begin
            ar_m = add_m; ev_val = add_f; ev_mask = ARITH_MASK;
            ev_flags = szp({1'b0, add_m[15:0]}, ev_byte);
            ev_flags[FCY] = add_cy;
            ev_flags[FAC] = add_ac;
            ev_flags[FV]  = add_ov;
        end
        A_SUB, A_SBB, A_CMP: begin
            ar_m = sub_m; ev_val = sub_f; ev_mask = ARITH_MASK;
            ev_flags = szp({1'b0, sub_m[15:0]}, ev_byte);
            ev_flags[FCY] = sub_cy;
            ev_flags[FAC] = sub_ac;
            ev_flags[FV]  = sub_ov;
            if (eff_op == A_CMP) ev_commits = 1'b0;
        end
        A_AND: begin
            ev_val = port_a & port_b; ev_mask = ARITH_MASK;
            ev_flags = szp({1'b0, a_m & b_m}, ev_byte);
        end
        A_OR: begin
            ev_val = port_a | port_b; ev_mask = ARITH_MASK;
            ev_flags = szp({1'b0, a_m | b_m}, ev_byte);
        end
        A_XOR: begin
            ev_val = port_a ^ port_b; ev_mask = ARITH_MASK;
            ev_flags = szp({1'b0, a_m ^ b_m}, ev_byte);
        end
        A_INC: begin
            ev_val = port_b + 16'd1;
            ev_mask = (16'd1<<FP)|(16'd1<<FAC)|(16'd1<<FZ)|(16'd1<<FS)|(16'd1<<FV);
            ev_flags = szp({1'b0, inc_m}, ev_byte);
            ev_flags[FAC] = inc_ac;
            ev_flags[FV]  = inc_ov;
        end
        A_DEC: begin
            ev_val = port_b - 16'd1;
            ev_mask = (16'd1<<FP)|(16'd1<<FAC)|(16'd1<<FZ)|(16'd1<<FS)|(16'd1<<FV);
            ev_flags = szp({1'b0, dec_m}, ev_byte);
            ev_flags[FAC] = dec_ac;
            ev_flags[FV]  = dec_ov;
        end
        A_INC2: begin ev_val = port_b + 16'd2; ev_mask = 16'd0; end
        A_DEC2: begin ev_val = port_b - 16'd2; ev_mask = 16'd0; end
        A_NOT:  begin ev_val = ~port_b;        ev_mask = 16'd0; end
        A_NEG:  begin
            ev_val = 16'd0 - port_b; ev_mask = ARITH_MASK;
            ev_flags = szp({1'b0, neg_m}, ev_byte);
            ev_flags[FCY] = (ev_byte ? (neg_m[7:0] != 8'd0) : (neg_m != 16'd0));
            ev_flags[FAC] = (b_m[4] ^ neg_m[4]);
            ev_flags[FV]  = ev_byte ? (b_m[7:0] == 8'h80) : (b_m == 16'h8000);
        end
        A_ABS: begin
            // [-1E-]: magnitude.  At byte width only the low lane is replaced.
            if (ev_byte) begin
                ev_val = port_b[7] ? {port_b[15:8], (8'd0 - port_b[7:0])}
                                   : port_b;
            end else begin
                ev_val = port_b[15] ? (16'd0 - port_b) : port_b;
            end
            ev_mask = 16'd0;
        end
        A_ADJD, A_ADJA, A_BIT: begin ev_val = port_b; ev_mask = 16'd0; end
        default: begin   // PASS and everything unlisted
            ev_val = port_b; ev_mask = ARITH_MASK;
            ev_flags = szp({1'b0, b_m}, ev_byte);
        end
    endcase
    // F30 -- THE ADJUST UNIT WAS COMPUTED AND DISCARDED.  `alu_eval` takes the
    // ARMED path BEFORE the ordinary op table (`sim/alu.cpp:127`): an ADJD/ADJA
    // armed by the previous row REPLACES the ADD/SUB pass with one pass of the
    // decimal corrector.  The EU built `adj_lo`/`adj_hi`/`adj_corr`/`adj_sum`/
    // `adj_val8`/`adj_rhi`/`adj_flags` faithfully -- and then never selected
    // them, so all three outputs sat in this module's `_unused_eu` sink and
    // `27`/`2F`/`37`/`3F` came out as the raw `tmpb + ONES` (`27 idx 3`:
    // exp e369, got e368 -- the correction, exactly, missing).
    //
    // The corrector sits on the LOW LANE of port B only; the HIGH lane goes
    // through raw and the ONE carry chain runs the whole 16 bits, which is what
    // `adj_rhi` already computes.
    if ((al_adjust != 2'd0) && ((eff_op == A_ADD) || (eff_op == A_SUB))) begin
        ev_val   = {adj_rhi, adj_val8};
        ev_flags = adj_flags;
        ev_mask  = ARITH_MASK;
        ev_commits = 1'b1;
    end
end

// --- the ONE shared iterative stepper --------------------------------------
// MUL (shift-add), DIV (restoring), ROL12 and the shift/rotate family are the
// SAME unit stepped once per clock; no lpm_divide, no per-op datapath.
wire        it_byte = s1w_al_width_byte;
wire [15:0] it_a    = it_byte ? {8'd0, tmpb[7:0]} : tmpb;
wire [15:0] it_bop  = tmps[al_tmp];
wire [15:0] it_mask = it_byte ? 16'h00FF : 16'hFFFF;
wire        it_msb  = it_byte ? it_a[7] : it_a[15];
wire        it_lsb  = it_a[0];
reg  [15:0] s1w_it_val;      // the SIGMA the step presents
reg  [15:0] s1w_it_tmpa;     // the multiplier / quotient register after the step
reg  [15:0] s1w_it_flags;
reg  [15:0] s1w_it_fmask;
reg         s1w_it_writes_tmpa;

// MUL
wire [15:0] mul_mplier = it_byte ? {8'd0, tmpa[7:0]} : tmpa;
wire [15:0] mul_mcand  = it_byte ? {8'd0, it_bop[7:0]} : it_bop;
wire [16:0] mul_sum    = {1'b0, it_a} +
                         (mul_mplier[0] ? {1'b0, mul_mcand} : 17'd0);
wire        mul_cout   = it_byte ? mul_sum[8] : mul_sum[16];
wire [15:0] mul_hi     = it_byte
                       ? {8'd0, {mul_cout, mul_sum[7:1]}}
                       : {mul_cout, mul_sum[15:1]};
wire [15:0] mul_lo     = it_byte
                       ? {8'd0, {mul_sum[0], mul_mplier[7:1]}}
                       : {mul_sum[0], mul_mplier[15:1]};
// DIV (restoring)
wire [15:0] div_divisor = it_byte ? {8'd0, it_bop[7:0]} : it_bop;
wire [15:0] div_lo0     = it_byte ? {8'd0, tmpa[7:0]} : tmpa;
// F32 -- THE RESTORING DIVIDER'S COMPARE IS ONE BIT WIDER THAN ITS OPERANDS.
// `alu.cpp::kDiv` computes `hi = (a << 1) | (lo >> (w-1))` in a uint32_t and
// does NOT mask it before `if (hi >= divisor)`: the bit shifted OUT of the high
// half is exactly what decides the subtract, and it is the whole point of a
// restoring step.  This shifted `it_a[w-1]` away, so every dividend whose high
// half reached the top bit took the wrong branch.  MEASURED: `F6.6 idx 2`
// (0x9151 / 179) `exp ax=94cf got 5100`.
wire [16:0] div_hi0     = it_byte
                        ? {8'd0, it_a[7:0], div_lo0[7]}
                        : {it_a[15:0], div_lo0[15]};
wire [15:0] div_lo1     = (div_lo0 << 1) & it_mask;
wire        div_fits    = (div_hi0 >= {1'b0, div_divisor});
wire [15:0] div_hi1     = div_fits ? (div_hi0[15:0] - div_divisor)
                                   : div_hi0[15:0];
wire [15:0] div_lo2     = div_fits ? (div_lo1 | 16'd1) : div_lo1;
// shifts / rotates
reg  [15:0] sh_r;
reg         sh_cy;
always @* begin
    sh_cy = 1'b0;
    sh_r  = 16'd0;
    case (eff_op)
        A_ROL: begin sh_cy = it_msb; sh_r = ((it_a << 1) | {15'd0, it_msb}) & it_mask; end
        A_ROR: begin sh_cy = it_lsb; sh_r = ((it_a >> 1) | (it_lsb ? (it_byte ? 16'h0080 : 16'h8000) : 16'd0)) & it_mask; end
        A_RCL: begin sh_cy = it_msb; sh_r = ((it_a << 1) | {15'd0, cin}) & it_mask; end
        A_RCR: begin sh_cy = it_lsb; sh_r = ((it_a >> 1) | (cin ? (it_byte ? 16'h0080 : 16'h8000) : 16'd0)) & it_mask; end
        A_SHL, A_SHL6: begin sh_cy = it_msb; sh_r = (it_a << 1) & it_mask; end
        A_SHR: begin sh_cy = it_lsb; sh_r = (it_a >> 1) & it_mask; end
        A_SAR: begin sh_cy = it_lsb; sh_r = ((it_a >> 1) | (it_msb ? (it_byte ? 16'h0080 : 16'h8000) : 16'd0)) & it_mask; end
        default: ;
    endcase
end
wire sh_left = (eff_op == A_ROL) || (eff_op == A_RCL) ||
               (eff_op == A_SHL) || (eff_op == A_SHL6);
wire sh_rmsb = it_byte ? sh_r[7] : sh_r[15];
wire sh_rmsb1= it_byte ? sh_r[6] : sh_r[14];
wire sh_v    = sh_left ? (sh_rmsb != sh_cy) : (sh_rmsb != sh_rmsb1);
// THE SHIFTER IS TWO 8-BIT LANES FED BY ONE FEEDBACK BIT (alu.cpp).
wire sh_wrap = (eff_op == A_ROR) || (eff_op == A_RCR);
wire sh_fb   = sh_wrap ? sh_r[7] : 1'b0;
wire [7:0] sh_hi = sh_left ? {tmpb[14:8], tmpb[7]}
                           : {sh_fb, tmpb[15:9]};

always @* begin
    s1w_it_val   = 16'd0;
    s1w_it_tmpa  = tmpa;
    s1w_it_flags = 16'd0;
    s1w_it_fmask = 16'd0;
    s1w_it_writes_tmpa = 1'b0;
    case (eff_op)
        A_MUL: begin
            s1w_it_val  = it_byte ? {tmpb[15:8], mul_hi[7:0]} : mul_hi;
            s1w_it_tmpa = it_byte ? {tmpa[15:8], mul_lo[7:0]} : mul_lo;
            s1w_it_writes_tmpa = 1'b1;
        end
        A_DIV: begin
            s1w_it_val  = it_byte ? {tmpb[15:8], div_hi1[7:0]} : div_hi1;
            s1w_it_tmpa = it_byte ? {tmpa[15:8], div_lo2[7:0]} : div_lo2;
            s1w_it_writes_tmpa = 1'b1;
        end
        A_ROL12: begin
            s1w_it_val = {tmpb[14:0], tmpb[11]};
        end
        default: begin
            s1w_it_flags[FCY] = sh_cy;
            s1w_it_flags[FV]  = sh_v;
            if ((eff_op == A_SHL) || (eff_op == A_SHR) ||
                (eff_op == A_SAR) || (eff_op == A_SHL6)) begin
                s1w_it_flags = s1w_it_flags | szp({1'b0, sh_r}, it_byte);
                s1w_it_fmask = ARITH_MASK;
            end else begin
                s1w_it_fmask = (16'd1 << FCY) | (16'd1 << FV);
            end
            s1w_it_val = it_byte ? {sh_hi, sh_r[7:0]} : sh_r;
        end
    endcase
end

// SIGMA: what the row's Source1 [-14-] presents.
wire [15:0] sigma = al_eaconst ? al_eaval
                  : is_iter ? (al_spent ? tmpb : s1w_it_val)
                            : ev_val;
wire [15:0] s1w_sig_flags = is_iter ? s1w_it_flags : ev_flags;
wire [15:0] s1w_sig_mask  = al_eaconst ? 16'd0
                      : is_iter ? (al_spent ? 16'd0 : s1w_it_fmask)
                                : ev_mask;
wire        s1w_sig_commits = al_eaconst ? 1'b1 : (is_iter ? 1'b1 : ev_commits);
// ...AND SIGMA CARRIES THE WIDTH THE ALU WORKED AT, so a `SIGMA -> tmp`
// transfer PROPAGATES the tag instead of losing it.  It is the ALU's OWN
// width and NOT a property of what `sigma` happens to mux -- an `ea_const`
// row is deliberately NOT special-cased here, exactly as `exec_impl.h` does
// not special-case it (`ctx.byte = alu_width_byte(...)`, unconditional, while
// `alu_eval` returns the EA early).
wire        sig_byte    = s1w_al_width_byte;

//============================================================================
// SOURCE / DESTINATION MUXES
//============================================================================
wire [15:0] flags_rd = (psw & PSW_WRITABLE) | PSW_FORCED;

// state.h::rb16 -- the byte-register read is 16 bits wide
function automatic [15:0] rb16(input [2:0] code, input [15:0] pair);
    rb16 = code[2] ? {pair[7:0], pair[15:8]} : pair;
endfunction

// A byte-coded FE/FF-group register feeding the E-tagged stack-write row
// supplies its unswapped parent word on silicon.  This is distinct from an
// ordinary byte-register read: the row is M -> OPR while issuing MEMW SS.
// The current group microcode page excludes immediate and fixed-register PUSH
// rows, whose unused M decode metadata can otherwise have the same values.
wire m_modrm_stack_word = (upc_page == 3'd3) &&
                          (m_kind == OK_REG) && m_byte && s1w_e_e &&
                          s1w_row_is_wr && (row_seg == 3'd2) &&
                          s1w_e_have1 && (s1w_e_s1 == 5'd19) && (s1w_e_d1 == 5'd6);
// The FE group's undocumented register-direct jump rows have the same
// physical exception.  Although the ModR/M metadata is byte-coded, the row
// is `M -> PC; FLUSH` and silicon redirects to the whole parent register
// (FE E6 with DW=7940 goes to 7940, not the rb16 view 4079).
wire m_modrm_pc_word = (upc_page == 3'd3) &&
                       (m_kind == OK_REG) && m_byte &&
                       s1w_e_have1 && (s1w_e_s1 == 5'd19) && (s1w_e_d1 == 5'd4) &&
                       (s1w_e_ictl == I_FLUSH);
wire m_modrm_parent_word = m_modrm_stack_word || m_modrm_pc_word;
// THE PARENT-WORD INDEX IS A FULL-WIDTH REGISTER-FILE ADDRESS, NAMED.
//
// A byte-register code is 3 bits: 0-3 select the LOW byte of gpr[0..3] and 4-7
// the HIGH byte of the SAME four words.  The PARENT word is therefore always
// `gpr[code[1:0]]` and `rb16`'s swap is what `code[2]` selects -- the top bit
// addresses no fifth word, it picks a half.  `gpr` is an 8-entry array, so a
// bare `[1:0]` subscript reaches four of its eight elements and Quartus says so
// (10027); the warning is CORRECT about the reach and only wrong about it being
// a mistake.  These two wires say the reach in the index's own declared width.
//
// ⚠ IT HAS TO BE A NAMED NET.  `gpr[{1'b0, m_idx[1:0]}]` written INLINE still
// warns, and so does `gpr[m_idx & 3'd3]`: Quartus 17.1 runs this check after
// constant-folding the expression, so a constant-zero MSB buys nothing.  A
// declared 3-bit net is what the check reads instead.  MEASURED on a standalone
// `quartus_map` (Cyclone V, 5CSEBA6U23I7) over six index forms -- inline concat
// WARNS, `& 3'd3` WARNS, named wire CLEAN, named `always @*` reg CLEAN, explicit
// 4-way mux CLEAN, plain `gpr[m_idx]` CLEAN.  Do not "simplify" these back
// inline; the warning returns.
//
// Pure wiring: same element selected on every input, no mux and no logic added.
wire [2:0] m_par_idx = {1'b0, m_idx[1:0]};
wire [2:0] r_par_idx = {1'b0, r_idx[1:0]};
wire [15:0] m_reg_rd = !m_byte              ? gpr[m_idx]
                       : m_modrm_parent_word ? gpr[m_par_idx]
                                             : rb16(m_idx, gpr[m_par_idx]);
wire [15:0] m_rd = (m_kind == OK_REG)  ? m_reg_rd
                 : (m_kind == OK_SREG) ? sreg[m_idx[1:0]]
                 : (m_kind == OK_MEM)  ? opr : 16'd0;
wire [15:0] r_rd = (r_kind == OK_REG)  ? (r_byte ? rb16(r_idx, gpr[r_par_idx])
                                                 : gpr[r_idx])
                 : (r_kind == OK_SREG) ? sreg[r_idx[1:0]]
                 : (r_kind == OK_MEM)  ? opr : 16'd0;

wire [15:0] dirsz = (s1w_op8_eff ? (psw[FDIR] ? 16'hFFFF : 16'h0001)
                             : (psw[FDIR] ? 16'hFFFE : 16'h0002));

//----------------------------------------------------------------------------
// THE SOURCE1 CLASSIFICATION.  `s1_byte` and `s1_wbyte` are DIFFERENT
// PROPERTIES, which is why the second is not just a copy of the first:
//
//   `s1_byte` is LANE REPLICATION -- the rail drives its eight bits on BOTH
//   halves of the source bus, so an H-half write (Dest1 22/23, which takes
//   bits 15:8) picks the same byte up.  Only Q and CONST do that.  It had NO
//   READER here and the row rebuilt the same expression inline; it is the
//   reader now, and the two cannot drift apart any more.
//
//   `s1_wbyte` is the DATUM WIDTH -- how many of the bits the rail presents
//   are significant.  It is what the ALU's flag taps and the iterative unit's
//   carry chain follow (`al_width_byte`).
//
// THE CRITERION IS ONE SENTENCE, the sibling-lane law of `rb16` generalised:
//
//     A RAIL IS TAGGED BYTE WHEN ITS UPPER LANE CARRIES SOMETHING THAT IS NOT
//     PART OF THIS DATUM.
//
// A rail whose upper lane holds a CORRECT extension -- a zero, a sign, a
// constant's leading zeroes -- presents a valid 16-bit number and is WORD,
// however small the number is.  "SMALL" IS NOT "BYTE": CONST, ZEROS, ONES and
// PFXCNT are clean 16-bit values.  Only four rails carry a foreign upper lane:
//
//   7     Q       the prefetched byte, driven on both lanes (that is `s1_byte`)
//   16    AL:AH   the HIGH byte read through the 8-bit rotator -- AH in the low
//                 lane with AL riding along as the sibling.  Its ROM consumers
//                 take the low lane as the datum (001B, 007C, 01DE, and
//                 018C/019D where it is the byte divide's dividend high half).
//   18/19 R / M   a BYTE operand read: the sibling byte sits on the unused
//                 lane, which is `rb16` itself.  The decoder's own width, and
//                 the only encodings it parameterises.
//   6     OPR     when a BYTE bus cycle filled it, the upper lane is the other
//                 half of the bus.  This is what makes CMPSB/SCASB compare at
//                 byte width (00A0/00A2 `OPR -> tmpb/tmpa`).
//
// The temps (12-14) and SIGMA (20) PROPAGATE the tag of what produced them.
// Everything else is WORD.
//
// The two disagree on CONST, and that is not a contradiction: `s1_byte` is
// read ONLY by the H-half writes, and NO ROM ROW EVER DRIVES AN H-HALF WRITE
// FROM CONST (measured: zero `CONST -> tmp?H` rows), so CONST's lane behaviour
// is unobservable and carries no evidence either way.  The datum criterion
// decides it, and it decides it WORD.
//----------------------------------------------------------------------------
reg  [15:0] s1w_s1_val;
reg         s1w_s1_byte;
reg         s1w_s1_wbyte;
always @* begin
    s1w_s1_byte  = 1'b0;
    s1w_s1_wbyte = 1'b0;                 // WORD unless the case says otherwise
    case (s1w_e_s1)
        5'd0,5'd1,5'd2,5'd3: s1w_s1_val = sreg[s1w_e_s1[1:0]];
        5'd4:  s1w_s1_val = pc;
        5'd6:  begin s1w_s1_val = opr;  s1w_s1_wbyte = opr_byte; end
        5'd7:  begin s1w_s1_val = {8'd0, q_byte}; s1w_s1_byte = 1'b1; s1w_s1_wbyte = 1'b1; end
        5'd8:  s1w_s1_val = dirsz;
        5'd9:  s1w_s1_val = 16'd0;
        5'd10: s1w_s1_val = {8'd0, pfxcnt_eff};        // F22
        5'd12: begin s1w_s1_val = tmpa; s1w_s1_wbyte = tmpa_byte; end
        5'd13: begin s1w_s1_val = tmpb; s1w_s1_wbyte = tmpb_byte; end
        5'd14: begin s1w_s1_val = tmpc; s1w_s1_wbyte = tmpc_byte; end
        5'd15: s1w_s1_val = flags_rd;
        5'd16: begin s1w_s1_val = {gpr[R_AW][7:0], gpr[R_AW][15:8]}; s1w_s1_wbyte = 1'b1; end
        5'd17: s1w_s1_val = count;
        5'd18: begin s1w_s1_val = r_rd; s1w_s1_wbyte = r_byte; end
        5'd19: begin s1w_s1_val = m_rd; s1w_s1_wbyte = m_byte; end
        5'd20: begin s1w_s1_val = sigma; s1w_s1_wbyte = sig_byte; end
        5'd21: s1w_s1_val = 16'hFFFF;
        5'd22: s1w_s1_val = {8'd0, opc_reg & 8'h38};
        5'd23: begin s1w_s1_val = {10'd0, r_constval}; s1w_s1_byte = 1'b1; end
        default: s1w_s1_val = (s1w_e_s1 >= 5'd24) ? gpr[s1w_e_s1[2:0]] : 16'd0;
    endcase
end

// Source2, the SAME classification: ONES (0), ZEROS (6) and the 16-bit
// register-file reads (>=8) are WORD; SIGMA (4) propagates; Q (5) is the queue
// byte; R (7) is the decoder's own operand width.
reg [15:0] s1w_s2_val;
reg        s1w_s2_wbyte;
always @* begin
    s1w_s2_wbyte = 1'b0;
    case (s1w_e_s2)
        4'd0: s1w_s2_val = 16'hFFFF;
        4'd4: begin s1w_s2_val = sigma; s1w_s2_wbyte = sig_byte; end
        4'd5: begin s1w_s2_val = {8'd0, q_byte}; s1w_s2_wbyte = 1'b1; end
        4'd6: s1w_s2_val = 16'd0;
        4'd7: begin s1w_s2_val = r_rd; s1w_s2_wbyte = r_byte; end
        default: s1w_s2_val = (s1w_e_s2 >= 4'd8) ? gpr[s1w_e_s2[2:0]] : 16'd0;
    endcase
end

//============================================================================
// THE ROW'S OWN TRANSFERS  (family A, U2 pass 3)
//============================================================================
// exec_impl.h::run_micro does the two parallel transfers FIRST and issues the
// row's bus cycle AFTERWARDS, off `m_.ind`.  So the address a row posts is the
// IND THE ROW ITSELF JUST WROTE whenever the row writes IND -- which is how
// every non-ModR/M address in the ROM is formed (`50`: `SIGMA -> SP  SIGMA ->
// IND  E  CTL MEMW SS`; the ModR/M forms get IND from the loader, which is why
// they were already green and this was invisible for two passes).
//
// The EU already had exactly this rule for the WRITE DATA (`opr_now`, "the
// value this row is about to put there").  It is the same rule; it was applied
// to one destination only.  `s1_now` / `s2_now` are the two transfer values,
// and dest2 is written after dest1, so dest2 wins if both name IND.
// ...and the ACT decode needs the same live OPR (F21).  It is combinational,
// so it does not get the step's blocking write for free: it reconstructs the
// `F` delivery the row is about to make.  ONE expression, both sides (F11).
// ...and when the completion is the LOOKAHEAD itself (`nr_have`'s
// `eu_rd_done_n`) the word is not in the store yet -- block (a) puts it there
// in the same edge the step then pops it, so the act decode must read
// `eu_rdata_n` directly.  `C3`'s `00F3 OPR -> PC  F E  CTL FLUSH` redirects
// off exactly that word, and read the STALE PC without this.
wire [15:0] opr_live = (s1w_e_f && (rdq_n != 2'd0)) ? rdq0
                     : (s1w_e_f && eu_rd_done_n)    ? eu_rdata_n
                     : opr;
wire [15:0] s1_now = (s1w_e_s1 == 5'd7) ? {8'd0, q_byte}
                   : (s1w_e_s1 == 5'd6) ? opr_live
                   : s1w_s1_val;
wire [15:0] s2_now = (s1w_e_s2 == 4'd5) ? {8'd0, q_byte} : s1w_s2_val;
// The CMP suppression: a SIGMA source that does not commit drives nothing.
wire wr_ind1 = s1w_e_have1 && (s1w_e_d1 == 5'd5) &&
               !((s1w_e_s1 == 5'd20) && !s1w_sig_commits);
wire wr_ind2 = s1w_e_have2 && (s1w_e_d2 == 2'd2) &&
               !((s1w_e_s2 == 4'd4) && !s1w_sig_commits);
wire [15:0] ind_now = wr_ind2 ? s2_now : wr_ind1 ? s1_now : ind;

// F14, the same rule for the REDIRECT.  `exec_impl.h`'s CTL block calls
// `biu_.flush(m_.sreg[kCS], m_.pc)` AFTER the transfers, so a row that writes
// PC (or CS) and flushes on the same row redirects to the value IT JUST WROTE
// -- which is every taken jump in the ROM (`EB`: `015B  SIGMA -> PC  E  CTL
// FLUSH`).  Reading the register gave the PRE-jump PC, so the refill fetched
// from `target - disp`.  The queue pops a row makes also advance PC, and they
// happen before the transfer, exactly as in `rd_src1`.
wire [15:0] pc_after_q = pc + {15'd0, s1w_row_q1} + {15'd0, s1w_row_q2};
wire wr_pc1 = s1w_e_have1 && (s1w_e_d1 == 5'd4) &&
              !((s1w_e_s1 == 5'd20) && !s1w_sig_commits);
wire wr_cs1 = s1w_e_have1 &&
              ((s1w_e_d1 == {3'd0, SR_CS}) ||
               ((s1w_e_d1 == 5'd18) && (r_kind == OK_SREG) &&
                (r_idx[1:0] == SR_CS)) ||
               ((s1w_e_d1 == 5'd19) && (m_kind == OK_SREG) &&
                (m_idx[1:0] == SR_CS))) &&
              !((s1w_e_s1 == 5'd20) && !s1w_sig_commits);
wire [15:0] pc_now = wr_pc1 ? s1_now : pc_after_q;
wire [15:0] cs_now = wr_cs1 ? s1_now : sreg[SR_CS];

wire        ghost_uses_ea = (ea_residue != tmpa);
// -- `ghost_uses_mul_hi` DELETED (F-A, `ghost_preflash20_prereg_2026-08-12.md`
// §3).  It read `(pla3_native(pe_opc_reg) == 14'h0104) && !tmpc[15]` -- the
// immediate-IMUL native PLA class (69/6B) -- and substituted `tmpa & opr` for
// the whole ghost offset.  It was fitted on the v1 `mc2` banks that SUP-1
// retired, and wave-4 measured it INERT on 654 replayed seeds (V3 scored
// BYTE-IDENTICALLY to V2), so nothing could tell whether it was right.
//
// `ghost_launch_law_results_2026-08-11.md` §3.2 found the population that
// reaches it, and the relocation landing (`093efbcfc2`) measured WHY it had
// been invisible: on the directed `imul` leg the CHIP's rail is `TMPA` =
// 0x1100 and this arm's value `tmpa & opr` is 0x1000, which is ALSO `E3 & SP`
// -- the two are indistinguishable on every population that came before.
// Where it fires the chip takes the ordinary stale rail, so the arm is not a
// second mechanism at all: it is a coincidence that was written down.
//
// The class is no longer excluded from `eu_ghost_row` either, so an `imul`
// predecessor's ghost is decorated by the launch law like every other one.
// ONE arm removed, no opcode named, no replacement.  MEASURED: the law's own
// 13-leg population goes 114/208 -> 128/208 with `imul` 2/16 -> 16/16 and
// every other leg EXACTLY on its number, the directed cell 384 -> 398 (+14,
// -0), and ZERO of the 264 replayed seeds move.
// The retained EA rail is a word-address rail.  A scratch/SIGMA residue keeps
// its low bit; a retained ModR/M address normally does not.  MOV-to-segment
// retains the EA rail itself, including its measured low bit (t30-raw/13).
wire [15:0] ghost_ea_off = (pe_opc_reg == 8'h8e) ? ea_residue
                                                  : {ea_residue[15:1], 1'b0};
wire [15:0] ghost_off = ghost_uses_ea ? ghost_ea_off : tmpa;
wire [13:0] ghost_next_pla = pla3_native(q_byte);
wire ghost_next_byte = q_ripe &&
                       (pla3_byte_only(ghost_next_pla) ||
                        (pla3_w_from_bit0(ghost_next_pla) && !q_byte[0]));
// WAVE-4 / V1 -- `ghost_relax` DELETED.  The AND IS UNCONDITIONAL.
//
// It used to read
//    ghost_relax = eu_ghost_full ? FFFF
//                : eu_ghost_idle ? ((pe_op8 ? C000 : 8000) |
//                                   (ghost_next_byte ? 0080 : 0000))
//                : 0000;
//    ghost_bus_off = ... : (ghost_off & (gpr[R_SP] | ghost_relax));
// -- a four-constant mask table whose whole job was to SUPPRESS the AND on
// selected bits.  M10's register-file solve (14 freezes, 3,208 named
// expressions, NO free parameter, expected accidental fits 0.003/freeze)
// measured the opposite from outside the fit: on `fz2c/410008`,
// `fz2e/519016` and `fz2e/520040` the CHIP performs the AND and the core does
// not, and `SS:(ghost_off & SP)` -- evaluated with THIS module's own
// `ghost_off` -- reproduces the chip exactly at freezes -3 and -2.  Every
// chip-side fit on those seats is a wired AND; not one is a single term and
// not one is an OR.
//
// A wired-AND of two live drivers on one internal bus is a simple system.
// A four-constant relax mask is what you write when you have not found it.
//
// WHAT WAS MEASURED AND WHAT WAS NOT -- the ladder, so the next sitting does
// not re-run it (`fz2_w4_ghostaddr_results_2026-08-10.md` §2).  Four cumulative
// variants were built and scored on 654 replayed seeds:
//
//   V1  this one, `ghost_relax` deleted                    +2 closed,  0 LOST
//   V2  V1 + the `(eu_ghost_idle && !q_ripe) ? SP` arm     +2 closed,  1 LOST
//   V3  V2 + the `ghost_uses_mul_hi` arm  -- ONE TERM      identical to V2
//   V4  V3 + the `pe_opc_reg == 8'h8e` case               identical to V2
//
// V3 and V4 score BYTE-IDENTICALLY to V2, so `ghost_uses_mul_hi` (the 0104
// PLA class, fitted on the v1 `mc2` banks that SUP-1 retired) and the `8E`
// special case are BOTH INERT on this corpus.  They are left standing because
// "inert on 654 seeds" is not "dead", and deleting a case on the strength of a
// population that never reaches it would be the same mistake in the other
// direction.  The seed V2 loses is `fz2c/410034`.
//
// THE AND IS NOT UNIVERSAL AND THIS LANDING DOES NOT CLAIM IT IS.  M10 §5.2
// measures `fz2e/530034` performing NO and at all and taking a different rail,
// and `fz2e/526054` forking on the SEGMENT with identical offsets.  The two
// free choices left standing are WHICH RAIL and WHETHER THE AND HAPPENS; only
// the second is settled here, and only in the direction "not by a mask".
//
// -- THE DECORATION IS TAKEN AT **LAUNCH**, SO WAVE-4'S V2 ARM IS DELETED. --
//
// `(eu_ghost_idle && !q_ripe) ? gpr[R_SP]` used to sit between the two arms
// below.  It was a FITTED approximation of the one case the die decides at the
// T1 and not here, and it fires in the wrong cells:
// `ghost_pred_cell_results_2026-08-11.md` §5 measures it taking `SP` on 2 of
// the 16 cells of every `D3` leg with no dependence on byte parity at all,
// while M10-SYS §4.5 has it silent on `524030` and `529067`, *"where that
// arm's answer is the right one and the arm did not fire"*.
//
// `ghost_launch_law_results_2026-08-11.md` names the mechanism it was
// approximating.  With `dGR` = the clocks from THIS row going current to the
// BIU launching the cycle,
//
//     dGR == 0  ->  SS:SP         the posting micro-row's own stack drive
//     dGR == 1  ->  stale & SP    BOTH drivers on the rail -- the wired AND
//     dGR >= 2  ->  stale         the row has released; only the stale rail
//
// -- 200/200 on the directed board cells, derivation 112, DISJOINT validation
// 56, multiply 32, with the map frozen before the last two were scored.  TWO
// DRIVERS, one monotone quantity: the `SP` driver is on for the row's own
// clock and the next, the stale rail re-asserts one clock after the row goes
// current, and the AND is their one-clock overlap.  No modulus, no mask table,
// no opcode named.
//
// WHAT STAYS HERE IS WAVE-4'S V1 -- the UNCONDITIONAL AND -- and it stays as
// the POSTED value on purpose: `acc_phys`, `acc_phys2`, `acc_split`,
// `eu_split`, `rq_ube`, `rq_odd`, `eu_word` and `eu_bs` are all computed from
// this expression, and a relocation that also moved THEM would be two
// behavioural changes measured as one.  Only the ADDRESS THE BUS LAUNCHES
// moves, and it moves in the BIU, at the clock the die takes it.
//
// `ghost_uses_mul_hi` IS GONE (F-A) -- see its epitaph at the top of this
// block.  What is left is ONE expression for every ghost, with no class named.
wire [15:0] ghost_bus_off = ghost_off & gpr[R_SP];
wire [15:0] acc_off  = s1w_ghost_read_stale_alu ? ghost_bus_off
                       : s1w_row_is_wb          ? wb_ea : ind_now;
wire [19:0] acc_phys_base = s1w_acc_io ? {4'd0, acc_off}
                                   : ({acc_segv, 4'd0} + {4'd0, acc_off});
wire [19:0] ghost_stack_phys = {acc_segv, 4'd0} + {4'd0, ind_now};
// An odd stack POP has already launched its first byte from SS:SP when the
// stale address reaches the second half.  Even-stack ghosts launch directly
// from the stale value.  The real stack address, not the stale pin value,
// decides whether the word is split.
wire [19:0] acc_phys = (s1w_ghost_read_stale_alu && ghost_stack_phys[0] &&
                        eu_ghost_stack_first)
                     ? ghost_stack_phys : acc_phys_base;
// On an idle odd-stack hand-off the first byte sees the contended stale
// address, while the second byte sees the un-contended scratch rail.  This is
// the same split already selected from the real stack address above; no extra
// history is needed.
wire [19:0] acc_phys2= (s1w_ghost_read_stale_alu && eu_ghost_idle &&
                        !ghost_uses_ea && ghost_stack_phys[0])
                      ? (({acc_segv, 4'd0} + {4'd0, ghost_off}) + 20'd1)
                      : s1w_ghost_read_stale_alu ? (acc_phys_base + 20'd1)
                     : s1w_acc_io ? {4'd0, acc_off + 16'd1}
                              : ({acc_segv, 4'd0} + {4'd0, acc_off + 16'd1});
// F-B (`ghost_preflash20_prereg_2026-08-12.md` §2) -- THE GHOST'S SPLIT IS
// TAKEN FROM THE `dGR == 0` DRIVER, AND THE TWO-CASE RULE IS DELETED.
//
// This used to read
//     ghost_read_stale_alu
//       ? ((ghost_uses_ea || ghost_uses_mul_hi) ? acc_phys_base[0]
//                                               : ghost_stack_phys[0])
// -- i.e. on the `ghost_uses_ea` rails the pair reservation was taken from the
// POSTED offset's low bit, and on the others from the real stack address.
//
// `dGR` is the clocks from this row going current to the BIU LAUNCHING the
// cycle.  **At the post the row IS current and the launch has not happened, so
// `dGR == 0` here by definition**, and the law's `dGR == 0` row is `SS:SP` --
// the posting micro-row's own stack drive.  The pair is reserved at the post,
// so it is reserved from the `dGR == 0` driver, which `ghost_stack_phys`
// already is (`{acc_segv,4'd0} + ind_now`, and `ind_now` is measured equal to
// `gpr[R_SP]` on every ghost event in the diagnosed population).  One
// expression for every rail; the second case is deleted, not replaced.
//
// WHAT MADE THIS VISIBLE.  The launch relocation moved the ADDRESS to the
// launch and left the SHAPE at the post, and its own §2.1 claimed the posted
// expression did not move.  It did, wherever wave-4's deleted V2 arm used to
// fire: on `fz2e/528010` the posted value went from `SP` = 0x9537 (ODD) to the
// AND = 0x9504 (EVEN), the ghost read stopped splitting, and ONE SIX-CLOCK BUS
// CYCLE disappeared from a seed the campaign had dispositioned as IMMATERIAL
// (`bad_rows` 4 -> 2,067).  The chip's own T1 there is 0x8B92D, likewise ODD:
// silicon splits and the ucore had stopped.  The V2 arm was accidentally right
// about the SHAPE while being wrong about the ADDRESS, and restoring it would
// be re-installing a fitted arm to recover a coincidence.
//
// THE ADDRESS IS NOT TOUCHED.  Only which driver decides whether there are one
// or two bus cycles moves, and it moves to the driver the law already names.
// The un-relocated SPLIT PARTNER stays booked residue (relocation prereg
// §7(b)); `fz2c/406063` row 249 is its first measurement.
//
// AMENDMENT A-1.  The first form of this edit guarded on `!acc_byte` for both
// arms and SPLIT A BYTE GHOST: `fz2e/520066` has `eu_word == 0` (the ghost's
// own width arm, `ghost_next_byte || (eu_ghost_full && modrm_reg == 0 &&
// m_idx == 0)`) with an ODD `ghost_stack_phys`, and it went 8 -> 589 rows.
// `eu_word` IS `!acc_byte` on every non-ghost path -- that is its own default
// arm -- and it is NOT on the ghost's.  The lane mux and the split decision
// were reading two different widths.  So the ghost arm reads the width the
// ghost's own lane mux reads, and the statement is one sentence for both:
// AN ACCESS SPLITS IFF IT TRANSFERS A WORD ACROSS AN ODD BOUNDARY.
// The non-ghost arm is byte-for-byte what it was, so `row_wr_add` and
// `pr_active` are untouched.
wire       acc_split = s1w_ghost_read_stale_alu
                       ? (eu_word && ghost_stack_phys[0])
                       : (!s1w_acc_byte && acc_phys[0]);
// §73 / R7' -- THE WRITE-ACCOUNTING SPLIT, AND WHY IT IS EXACT.
// `acc_split` above is the BUS value: it drives `eu_split` and `eu_pair2`,
// which land in the BIU's request registers.  It is ALSO read by
// `row_wr_add`, and from there it reaches `stop`
// (`row_wr_add -> wr_after -> retire_ok_e -> bnd_row -> at_bnd -> bnd_fire`),
// which is how the ghost rails would enter the loader's control cone.
// They cannot MATTER there: `row_wr_add` is gated on `row_is_wr || row_is_wb`
// and `ghost_read_stale_alu` requires `row_is_read`, so the two are disjoint
// IN VALUE and joined only IN TEXT.  This is the write side's own value,
// ghost-free by construction -- not an approximation, and identical to what
// this expression computed before the read landed.
wire [15:0] s1w_acc_off_nog  = s1w_row_is_wb ? wb_ea : ind_now;
wire [19:0] acc_phys_nog = s1w_acc_io ? {4'd0, s1w_acc_off_nog}
                                  : ({acc_segv, 4'd0} + {4'd0, s1w_acc_off_nog});
wire       s1w_acc_split_wr  = !s1w_acc_byte && acc_phys_nog[0];

// THE TWO DRIVERS' OWN COMPOSED ADDRESSES, for the BIU to pick between at the
// launch.  Both are formed HERE, at the clock the ghost's micro-row is
// current, because that is when the rails are the row's own -- and both are
// formed BEFORE the launch so that NO ADDER enters the launch cone.  The
// segment is `SS` by construction: `ghost_read_stale_alu` requires
// `row_seg == 3'd2` and the row is not a write-back, so `acc_segv` is `SS`.
wire [19:0] ghost_phys_sp   = {acc_segv, 4'd0} + {4'd0, gpr[R_SP]};
wire [19:0] ghost_phys_bare = {acc_segv, 4'd0} + {4'd0, ghost_off};

//============================================================================
// COMBINATIONAL OUTPUTS -- what the BIU samples during THIS clock
//============================================================================
// The F interlock has to be clear before any of the row's acts happen.
wire s1w_row_blocked = (st == S_ROW) && s1w_e_f && f_wait;

//----------------------------------------------------------------------------
// SM3 SITTING 12 (R7') -- THE READ'S DATA EDGE, AND WHY IT IS A `D`-PIN MUX
// AND NOT A CHAIN INPUT.
//----------------------------------------------------------------------------
// `eu_rd_edge` is the ONLY thing in this module that carries the LIVE `READY`
// pin.  (By elimination, `sm3_s12_prereg_2026-08-04.md` §2: READY reaches
// `v30u_biu`'s next-state in three places; `ready_prev` goes straight to a
// flop; the `ts` advance reaches the EU only through `eu_slot_busy_n`, which
// `S_PRERD` consumes inside an arm that sets `stop` on every branch, so its
// cone ends at `row_posted_n`/`rd_pending_n`; everything else the EU reads --
// `q_ripe_lead_n`, `eu_rd_done_n`, `eu_wr_done_n`, `eu_rdata_n`,
// `eu_rd_edge_d` -- is REGISTER-ONLY.)
//
// It used to be applied inside block (a), i.e. it SEEDED `psw_n` at the head of
// the twelve-position chain, so one AND gate off the READY pin selected the
// input of the deepest combinational structure in the core.  MEASURED:
// `system_large|c_ready_q` -> `v30u_eu|opc_base[3]` at **62-63 logic levels,
// 51.2 ns against 31.25**, on 20,000 of 20,000 failing paths, Fmax 19.42 MHz
// (`docs/notes/sm3_s12_r7p/CTRL_cone.txt`).  The identical RTL closed at
// 45.67 MHz one sitting earlier: the fitter's physical synthesis happens to
// break that cone or happens not to (§70.5).  Same cone, same fix, as §52.3's
// `srst`.  With the load moved here the control is **42.37 MHz, 0 failing
// paths, worst `c_ready_q` path 19 levels**.
//
// THE RULE ITSELF IS UNCHANGED and it is `interrupt_model.md`'s:
//   "POP PSW consumes the popped image at its read's data edge -- the new IE
//    shows in the PS bits during the read's own T4."
// Only WHERE it is applied moves.
//
// `row_blocked` IS PART OF THE TAKE, AND IT IS THERE BECAUSE THE FORM WITHOUT
// IT WAS BUILT AND REFUTED (`sm3_s12b_prereg_2026-08-04.md` §1, seed
// `mc2/2788`).  Without it the two forms differ on exactly one shape: a SECOND
// read outstanding while an EARLIER one already sits in the completed-read
// store (`rd_pending=2`, `rd_done_cnt=1`, `rdq_n=1`), so `nr_have` holds,
// `nr_wait` is 0, the row is NOT blocked -- and the `OPR -> FLAGS` row RUNS on
// the same clock this data edge fires, writing `opr_live` (the EARLIER word)
// where the data edge wants `eu_rd_edge_d` (the CURRENT one).  Different
// values; the order decides.  The term is REGISTER-ONLY (`st`, `e_f`,
// `f_wait`), so it costs the cone nothing.
//
// WHY THE MOVE IS EXACT, in two cases that partition the clock:
//  * `row_blocked` HOLDS -- `S_ROW`'s `chain == 0` arm sets `stop` and assigns
//    nothing and positions 1-11 are skipped, so `psw_n` reaches the commit
//    equal to its preload `psw`, PROVIDED `poste`/`iend_owed` are not owed
//    (they run between the old write site and the chain and read-modify-write
//    `psw_n`).  That proviso is FALSIFIER (A) in the clocked observer.
//  * `row_blocked` DOES NOT HOLD -- the row is a pure register transfer
//    (`row_bus` false, `e_s1 == 6` not 7), so `row_acts_ok` holds, the step
//    performs `dest1 = FLAGS` and OVERWRITES `psw_n` entirely with
//    `s1_now = opr_live`.  Whatever block (a) put there was DEAD, so deleting
//    it changes nothing.  That is FALSIFIER (B).
//
// Both falsifiers are on the RAW take -- without `row_blocked` -- so they see
// every clock the old form would have written on, and they STAY in the tree.
wire        rd_edge_take_raw  = eu_rd_edge && (st == S_ROW) && s1w_e_f &&
                                (s1w_e_s1 == 5'd6) && (s1w_e_d1 == 5'd15);
wire        rd_edge_psw_take  = rd_edge_take_raw && s1w_row_blocked;
wire [15:0] rd_edge_psw       = (eu_rd_edge_d & PSW_WRITABLE) | PSW_FORCED;

// The row's own queue demand
wire q_demand_row = s1w_row_need_q && !s1w_row_blocked;

// The interrupt entry's first IVT read is reserved while row 7.10.0 is
// standing, two micro-rows before 7.10.2 accounts for the read.  This is the
// address-preparation half of the same fixed vector path: NMI and single-step
// supply their fixed vector numbers, while software and maskable interrupts
// leave the acquired vector in OPR.  Posting here lets ordinary BIU
// arbitration decide whether the status follows an idle clock, a direct
// redirect, or the final no-wait landing phase; no vector-specific delay or
// bus-state table is needed.
wire vector_fixed = irq_sel_nmi || irq_sel_brk;
// A waited landing overlaps only when NMI was taken at the cold opcode-pop
// boundary.  `irq_fast_inta` already records that boundary for the hardware-
// acknowledge collision; retaining it through the fixed-vector prologue also
// distinguishes this one waited overlap from ordinary row-boundary entries.
// No-wait landings remain the common NMI/BRK path.
wire vector_tail = eu_fetch_tail && vector_fixed &&
                   (!q_ripe || (irq_sel_nmi && irq_fast_inta));
wire vector_overlap = (st == S_ROW) &&
                      ((eu_direct_fetch && !q_ripe) || vector_tail);
wire vector_early = !s1w_row_blocked && vector_overlap &&
                    (upc_page == 3'd7) && (upc_opc == 8'h10) &&
                    (upc_loc == 4'd0);
wire s1w_vector_first = (st == S_ROW) &&
                    (upc_page == 3'd7) && (upc_opc == 8'h10) &&
                    (upc_loc == 4'd2);
wire [15:0] vector_number = irq_sel_nmi ? 16'd2
                          : irq_sel_brk ? 16'd1 : opr;
wire [19:0] vector_phys_early = {2'b0, vector_number, 2'b0};
// When the reservation is still short of T1, the BIU's ordinary slot latch is
// its provenance at 7.10.2.  All non-overlapped entries arrive here with the
// slot free and post in the normal way.
wire vector_reserved = s1w_vector_first && (eu_slot_busy || eu_access_active);

// The E row's successor pop (max-of-two-deadlines: the E row's own clock and
// the retire deadline).  A staged write defers it to the sequence tail.
//
// F11: THE DEMAND AND THE TAKE ARE ONE EVENT.  This wire is what puts the pop
// on the bus; v30u_eu_row.svh's cadence block is what consumes the byte.  They
// must be true on exactly the same clocks, so every term the step applies is a
// term here -- the row must RUN this clock (all four stalls), and the retire
// deadline must count THE WRITE THIS ROW IS ABOUT TO POST, which the step sees
// (it reads `wr_out` after its own increment) and the pre-edge wire did not.
// 7.10.2 owns the read reserved by 7.10.0, so an occupied slot there is its
// own access, not a reason to post or wait for a second copy.
wire       s1w_row_slot_wait = s1w_row_bus && !row_posted &&
                           eu_slot_busy &&
                           !vector_reserved;
wire [2:0] row_wr_add    = (s1w_row_is_wr || s1w_row_is_wb)
                           ? (s1w_acc_split_wr ? 3'd2 : 3'd1) : 3'd0;
wire [2:0] wr_after      = {1'b0, wr_out} + row_wr_add;
wire       s1w_retire_ok_e   = (wr_after == 3'd0) ||
                           ((wr_after == 3'd1) && eu_wr_done_n);
// ...and the E row's OWN pairing latch.  `exec_impl.h`'s
// `if (pend_.active && opr_fresh_) emit_pending();` runs IMMEDIATELY BEFORE the
// cadence, so the cadence sees the latch CLEARED -- reading the pre-edge
// `pend_active` here would take a byte the bus was never asked for.  Same two
// terms as `eu_pair` below, which is the act that does the clearing.
wire pend_new   = pend_active || (s1w_row_is_wr || s1w_row_is_wb);
wire s1w_pend_after = pend_new && !(opr_fresh || row_wr_opr);
// F24 -- A ROW THAT FLUSHES CANNOT POP.  `exec_impl.h`'s CTL block calls
// `biu_.flush()` BEFORE the cadence block reaches `opcode_prefetch`, so on a
// redirect row the queue the pop would take from has already been emptied and
// the pop waits for the refill.  The EU had the demand and the flush as two
// independent acts of the same clock and took the byte the flush was about to
// discard: `EB idx 0` popped its successor at row 5, where the golden shows
// PASV and the flush's own `E` on row 6.  The whole taken-JMP family (Jcc,
// E9/E8/EB/EA, FF.2/.4, RET, INT) is this one term.
wire s1w_row_flush = (s1w_e_type == TY_CTL) && !s1w_e_farjmp && (s1w_e_ictl == I_FLUSH);
wire row_epop = (st == S_ROW) && (s1w_e_e || s1w_ext4s_early_e) &&
                !s1w_pend_after && !opc_valid &&
                !s1w_row_blocked && (rowq >= s1w_row_qn) && !s1w_row_pre_wait &&
                !s1w_row_slot_wait && s1w_retire_ok_e && !s1w_row_flush && !s1w_bnd_fire;

//----------------------------------------------------------------------------
// THE BOUNDARY, AND WHY IT IS NOT THE POP
//----------------------------------------------------------------------------
// `BiuTimed::boundary_no_pop()` is `if (opc_valid_) return clk_; wait_bus();`
// -- the RETIRE deadline and NOTHING ELSE.  The recognition decision does not
// need the byte (it is the decision NOT to take one), so a recognised boundary
// does not slide when the queue is dry, and it is NOT cancelled by a flush
// (F24 is a fact about a POP; there is no pop here).  MEASURED in the SPEC:
// `INT.90` 200/200 with the retire deadline, 177 with the pop deadline, and
// every one of the 23 failures an odd-address dry-queue case.
//
// So `bnd_row` is `row_epop` with the two POP-ONLY terms removed (`q_ripe`,
// which lives in the step, and `!row_flush`).
//
// ...AND THE BOUNDARY IS A WINDOW, NOT A CLOCK.  `boundary_no_pop()` returns
// the retire deadline, but the model then takes its decision at
// `max(B, A + pipe)` -- and C5 says that `max` cannot be hardware.  What CAN
// be, and is what the frozen FSM does, is the plain reading of
// `pop_want = (state == S_FIRST && !irq_take)`: the part SITS at the pop point
// from the retire deadline until the byte arrives, and `irq_take` is a LEVEL
// sampled on every clock of that wait.  The two agree on every replayed case
// because the replay had already chosen a boundary that fires -- but only the
// window is causal, and it is what the goldens show.
// MEASURED: `INT.90 idx 14`, retire met on row 3 with a dry queue and the pin
// maturing on row 4; the chip's row-4 pop is SUPPRESSED.  A one-clock boundary
// declines it and pops.
wire bnd_row  = (st == S_ROW) && (s1w_e_e || s1w_ext4s_early_e) &&
                !s1w_pend_after && !opc_valid &&
                !s1w_row_blocked && (rowq >= s1w_row_qn) && !s1w_row_pre_wait &&
                !s1w_row_slot_wait && s1w_retire_ok_e;
// ...and `tailw_go` is a pop point too, so it is a boundary point too: the
// model's tail is `{deliver; emit;} ... if (at_fire_boundary()) ...
// opcode_prefetch()`, one check covering both.  MEASURED, `INT.F3AA idx 2`:
// `irq_take` was already true on the `E` row (which deferred, a store being
// staged) and the tail popped one clock later with no boundary evaluated.
wire bnd_epop = ((st == S_EPOP) || (st == S_TAIL_POP) || tailw_go) &&
                s1w_retire_ok_n;
// ...and the boundary of a PRE-DECODE-EXECUTED form, which has no `E` row at
// all: `step()` checks it after `loader_decode` returns (S9b), i.e. on the
// clock the successor's cold pop would ride.  `bnd_armed` is what separates
// that `S_OPC_POP` from the one a PREFIX hands over -- the model's prefix loop
// is INSIDE `loader_decode`, so there is no boundary between a prefix and its
// instruction, which is the measured "no sample between 26 and 8B".
wire s1w_bnd_opc  = (st == S_OPC_POP) && bnd_armed;
wire at_bnd   = bnd_row || bnd_epop || s1w_bnd_opc;

// THE SHADOW IS A DECODE-TIME CLASS, NOT A WRITE.  "Recognition-deferring
// instructions: every segment-register load -- measured on `MOV SS,AW` AND
// `MOV DS0,AW`" ... "8C sreg-STORE shadows recognition too".  It was tempting
// to derive it from the sreg WRITE itself, and that is REFUTED by the row
// order: `8E`'s write is on the POST-`E` row (`0.8e.1`), which the model runs
// AFTER the cadence -- so at the boundary no write has happened yet, and the
// golden still skips the sample (`INT.8ED0 idx 16` row 4: the chip pops, the
// write-derived rendering vectored).  The class is what the PLA already says
// (`pla3_sreg_mov`, the same bit that makes the ModR/M `reg` field an SREG),
// and it is set where the loader latches it.
// REGISTERED RESIDUE: the far-CALL / far-JMP `CS` write is documented to
// shadow too and is NOT in this class; no golden combines the two.
// SM3 SITTING 11 -- AND H1's SEPARATE FLOOR IS GONE.  It used to sit in the
// BIU (`bnd_hold`, five flops, armed by an INTA) and hold this boundary open
// for two clocks.  The gate above now demands IE up NOW **and** up three
// clocks ago, so a recognition cannot act until a rising IE has crossed the
// floor -- and `bnd_hold` was MEASURED INERT against the whole 3,242-seed
// bank (REGISTERED 1,490 / EVT 910 / COMBINED 2,400, to the seed, with it
// forced to zero).  It is DELETED rather than left standing.
//
// WHAT THE BIU STILL NEEDS FROM HERE is the prefetcher SUSPEND: the
// recognition that PAYS the floor grants the slot between the floor and its
// own request to NOTHING (the census's two idle clocks).  `eu_bnd_post`
// carries that condition now: `!ie_p[3]` is exactly "the IE gate is what held
// this boundary", since the take needs `ie_p[2]` and IE was still low four
// clocks back.  This includes an INT remembered on IE's rise; a REP withdrawal
// remains on C_INTR's separate route while `rep_kind != REP_NONE`.  MEASURED:
// forcing the suspend unconditional costs EVT 910 -> 897.
//
// AND `!irq_nmi_lvl`, for the SAME reason the floor itself is maskable-only: a
// non-maskable recognition is not IE-gated, never paid the floor, and must not
// carry the suspend that goes with it.  MEASURED: without this term the entry
// after an NMI suspends a fetch the chip runs, and `NMI.B8` falls 200 -> 188
// (12 cases, all `row 6 busstat: exp CODE got PASV`).
wire s1w_irq_take = irq_any && !irq_shadow;
// §86 -- AND THE TRAP RIDES THE SAME BOUNDARY.  `at_fire_boundary()` in the
// model is `ext_fire() || brk_take_`: ONE recognition path with one more term
// on it, not a second path.  The floor is `ie_p`'s sentence one bit over --
// "TF up NOW **and** up three clocks ago" -- and the take is the ARM, which
// was sampled at the PREVIOUS boundary (see `brk_smp` below).
wire s1w_brk_seen = psw[FBRK] && brk_p[BRK_FLOOR-1];
// W3.1 -- **...AND THE TRAP RIDES THE SHADOW TOO.**  §86.A booked its absence
// as a divergence with a falsifier written down (*"the trap is not shadowed
// behind a segment-register load ... silicon is documented to, this tree has
// no cell"*).  The cell is the `wr1` corpus and the falsifier FIRED.
//
// MEASURED, chip-side and engine-free (`sw/w31_shadow.py`), over 380 captures
// / 3,411 chip vector-1 entries / 1,363 consecutive trap pairs, where `grace`
// is instruction boundaries the part ran PAST between two traps and §84/§85
// measured the storm cadence at 0 on 1,742 + 90 pairs:
//
//     MOV sreg  8C 8E    g>=1 on 69, g0 on     0      the class already here
//     POP sreg  07 17    g>=1 on  6, g0 on     0      NEW -- no PLA column
//     PUSH sreg 06 16    g>=1 on  0, g0 on     5      NOT the class
//     LES/LDS   C4 C5    g>=1 on  0, g0 on    11      NOT the class
//     all other opcodes  g>=1 on  0, g0 on 1,277      195 distinct opcodes
//
// Not one exception in either direction.  The single grace-2 pair is two
// consecutive `8E`s -- the shadow COMPOSING, which this shape gives for free
// because the arm is untouched and only the TAKE is gated.
//
// THE CLASS IS TWO MICROCODE ENTRIES, which is why `8C` -- a segment-register
// READ -- is in it and `PUSH` sreg is not:
//     00?.100011?0.00   8C 8E          `R -> M`     the MOV-sreg entry
//     00?.000??111.00   07 0F 17 1F    `OPR -> R`   the POP-sreg entry
//     00?.000??110.00   06 0E 16 1E    `R -> OPR`   PUSH sreg -- a DIFFERENT
//                                                   entry, and it does not
//                                                   shadow
// *Falsifier*: any capture in which `PUSH` sreg or `LES`/`LDS` shows a grace
// >= 1, or a member of the two entries shows a grace of 0.
// fz2 SURVEY FIX #3 (family `C1`) -- **AN EXTERNAL RECOGNITION DOES NOT SPEND
// THE ARM.  ONLY THE TRAP'S OWN TAKE DOES.**  §86 landed the five entry sites
// with `brk_arm_n = 1'b0` and the comment *"the arm is spent either way"*.
// That second half is refuted by silicon: at a boundary where a maskable or
// non-maskable recognition and an armed single-step trap coincide, the part
// walks through the external door and STILL OWES THE TRAP, which it pays at
// the entry sequence's own end boundary -- before the handler's first
// instruction, after exactly one handler prefetch.
//
// MEASURED, on the banked FLASH #13 A/B captures, chip against fabric core,
// 19 seats whose rows agree cycle for cycle up to the fork
// (`docs/notes/fz2_c1_prereg_2026-08-10.md` §2).  Exemplar `fz2c/400007`:
// both legs read the NMI vector at rows 3,345-3,352 and push at 3,357-3,373,
// both fetch the handler's first word at 3,374, and then the CHIP reads
// `0x00004`/`0x00006` at 3,383-3,390 while the core executes the handler.
//
// The fix is the term the line beside it already uses.  It is INERT wherever
// `brk_arm` is 0 -- every `HLT.*` golden and every sweep cell runs with
// `PSW.TF` clear -- so the whole `check_core` surface is bit-identical.
// *Falsifier*: a capture in which the chip takes an external interrupt at a
// boundary with `PSW.TF` armed and does NOT then read vector 1 before the
// handler's first instruction retires.
wire s1w_brk_take = brk_arm && !irq_shadow;
wire s1w_bnd_take = s1w_irq_take || s1w_brk_take;
wire s1w_bnd_fire = at_bnd && s1w_bnd_take;
// ...and the boundary that fires is the one that CLEARS the arm and suspends
// the prefetcher.  `at_bnd` implies `!opc_valid` on all three of its arms,
// which is `boundary_no_pop()`'s own early return ("already latched: this IS
// the pop clock") -- a pre-popped successor never reaches the floor at all.
assign eu_bnd_take = s1w_bnd_fire;
// §86 -- ...AND THE SUSPEND BELONGS TO THE RECOGNITION THAT PAID THE IE
// FLOOR, WHICH THE TRAP NEVER DOES.  `irq_take` is the added term.  It is
// INERT on every path that existed before the trap, because this wire is only
// ever consumed as `eu_bnd_take && eu_bnd_post` and the old `eu_bnd_take`
// (`at_bnd && irq_take`) already implied it.  The trap is not IE-gated, for
// the same reason a non-maskable recognition is not -- and `!irq_nmi_lvl` is
// already here saying exactly that about NMI.  In the model the suspend is
// inside `if (post_redirect && live)` with `live = maskable() && ...`, and
// `maskable()` is `ev_pin_ == 0`: a run with no pin directive never suspends,
// which is every seed a BRK trap fires in.
assign eu_bnd_post = s1w_irq_take && !ie_p[3] && !s1w_irq_nmi_lvl;

// §35.4 -- ...AND F11's RULE APPLIES TO THE TAIL'S OWN FALL-THROUGH.  With
// `S_TAIL_W` made zero-cost the tail's POP now happens inside the delivery's
// edge, so the act decode has to reconstruct the hand-over the step is about
// to make -- otherwise the EU eats a byte the BIU was never asked for (the
// first attempt did exactly that: the three string forms' ARCH fell from
// 500 to their cycle counts while nothing timed moved).
wire tailw_go = (st == S_TAIL_W) && !opc_valid &&
                (opr_fresh || !(s1w_nr_wait || !s1w_opr_free_now));

wire q_demand = ((st == S_OPC_POP) && !s1w_bnd_fire) ||
                (st == S_EXT_POP) || (st == S_MODRM) ||
                (st == S_D16_LO) ||
                ((st == S_D8_B)   && (!ld_ripe_prev ? (chg == 2'd1) : 1'b1)) ||
                ((st == S_D16_HI) && (!ld_ripe_prev ? (chg == 2'd1) : 1'b1)) ||
                q_demand_row || row_epop ||
                // F11 again: both deferred-pop states TAKE the byte only past
                // the retire deadline, so neither may DEMAND it before.
                (((st == S_EPOP) || (st == S_TAIL_POP) || tailw_go) &&
                 s1w_retire_ok_n && !s1w_bnd_fire);

assign q_pop   = q_demand;

// WAVE 15 C1 -- THE SELECTION HAPPENS HERE, NOT IN THE BIU.
//
// The BIU publishes the 1BL retire lead for each of the two things this module
// can do to the queue on this clock, both off ITS OWN REGISTERS.  The EU's pop
// is a one-bit fact this module already owns, and `q_ripe` is a BIU REGISTER
// port, so the select costs one AND and one MUX HERE and the value the clocked
// step reads no longer makes a combinational excursion into the BIU and back.
//
// `!q_flush` is a term because the flush OVERWRITES the queue count after the
// pop has decremented it, so on a flush clock the published no-pop level is the
// right one.  The BIU `$fatal`s (`ifndef SYNTHESIS`) if this expression ever
// disagrees with its own `pop_eff`, and again if the composed value ever
// differs from the original predicate -- so the two consumer sites below
// (`v30u_eu_step.svh`, `v30u_eu_arm_decode2.svh`) are BYTE-UNCHANGED and read
// exactly what F7 promises them.
// WAVE 15 C2 -- ...AND THE SELECT RIDES THE PHASE SPLIT'S OWN SHADOW.
// `q_pop`, `q_ripe` and `q_flush` are all constant across the CPU cycle
// (`q_ripe` is a BIU REGISTER; the other two are stage-1 quantities), so this
// one bit belongs in `s1_bus` like every other stage-1 output -- and the
// split's OWN premise assertion `$fatal`s if it is not constant, which is this
// arm's free falsifier.  With the select shadowed, stage 2 reads THREE
// registers -- the two published levels and this bit -- and the `ce -> ce` cone
// no longer contains any of stage 1's logic on this path.
wire s1w_qripe_pop = q_pop && q_ripe && !q_flush;
assign q_first = (st == S_OPC_POP) ? pop_is_first
               : (st == S_EPOP) || (st == S_TAIL_POP) || tailw_go ||
                 row_epop ? 1'b1
               : 1'b0;

// KM -- THE PIN QUESTION AND THE BOUNDARY QUESTION ARE NOT THE SAME QUESTION.
//
// `q_first` answers "does this pop START an instruction?" and that is exactly
// what the `QS` pins announce (v30u_biu.sv `QS_FIRST`/`QS_SUBSEQ`).  The BRK/TF
// arm asks a different one -- "is this the pop whose byte the LOADER DECODES?"
// -- and on an `0F`-escaped instruction the two differ: the escape's SECOND
// byte is the opcode, popped in `S_EXT_POP`, and the pins announce it
// SUBSEQUENT.  Everywhere else the two coincide, so this is ONE term.
//
// MEASURED, silicon, FLASH #17, `docs/notes/tf0f_cell_results_2026-08-11.md`:
// 512 directed cells x 4 waits x 4 alignments, 2,880 scored traps per engine,
// derivation 16/16 and a DISJOINT validation 14/14.  An instruction contributes
// ONE TF boundary unit plus ONE MORE iff its opcode byte is not its first byte
// -- prefixes and/or an `0F` escape -- and the extra unit is ONE however deep
// the decoration and however many KINDS of it are present.  The eleven bare-
// `0F` legs are the whole divergence: the chip is one unit EARLIER on all of
// them (`x13 x1b x18 x28 x33 y1e`, `v_x39 v_x1f v_x10 v_x2a v_y13`), 176 of 512
// cells, every one in the same direction, at every wait and every alignment.
//
// SATURATION NEEDS NO COUNTER, AND IS NOT ADDED HERE -- IT IS ALREADY WHAT THIS
// TREE DOES.  `brk_arm` is ONE FLOP holding a LEVEL (`brk_arm_n = brk_seen`),
// and the TAKE is `bnd_fire = at_bnd && bnd_take` with `bnd_opc` gated by
// `bnd_armed`, which is set only at a RETIRE and never at a prefix hand-over.
// So extra samples INSIDE an instruction cannot move its trap earlier than its
// own retire boundary.  That is already why `pfx1`..`pfx4` all read TWO units
// while the pins announce two, three, four and five (384 traps, both engines),
// and it is why adding the escape's sample leaves the PREFIXED-`0F` legs
// `z1b` / `v_p2x` / `v_p4x` -- 288 traps -- exactly where they are.
// *Falsifier*: any capture in which a prefixed `0F` instruction with `PSW.TF`
// set traps one unit earlier than an unprefixed one of the same length.
//
// The three other `q_first` consumers -- the `QS` pins, `eu_halt` and
// `first_pop_seen` -- deliberately keep asking the PIN question.
wire s1w_q_bnd_pop = q_first || (st == S_EXT_POP);

// --- the bus request -------------------------------------------------------
// exec_impl.h::bus_read / bus_write: a staged write must run before the next
// cycle, so the row first pairs it (`emit_pending`) and then posts its own.
// F20 -- THE PRE-PAIR FLUSH IS A `deliver_read()`, NOT JUST A WAIT.  The
// model's guard is `if (pend_.active) { if (!opr_fresh_) deliver_read();
// emit_pending(); }`, and `deliver_read()` is `wait_read()` PLUS a POP of the
// completed-read store into OPR.  The EU had only the wait, and only its
// `wait_opr_free` half: nothing popped, nothing paired, `pend_active` never
// cleared.  `REP MOVS` is where it shows -- every iteration's store is paired
// by the NEXT iteration's read row -- and it is what tripped C3's assertion at
// CX==3 (two completed reads in the store because none were ever taken out).
wire pend_go = pend_active && opr_fresh;
wire row_pre_pair = s1w_row_bus && pend_active;
wire s1w_row_pre_wait = row_pre_pair && !opr_fresh && (s1w_nr_wait || !s1w_opr_free_now);

wire row_acts_ok = (st == S_ROW) && !s1w_row_blocked && (rowq >= s1w_row_qn) &&
                   !s1w_row_pre_wait;

wire pr_active = (st == S_PRERD) && !row_posted;
wire row_post_now = row_acts_ok && s1w_row_bus && !row_posted &&
                    !vector_reserved;
// First hardware acknowledge contested-slot law: ordinary microcode
// retirement reserves a direct CODE tail until the next idle clock.  A cold
// opcode-pop boundary, or recognition that already paid the IE floor, keeps
// the immediate replacement.  This separates the four slow collisions from
// the mc2/2062 immediate control without a bus-state table.
wire s1w_inta_first = s1w_row_is_inta && (upc_page == 3'd7) &&
                  (upc_opc == 8'h02) && (upc_loc == 4'd0);
// A HALT wake reaches the interrupt dispatcher while the wake prefetch may
// still be only an announcement.  Publish that one-clock provenance before
// 7.02.0 posts INTA so the BIU can withdraw the announced fetch instead of
// opening its T1.  The latch is set only by S_HALTED and spent by S_IRQ_D.
assign eu_post = (vector_early || pr_active || row_post_now) && !eu_slot_busy;
assign eu_post_hold = (vector_early && vector_tail && !eu_direct_fetch &&
                      !q_ripe && !eu_slot_busy) ||
                      (row_post_now && s1w_inta_first && eu_direct_fetch &&
                       !irq_fast_inta && !eu_slot_busy) ||
                      (row_post_now && (rdq_n == 2'd2) && !eu_slot_busy);
assign eu_halt_irq = irq_halt_entry;
assign eu_vector_post = eu_post && s1w_vector_first;
// P4'-space -- THE GHOST READ'S SPACE IS THE DECODE STANDING AT ITS OWN T1.
//
// The 8F mod==3 ghost is the one cycle in this machine that reaches the bus
// with no decode of its own behind it: the register-form POP has no memory
// operand, and the row that posts it (0058) belongs to the 8F, whose SR field
// is memory.  `acc_io` is `row_io`, a MICRO-ROW field, so the ucore announces
// MEMR and only reaches IOR at pop+2, once the SUCCESSOR's own row is standing.
// MEASURED on all four seats (fz2_p4p5_results sec.1): `eu_bs` is MEMW at the
// ghost's display AND at its T1, and first reads IOR at pop+2.
//
// Silicon announces the space from the decode standing at the cycle's OWN T1,
// which is the successor opcode at pop+0, and the only pop+0 carrier here is
// `q_byte`.  The CLASS it is read with is not a new one: `row_io` above is
// `(e_sr == IO) && (xop == F || xop == 6)`, and those two `xop` values ARE the
// die's I/O class -- E4-E7 / EC-EF and 6C-6F.  So the space rail gets that same
// class one clock earlier, off the byte being popped, qualified by the cycle's
// DIRECTION: the announcement is a READ, so the pop+0 opcode's own direction
// bit (bit 1, the 8086/V30 encoding's `d`) must be CLEAR.
//
// MEASURED, chip IOR / core MEMR at the fork on all four:
//   fz2c/410028 @2994 successor ED   fz2e/520066 @1249 successor EC
//   fz2e/527055 @655  successor 6D   fz2e/528030 @423  successor EC
// and `6F`/OUTM -- the identical `xop == 6` with bit 1 SET -- is the control:
// silicon says MEMR there, and `!q_byte[1]` says so without naming an opcode.
//
// THE ADDRESS IS DELIBERATELY NOT TOUCHED, AND THAT IS A MEASUREMENT.  Routing
// this through `acc_io` would also strip the segment from `acc_phys_base`, and
// silicon does NOT: on three of the four seats the chip's ghost T1 address
// ALREADY AGREES with the core's (4070e, f79b0, fd93c) while the status
// disagrees.  On this cycle the space rail reaches the STATUS encoder and not
// the address adder.  (`fz2e/520066` also forks on the address; that half is
// the ghost-address cone and is not this landing's.)
//
// `q_ripe` is the same guard the pop+0 WIDTH rail uses one block up: with no
// ripe byte there is no decode standing, and the row's own space wins.  The
// PLA lookup is declared here rather than shared with that block so that this
// landing and the ghost-address work stay textually independent.
//
// !! THE OVER-FIRE IS NAMED, NOT FITTED AROUND.  `xop == F` also selects `F0`
// (LOCK) and `xop == 6` also selects `F9` (STC), both with bit 1 clear.  The
// ordinary path excludes them with the micro-row's `e_sr`, WHICH DOES NOT
// EXIST AT pop+0 -- there is no ROM row yet.  Taking the PLA class unqualified
// is therefore a PREDICTION, not a fit, and an F0/F9 exclusion is deliberately
// NOT written.
//
// FALSIFIER: (a) a capture in which an 8F mod==3 ghost whose pop+0 successor
// is an I/O READ opcode is announced MEMR by the chip; (b) one in which the
// same ghost with an F0 or F9 successor is announced MEMR -- that refutes the
// unqualified class and sends the predicate to a narrower carrier; (c) one in
// which a 6E/6F successor makes the ghost IOR.
// (docs/notes/fz2_w4_prereg_2026-08-10.md sec.2)
wire [13:0] ghost_t1_pla = pla3_native(q_byte);
wire ghost_space_io = s1w_ghost_read_stale_alu && q_ripe && !q_byte[1] &&
                      ((pla3_xop(ghost_t1_pla) == 4'hF) ||
                       (pla3_xop(ghost_t1_pla) == 4'h6));
assign eu_bs   = vector_early ? BS_MEMR
               : pr_active   ? BS_MEMR
               : s1w_row_is_inta ? BS_INTA
               : row_is_read ? ((s1w_acc_io || ghost_space_io) ? BS_IOR : BS_MEMR)
                             : (s1w_acc_io ? BS_IOW : BS_MEMW);
assign eu_addr = vector_early ? vector_phys_early
               : pr_active ? pr_phys : (s1w_row_is_inta ? 20'd0 : acc_phys);
// The launch-law's two publications.  `eu_ghost_row` is the ROW's currency and
// nothing else -- the BIU takes its RISING EDGE as the age's arm, which is the
// law's own anchor, `upc_opc == 8'h8f && upc_loc == 4'd4` going current.
// `eu_ghost_acc` is the narrower fact that the access published THIS clock is
// the ghost's own, which is what tags the BIU's request slot; the pre-decode
// read and the vector's early post use the same wires for their own addresses
// and must not be tagged.
assign eu_ghost_row  = s1w_ghost_read_stale_alu;
assign eu_ghost_acc  = eu_ghost_row && !vector_early && !pr_active;
assign eu_ghost_sp   = ghost_phys_sp;
assign eu_ghost_bare = ghost_phys_bare;
assign eu_addr2= vector_early ? (vector_phys_early + 20'd1)
               : pr_active ? pr_phys2 : acc_phys2;
assign eu_split= vector_early ? 1'b0
               : pr_active ? pr_split : (!s1w_row_is_inta && acc_split);
assign eu_seg  = vector_early ? 2'd2
               : pr_active ? seg_code(pr_seg)
               : s1w_row_is_inta ? 2'd2 : (s1w_acc_io ? 2'd2 : seg_code(s1w_acc_seg));
assign eu_seg2 = vector_early ? 2'd2
               : pr_active ? seg_code(pr_seg2)
               : s1w_row_is_inta ? 2'd2 : (s1w_acc_io ? 2'd2 : seg_code(s1w_acc_seg));
assign eu_word = vector_early ? 1'b1
               // The stale 8F word-lane rail outlives its absent operand and
               // overlays the following byte pre-read on silicon.
               : pr_active ? (ghost_preread_tail ? 1'b1 : !s1w_pr_byte)
               // The ghost posts on the successor-opcode overlap.  Its lane
               // mux therefore sees the successor's ordinary PLA width; C0
               // and C6 successors are the two current-socket byte witnesses.
               // Retain the earlier full-phase C0 witness as the same mux's
               // absent-operand input.
               : (s1w_ghost_read_stale_alu &&
                  (ghost_next_byte ||
                   (eu_ghost_full && (modrm_reg == 3'd0) &&
                    (m_idx == 3'd0)))) ? 1'b0
               : (s1w_row_is_inta ? 1'b1 : !s1w_acc_byte);

// The data pairing (`emit_pending`).  The row's OWN `-> OPR` write counts:
// the model writes OPR and then emits, both on the row's clock, so the value
// the store takes is the one this row is about to put there.
//
// THE POST-`E` ROW IS A ROW WITH A CLOCK (family A, U2 pass 3).  F8 gave it no
// STATE -- it is a one-bit debt discharged at the top of the next edge -- but
// the model runs it as an ordinary row, and `exec_impl.h:1095`'s
// `if (pend_.active && opr_fresh_) emit_pending();` fires on it like any other.
// `50`'s store is paired by exactly that: the `E` row `0029` posts the cycle
// and the post-`E` row `002A` (`M -> OPR`) hands it the data.  The clock it
// happens on is the clock `poste` STANDS on, so the pairing act belongs there.
// Without this the deferred store ran with whatever OPR held (`50 idx 2`:
// data 0000 against the golden's AX) -- eu_pair never asserted at all.
wire opr_wr_gate = s1w_e_have1 &&
                   ((s1w_e_d1 == 5'd6) ||
                    ((s1w_e_d1 == 5'd18) && (r_kind == OK_MEM)) ||
                    ((s1w_e_d1 == 5'd19) && (m_kind == OK_MEM))) &&
                   !((s1w_e_s1 == 5'd20) && !s1w_sig_commits);
wire row_wr_opr = (st == S_ROW) && !s1w_row_blocked && (rowq >= s1w_row_qn) &&
                  opr_wr_gate;
wire poste_wr_opr = poste && opr_wr_gate;
// F20's delivery is a transfer like any other, so the `emit_pending()` that
// follows it takes the word it delivers -- the head of the completed-read
// store.  The row's OWN `-> OPR` write comes FIRST in the model's order
// (transfers, then the row-type block's bus call), so it wins.
wire row_pre_deliver = (st == S_ROW) && !s1w_row_blocked && (rowq >= s1w_row_qn) &&
                       !s1w_row_pre_wait && row_pre_pair && !opr_fresh &&
                       !row_wr_opr;
// ...and F11a's rule on the READ side applies to THIS delivery too.  When the
// completion IS the lookahead (`nr_have`'s `eu_rd_done_n`) the word is not in
// the store yet -- block (a) puts it there in the same edge the step then pops
// it -- so the act decode has to read `eu_rdata_n` directly.  `opr_live` had
// this for the `F` row and `opr_now` did not, so every `REP MOVS` middle
// iteration whose read landed on the pairing clock drove the STALE OPR:
// `F3A4 idx 1` row 14, exp 37032 got 0.
// The same untagged data rail is also the write-pairing rail.  If a successor
// store pairs while the ghost word is still in the BIU read latch, that word
// wins the collision.  Once the completion pulse has handed the word to the
// EU, the row's ordinary source wins instead.  No added latch is needed, and
// `eu_rd_edge_d` is the LATCHED word, which `sw/r7_lint.py` classes
// register-only -- it is not the live READY pin.
wire ghost_edge_pair = ghost_rd_discard && eu_pair && !eu_rd_done_n;
wire [15:0] opr_now = ghost_edge_pair                    ? eu_rd_edge_d
                    : (row_wr_opr || poste_wr_opr)       ? s1_now
                    : (row_pre_deliver && (rdq_n != 2'd0)) ? rdq0
                    : (row_pre_deliver && eu_rd_done_n)    ? eu_rdata_n
                    : opr;
assign eu_pair  = ((st == S_ROW) && !s1w_row_blocked && (rowq >= s1w_row_qn) &&
                   !s1w_row_pre_wait &&
                   (pend_active || s1w_row_is_wr || s1w_row_is_wb) &&
                   (opr_fresh || row_wr_opr || row_pre_deliver))
               || (poste && pend_active && (opr_fresh || poste_wr_opr));
assign eu_pair2 = pend_active ? pend_split : acc_split;
assign eu_wdata = opr_now;

// --- the CTL strobes -------------------------------------------------------
assign q_flush  = row_acts_ok && s1w_row_flush;
// The REP-withdrawal redirect can coincide with the tail of an element whose
// accepted bus result is still draining into the EU.  Publish that one-bit
// ownership fact with the flush; the BIU uses it only to choose which side of
// the redirect clock its next arbitration point occupies.
// `rep_kind` has already been retired on the no-tail arm by this row, while it
// remains live until S_TAIL_W on the pending arm.  The common control rail is
// therefore the withdrawal microaddress itself, not that travelling prefix
// latch: page 7 / opcode 40 is the one REP-withdrawal sequence in the ROM.
assign flush_pre = (st == S_ROW) && (upc_page == 3'd7) &&
                   (upc_opc == 8'h40) && (upc_loc == 4'd6) && !pend_active;
assign flush_rep = q_flush && (upc_page == 3'd7) && (upc_opc == 8'h40);
assign flush_stage = q_flush && pend_active;
// A staged tail delays the redirect only when an external withdrawal still
// has a completed element read to deliver.  A bare pairing latch has no read
// behind it and the single-step path consumes its tail in parallel with the
// redirect; neither owns an extra BIU arbitration point.
assign flush_pend = q_flush && pend_active && (rdq_n != 2'd0) && !s1w_brk_take;
// Publish the two interrupt rails that physically meet the withdrawal edge.
// NMI is the part's recognition latch; maskable INT is the live package pin,
// whose release distinguishes a short impulse from an asserted hold without
// adding history state to either unit.
// The pin is published RAW.  It was gated on `q_flush`, which is redundant at
// both of the BIU's original readers (each is already ANDed with `flush_stage`
// or `flush_rep`, and both carry `q_flush`) and WRONG for the third: the empty
// arm reads the same rail on the withdrawal's own preceding row, where the
// flush strobe is still low.  Removing the gate changes nothing the two old
// readers see and gives the third the pin it is asking about.
assign flush_nmi = s1w_irq_nmi_lvl;
assign flush_int_live = pin_int;
// P5'-stall -- A CS WRITE IS PUBLISHED ON THE CLOCK ITS ROW ACTS, NOT ON EVERY
// CLOCK OF THE ROW'S STALL.
//
// `wr_cs1` is the row's INTENT to write CS -- it is decoded from the micro-row
// standing on `upc` and is therefore true for every clock a stalling row
// re-enters itself.  `cs_now` during that stall is NOT the value that will be
// written: it is whatever the row's source mux happens to hold, and in
// `fz2e/533028` that is the instruction's DISPLACEMENT `7664` against the
// `ccac` finally written.  The chip writes the register ONCE and builds
// anything committed before that from the value the register HOLDS -- measured
// on all four seats, each one's chip fetch equal to `flush_cs_old` exactly:
//   fz2e/520062 @700  we 691->702, flush_cs 2774, written a243, chip 5cdb=OLD
//   fz2e/528008 @628  we ...->630, flush_cs 3b1f, written 3e05, chip 0ecc=OLD
//   fz2e/532012 @328  we 320->330, flush_cs bd85, written 64c3, chip b674=OLD
//   fz2e/533028 @881  we 870->883, flush_cs 7664, written ccac, chip 12fe=OLD
//
// `v30u_biu.sv`'s P5' comment books this to THIS file and says why it cannot
// be said there: no flop-free BIU predicate separates "the register is written
// THIS clock" from "a row that will write it is stalled" (`flush_cs !=
// flush_cs_old` is true throughout, and `r_cs_r` observes the change one clock
// too late).  Here the predicate already exists and needs no flop:
// `row_acts_ok` is the rail on which the row's acts are published, and it is
// the rail `q_flush` itself is qualified by, one line above the strobes.  The
// REDIRECT and the CS it redirects to are published by the same row on the same
// clock, or they are not one act.  Both of the BIU's readers are fixed by this
// one term, because both read these two wires: the display's `cmt_cs_live`
// retarget and the prefetcher's own `fetch_lin`.
//
// FALSIFIER: any capture in which the chip's retargeted fetch is built from a
// CS the register does not yet hold on that clock -- i.e. in which a stalled
// CS-writing row's intended value reaches the bus before its row commits.
// (docs/notes/fz2_w4_prereg_2026-08-10.md sec.1)
wire flush_cs_now = wr_cs1 && row_acts_ok;
assign flush_cs = flush_cs_now ? cs_now : sreg[SR_CS];
assign flush_cs_old = sreg[SR_CS];
assign flush_cs_we = flush_cs_now;
assign flush_ip = pc_now;
// F25: ...and the prefetcher is held through the reset dispatch.
assign eu_susp  = (st == S_RESET) ||
                  (row_acts_ok && (s1w_e_type == TY_CTL) && !s1w_e_farjmp &&
                   (s1w_e_ictl == I_SUSP));
assign eu_resume = 1'b0;

// S9a -- HLT IS DECODED, NOT MICROCODED, AND THE DECODE IS WHERE IT ACTS.
// The model's `note_halt` lands in tick(c)'s PRE-ROW block, which in RTL is
// the edge ending c-1 (U1 finding, provenance sec.11.6) -- so `eu_halt` LEADS
// by one clock, and the clock it must ride is the OPCODE'S OWN POP CLOCK.
// One rule, both paths: the loader's own F pop and the E row's pre-pop.
//
// U2 pass 5 -- VERIFIED FOR THE FIRST TIME, and it is RIGHT: the model's HALT
// DISPLAY block sits at the TOP of `tick(c)` and writes `cmt_disp_ = c`, i.e.
// it claims the clock it runs on, where a GRANT (decided at the end of
// `tick(c)`) claims `c + 1`.  The RTL's register boundary supplies exactly
// that one clock of skew, so the pop-clock lead is what puts the HALT display
// on `pop + 1` -- which is where 300 of the 600 goldens have it.
//
// What was WRONG is the other half of the same edge, and it is a BIU fact, not
// this one: `halted` was applied to the prefetch grant IN THE SAME EDGE, so
// the eval at the end of the pop clock refused a fetch the part grants.  See
// `v30u_biu.sv`'s "M16 -- THE DECODE DOES NOT TAKE A COMMITTED FETCH BACK".
wire qb_is_halt = pla3_one_byte_logic(pla3_lookup(
                      mode8080 ? PLA3_MODE_8080 : PLA3_MODE_NATIVE, q_byte)) &&
                  (pla3_xop(pla3_lookup(
                      mode8080 ? PLA3_MODE_8080 : PLA3_MODE_NATIVE, q_byte))
                   == PLA3_BL1_HALT);
// fz2 P2 / `L-B` -- ...AND THE ANNOUNCEMENT IS THE OTHER HALF OF THE ACT THE
// DECODE PARKS ON, SO IT CARRIES THE SAME TERM.  `HLT` is split across two
// clocks BY DESIGN (S9a above: the display leads the park by one, and it rides
// the OPCODE'S OWN POP CLOCK), so *"a boundary that retires into the trap does
// not halt"* has to be said at both halves or it is only half said.  MEASURED,
// and this is why it is here rather than argued: with the term at the decode
// alone (`v30u_eu_step.svh` S_DECODE2), `fz2e/535042`'s trap fires at exactly
// the chip's row and pushes the chip's IP `0e84` -- and the core still drove a
// HALT cycle at row 820 that the chip leaves PASV, so NOT ONE of the eight
// class-`B` seats moved and `fz2c/410053` hit `v30u_biu`'s `sev bound`
// assertion.  The predicate is otherwise untouched: `q_pop && q_ripe &&
// q_first` is the same boundary `brk_smp_n` samples on, and `brk_seen` is live
// there (the `1BLD` probe reads `seen=1` on that clock).
// *Falsifier*: a capture in which the chip drives a HALT cycle at a `HLT`
// whose own retire boundary has the BRK/TF arm standing.
assign eu_halt = q_pop && q_ripe && q_first && qb_is_halt && !mode8080 &&
                 !eu_halted && !s1w_brk_seen;

// THE WAKE.  A halted part has no instruction boundary to sample, so the
// decision sits at the EARLIEST CLOCK THE PIN PIPELINE ALLOWS -- which is the
// same pipeline, read in the same place.  `timed_runner.cpp` states the
// geometry and it falls straight out of `B = D + 1`, `entry = B + 2`:
//
//   HLT.RES  D = A+3 (the INT level matures), pop at A+4  -- "the prefetcher
//            resumes at the decision cycle, the next instruction pops one
//            cycle later"
//   HLT.INT  D = A+3, B = A+4, entry at A+6 -- "INTA request ready at
//            assert+6"; the prefetcher restarts at the DECISION
//   HLT.NMI  D = A+4 (the latch reads true at edge+4), B = A+5, entry at A+7
//            -- and the BUS IS HELD: the wake does not happen until the entry
//            clock, which is what `unhalt_pend` carries.
//
// The INT wake is IE-INDEPENDENT (measured, and it is where the V30 differs
// from the 8086): a masked INT resumes the stream without vectoring, which is
// the same `S_OPC_POP` with `irq_take` false.
wire hlt_wake_int = (st == S_HALTED) && !s1w_irq_nmi_lvl && s1w_irq_pin_int;
assign eu_unhalt = hlt_wake_int || unhalt_pend;

// F43 -- THE HALT-DISPLAY DECISION MUST TEST THE WAKE VISIBLE ON ITS OWN
// DECISION EDGE.  M20 threshold 1 says the display at clock `H` is suppressed
// when the wake decision `D` satisfies `D <= H`; `D = A + 3` is MEASURED at
// 100 % on all four `evt` cells.  The BIU decides the display at the edge
// ending `H-1`, where `eu_unhalt` reads `int_p[2]` (the pin at `c-3`) and so
// is true only for `D <= H-1`.  The remaining case `D == H` is visible AT THAT
// SAME EDGE one stage further down: `int_p[1]`, the pin at `c-2`.  Both taps
// are `edge - 4`; what changed is the REFERENCE EDGE (F40's shape).
wire hlt_wake_disp = (st == S_HALTED) && !s1w_irq_nmi_lvl && int_p[1];

// F54 (SM3 sitting 17) -- ...AND THE NMI HALF OF THE SAME SENTENCE.  MEASURED
// on the S16 display walk, 1,512 retained captures, `sw/sm3_haltsupp.py chip`:
// the HALT announcement at `H` is cancelled iff the assert clock `A` satisfies
// `A <= H - K`, with **K = 3 on the INT pin and K = 6 on the NMI pin** --
// one value per pin, invariant over the four wait levels, over six programs
// per form, and over IE (`HLT.INT` ie=1 and `HLT.RES` ie=0 share K=3).
//
// The INT half is already right, and it is right in TWO places: `eu_unhalt`
// clears the BIU's `halt_pending` outright (`v30u_biu.sv` "if (eu_unhalt)"),
// which covers every `A <= H-4`, and `eu_unhalt_disp` above covers the single
// remaining `D == H` clock.  The NMI wake reaches NEITHER until `unhalt_pend`,
// which `S_IRQ_D` sets at `c0+2` and which therefore reads true only from
// `c0+3 = A+7` -- so the ucore's effective K was **8**, and the 42 S16 cells
// at `A` in {H-7, H-6} are exactly that difference.  (S17 candidate V-A put
// `irq_nmi_lvl` in `hlt_wake_disp`; that test is ONE clock long, so it reached
// exactly `A == H-5` and nothing else.  It broke the 24 cells that predicts
// and closed none of the 42 -- registered, measured, reverted.)
//
// `c0` is the first `S_HALTED` clock with `nmi_latch` up.  The EU leaves
// `S_HALTED` on that edge and does not clear `eu_halted` until `S_IRQ_D`, so
// `eu_halted && (st != S_HALTED)` is true across `c0+1 .. c0+2` and
// `unhalt_pend` takes over at `c0+3`: the union is `c >= c0+1`, and the
// display decided at the edge ending `H-1` is therefore cancelled iff
// `c0 + 1 <= H - 1`, i.e. `A + 5 <= H - 1`, i.e. **`A <= H - 6`**.
// NO FLOP IS ADDED and no pin is tested: `eu_halted` and `st <= S_HALTED` are
// written in the SAME arm (`S_DECODE2`), so the term is false everywhere
// before the HALT, and the INT wake clears `eu_halted` in the same arm that
// leaves `S_HALTED`, so it is false there too.  It is NMI-specific by
// construction.
//   *Falsifier*: a silicon capture whose HALT announcement fires with the NMI
//   asserted at `A <= H-6`, or is cancelled with it asserted at `A >= H-5`.
wire hlt_wake_nmi_disp = eu_halted && (st != S_HALTED);
assign eu_unhalt_disp = hlt_wake_disp || unhalt_pend || hlt_wake_nmi_disp;

// CITF follows the interrupt prologue's FLAGS->OPR F row.  Its clear rail
// reaches the package-status mux through the ROM lookahead while that row
// retires, before the flag register itself is written.  The existing OPR-free
// rail is the row's enable; no history or interrupt-specific state is added.
wire citf_status_pre = (st == S_ROW) && (upc_page == 3'd7) &&
                       ((upc_opc == 8'h10) || (upc_opc == 8'h18)) &&
                       (upc_loc == 4'd8) && s1w_opr_free_now;
assign psw_ie  = psw[FIE] && !citf_status_pre;
assign md8080  = mode8080;

//----------------------------------------------------------------------------
// the backdoor / debug view
//----------------------------------------------------------------------------
assign dbg_regs = {psw, pc, sreg[3], sreg[2], sreg[1], sreg[0],
                   gpr[7], gpr[6], gpr[5], gpr[4],
                   gpr[3], gpr[2], gpr[1], gpr[0]};
assign dbg_first_pop = first_pop_seen;
assign dbg_pend = (rd_pending != 2'd0) || (rdq_n != 2'd0) || poste;

//--------------------------------------------------------------------------
// THE RESET NEXT-STATE (U4 pass 3, second structural pass -- sec.52.3)
//--------------------------------------------------------------------------
// `srst` used to be an ARM of the run next-state function, which put it in
// the same expression tree as the twelve-position chain and let Quartus
// distribute it through the whole cone -- measured: `c_reset_q` ->
// `v30u_eu|wb_seg[0]~0` -> `v30u_biu|q_ripe_lead_n` -> twelve chain
// positions -> `opc_base[4]`, 58.9 ns against a 31.25 ns requirement, and
// NOT coverable by the CE multicycle because it LAUNCHES OUTSIDE THE CORE
// (`system_large.sv:372`: `core_reset = c_reset_q | ~cfg_use_core`).
//
// Given its own function, the reset value is constants + the pin levels +
// the backdoor and nothing else, `_n` is provably independent of `srst`,
// and the register bank picks between them.  Same medicine as the CE fix
// and the same expectation: zero ladder deltas.
reg     [15:0] gpr_r [0:7];
reg     [15:0] sreg_r [0:3];
reg     [15:0] pc_r;
reg     [15:0] psw_r;
reg     [15:0] tmpa_r;
reg            tmpa_byte_r, tmpb_byte_r, tmpc_byte_r;
reg            opr_byte_r;
reg     [15:0] tmpb_r;
reg     [15:0] tmpc_r;
reg     [15:0] ea_residue_r;
reg     [15:0] ea_pair_rhs_r;
reg            ea_pair_valid_r;
reg     [15:0] opr_r;
reg     [15:0] ind_r;
reg     [15:0] count_r;
reg      [7:0] pfxcnt_r;
reg     [15:0] stat_r;
reg            sign_neg_r;
reg      [3:0] bit_n_r;
reg      [4:0] al_op_r;
reg      [1:0] al_tmp_r;
reg            al_eaconst_r;
reg     [15:0] al_eaval_r;
reg      [1:0] al_adjust_r;
reg      [1:0] al_adjtmp_r;
reg            al_bitarm_r;
reg      [3:0] al_bitn_r;
reg            al_spent_r;
reg      [2:0] upc_page_r;
reg      [7:0] upc_opc_r;
reg      [3:0] upc_loc_r;
reg            seg_override_r;
reg      [1:0] seg_ovr_r;
reg      [2:0] rep_kind_r;
reg            lock_pfx_r;
reg      [7:0] opc_reg_r;
reg            op8_r;
reg            imm8_r;
reg      [4:0] opc_base_r;
reg            opc_from_modrm_r;
reg      [2:0] modrm_reg_r;
reg      [3:0] xop_r;
reg      [1:0] rep_test_r;
reg            rep_pol_r;
reg            bus_word_r;
reg            opc8080_r;
reg            mode8080_r;
reg            intr_pending_r;
reg            eu_halted_r;
reg      [3:0] int_p_r;
reg      [4:0] nmi_p_r;
reg            nmi_latch_r;
reg      [3:0] ie_p_r;
reg            rep_chain_r;
reg            irq_shadow_r;
reg            bnd_armed_r;
reg            irq_sel_nmi_r;
reg            irq_sel_brk_r;
reg [BRK_FLOOR-1:0] brk_p_r;
reg            brk_arm_r;
reg            brk_smp_r;
reg            unhalt_pend_r;
reg            irq_fast_inta_r;
reg            irq_halt_entry_r;
reg      [1:0] m_kind_r;
reg      [1:0] r_kind_r;
reg      [1:0] wb_kind_r;
reg      [2:0] m_idx_r;
reg      [2:0] r_idx_r;
reg      [2:0] wb_idx_r;
reg     [15:0] m_ea_r;
reg     [15:0] r_ea_r;
reg     [15:0] wb_ea_r;
reg      [2:0] m_seg_r;
reg      [2:0] r_seg_r;
reg      [2:0] wb_seg_r;
reg            m_byte_r;
reg            r_byte_r;
reg            wb_byte_r;
reg            pend_active_r;
reg     [15:0] pend_off_r;
reg      [2:0] pend_seg_r;
reg            pend_byte_r;
reg            pend_io_r;
reg            opr_fresh_r;
reg            opr_loaded_r;
reg            rdp0_byte_r, rdp1_byte_r;
reg            rdq0_byte_r, rdq1_byte_r;
reg     [15:0] rdq0_r;
reg     [15:0] rdq1_r;
reg      [1:0] rdq_n_r;
reg      [1:0] rd_pending_r;
reg            ghost_rd_discard_r;
reg      [1:0] rd_done_cnt_r;
reg            rd_age0_r;
reg            iend_owed_r;
reg      [2:0] rst_ctr_r;
reg     [15:0] tsel_r;
reg      [7:0] pe_opc_reg_r;
reg            pe_opc8080_r;
reg            pe_op8_r;
reg      [7:0] pe_pfxcnt_r;
reg      [1:0] wr_out_r;
reg            opc_valid_r;
reg      [7:0] opc_byte_r;
reg            pop_is_first_r;
reg      [7:0] ld_b_r;
reg     [13:0] ld_pla_r;
reg            ld_ext_r;
reg      [2:0] ld_page_r;
reg            ld_hasrm_r;
reg      [7:0] ld_rm_r;
reg     [15:0] ld_disp_r;
reg      [7:0] ld_dlo_r;
reg            ld_grpd_r;
reg            ld_byte_r;
reg            ld_preread_r;
reg            ld_ripe_prev_r;
reg      [5:0] st_r;
reg      [1:0] chg_r;
reg            ending_r;
reg      [1:0] rowq_r;
reg            row_posted_r;
reg            row_paired_r;
reg     [15:0] rloop_n_r;
reg            suppress_commit_r;
reg            first_pop_seen_r;
reg      [7:0] rowb0_r;
reg      [7:0] rowb1_r;
reg            poste_r;
reg      [2:0] poll_pipe_r;

integer rsi;                // the reset function's own array index
always @* begin
    //-- preload, so an unassigned reset arm holds rather than latches
    for (rsi = 0; rsi < 8; rsi = rsi + 1) gpr_r[rsi] = gpr[rsi];
    for (rsi = 0; rsi < 4; rsi = rsi + 1) sreg_r[rsi] = sreg[rsi];
    pc_r = pc;
    psw_r = psw;
    tmpa_r = tmpa;
    tmpa_byte_r = tmpa_byte;
    tmpb_byte_r = tmpb_byte;
    tmpc_byte_r = tmpc_byte;
    opr_byte_r = opr_byte;
    tmpb_r = tmpb;
    tmpc_r = tmpc;
    ea_residue_r = ea_residue;
    ea_pair_rhs_r = ea_pair_rhs;
    ea_pair_valid_r = ea_pair_valid;
    opr_r = opr;
    ind_r = ind;
    count_r = count;
    pfxcnt_r = pfxcnt;
    stat_r = stat;
    sign_neg_r = sign_neg;
    bit_n_r = bit_n;
    al_op_r = al_op;
    al_tmp_r = al_tmp;
    al_eaconst_r = al_eaconst;
    al_eaval_r = al_eaval;
    al_adjust_r = al_adjust;
    al_adjtmp_r = al_adjtmp;
    al_bitarm_r = al_bitarm;
    al_bitn_r = al_bitn;
    al_spent_r = al_spent;
    upc_page_r = upc_page;
    upc_opc_r = upc_opc;
    upc_loc_r = upc_loc;
    seg_override_r = seg_override;
    seg_ovr_r = seg_ovr;
    rep_kind_r = rep_kind;
    lock_pfx_r = lock_pfx;
    opc_reg_r = opc_reg;
    op8_r = op8;
    imm8_r = imm8;
    opc_base_r = opc_base;
    opc_from_modrm_r = opc_from_modrm;
    modrm_reg_r = modrm_reg;
    xop_r = xop;
    rep_test_r = rep_test;
    rep_pol_r = rep_pol;
    bus_word_r = bus_word;
    opc8080_r = opc8080;
    mode8080_r = mode8080;
    intr_pending_r = intr_pending;
    eu_halted_r = eu_halted;
    int_p_r = int_p;
    nmi_p_r = nmi_p;
    nmi_latch_r = nmi_latch;
    ie_p_r = ie_p;
    rep_chain_r = rep_chain;
    irq_shadow_r = irq_shadow;
    bnd_armed_r = bnd_armed;
    irq_sel_nmi_r = irq_sel_nmi;
    irq_sel_brk_r = irq_sel_brk;
    brk_p_r = brk_p;
    brk_arm_r = brk_arm;
    brk_smp_r = brk_smp;
    unhalt_pend_r = unhalt_pend;
    irq_fast_inta_r = irq_fast_inta;
    irq_halt_entry_r = irq_halt_entry;
    m_kind_r = m_kind;
    r_kind_r = r_kind;
    wb_kind_r = wb_kind;
    m_idx_r = m_idx;
    r_idx_r = r_idx;
    wb_idx_r = wb_idx;
    m_ea_r = m_ea;
    r_ea_r = r_ea;
    wb_ea_r = wb_ea;
    m_seg_r = m_seg;
    r_seg_r = r_seg;
    wb_seg_r = wb_seg;
    m_byte_r = m_byte;
    r_byte_r = r_byte;
    wb_byte_r = wb_byte;
    pend_active_r = pend_active;
    pend_off_r = pend_off;
    pend_seg_r = pend_seg;
    pend_byte_r = pend_byte;
    pend_io_r = pend_io;
    opr_fresh_r = opr_fresh;
    opr_loaded_r = opr_loaded;
    rdp0_byte_r = rdp0_byte;
    rdp1_byte_r = rdp1_byte;
    rdq0_byte_r = rdq0_byte;
    rdq1_byte_r = rdq1_byte;
    rdq0_r = rdq0;
    rdq1_r = rdq1;
    rdq_n_r = rdq_n;
    rd_pending_r = rd_pending;
    ghost_rd_discard_r = ghost_rd_discard;
    rd_done_cnt_r = rd_done_cnt;
    rd_age0_r = rd_age0;
    iend_owed_r = iend_owed;
    rst_ctr_r = rst_ctr;
    tsel_r = tsel;
    pe_opc_reg_r = pe_opc_reg;
    pe_opc8080_r = pe_opc8080;
    pe_op8_r = pe_op8;
    pe_pfxcnt_r = pe_pfxcnt;
    wr_out_r = wr_out;
    opc_valid_r = opc_valid;
    opc_byte_r = opc_byte;
    pop_is_first_r = pop_is_first;
    ld_b_r = ld_b;
    ld_pla_r = ld_pla;
    ld_ext_r = ld_ext;
    ld_page_r = ld_page;
    ld_hasrm_r = ld_hasrm;
    ld_rm_r = ld_rm;
    ld_disp_r = ld_disp;
    ld_dlo_r = ld_dlo;
    ld_grpd_r = ld_grpd;
    ld_byte_r = ld_byte;
    ld_preread_r = ld_preread;
    ld_ripe_prev_r = ld_ripe_prev;
    st_r = st;
    chg_r = chg;
    ending_r = ending;
    rowq_r = rowq;
    row_posted_r = row_posted;
    row_paired_r = row_paired;
    rloop_n_r = rloop_n;
    suppress_commit_r = suppress_commit;
    first_pop_seen_r = first_pop_seen;
    rowb0_r = rowb0;
    rowb1_r = rowb1;
    poste_r = poste;
    poll_pipe_r = poll_pipe;

        //--------------------------------------------------------------------
        // RESET == begin_case() plus the backdoor injection
        //--------------------------------------------------------------------
        for (rsi = 0; rsi < 8; rsi = rsi + 1) gpr_r[rsi] = 16'd0;
        for (rsi = 0; rsi < 4; rsi = rsi + 1) sreg_r[rsi] = 16'd0;
        pc_r = 16'd0; psw_r = PSW_FORCED;
        tmpa_r = 16'd0; tmpb_r = 16'd0; tmpc_r = 16'd0;
        tmpa_byte_r = 1'b0; tmpb_byte_r = 1'b0; tmpc_byte_r = 1'b0;
        opr_byte_r = 1'b0;
        ea_residue_r = 16'd0;
        ea_pair_rhs_r = 16'd0; ea_pair_valid_r = 1'b0;
        opr_r = 16'd0; ind_r = 16'd0; count_r = 16'd0; pfxcnt_r = 8'd0;
        stat_r = 16'd0; sign_neg_r = 1'b0; bit_n_r = 4'd0;
        al_op_r = A_ADD; al_tmp_r = 2'd0;
        al_eaconst_r = 1'b0; al_eaval_r = 16'd0;
        al_adjust_r = 2'd0; al_adjtmp_r = 2'd0; al_bitarm_r = 1'b0; al_bitn_r = 4'd0;
        al_spent_r = 1'b0;
        upc_page_r = 3'd0; upc_opc_r = 8'd0; upc_loc_r = 4'd0;
        seg_override_r = 1'b0; seg_ovr_r = 2'd3; rep_kind_r = REP_NONE;
        lock_pfx_r = 1'b0; opc_reg_r = 8'd0; op8_r = 1'b0; imm8_r = 1'b0;
        opc_base_r = 5'd0; opc_from_modrm_r = 1'b0; modrm_reg_r = 3'd0; xop_r = 4'd0;
        rep_test_r = TEST_NONE; rep_pol_r = 1'b0; bus_word_r = 1'b0;
        opc8080_r = 1'b0; mode8080_r = 1'b0; intr_pending_r = 1'b0; eu_halted_r = 1'b0;
        rep_chain_r = 1'b0;
        m_kind_r = OK_NONE; m_idx_r = 3'd0; m_ea_r = 16'd0; m_seg_r = 3'd3; m_byte_r = 1'b0;
        r_kind_r = OK_NONE; r_idx_r = 3'd0; r_ea_r = 16'd0; r_seg_r = 3'd3; r_byte_r = 1'b0;
        wb_kind_r = OK_NONE; wb_idx_r = 3'd0; wb_ea_r = 16'd0; wb_seg_r = 3'd3;
        wb_byte_r = 1'b0;
        pend_active_r = 1'b0; pend_off_r = 16'd0; pend_seg_r = 3'd3;
        pend_byte_r = 1'b0; pend_io_r = 1'b0; opr_fresh_r = 1'b0;
        opr_loaded_r = 1'b0;
        rdq0_r = 16'd0; rdq1_r = 16'd0; rdq_n_r = 2'd0;
        rdp0_byte_r = 1'b0; rdp1_byte_r = 1'b0;
        rdq0_byte_r = 1'b0; rdq1_byte_r = 1'b0;
        rd_pending_r = 2'd0; ghost_rd_discard_r = 1'b0;
        rd_done_cnt_r = 2'd0; rd_age0_r = 1'b0;
        iend_owed_r = 1'b0; pe_opc_reg_r = 8'd0; pe_opc8080_r = 1'b0; pe_op8_r = 1'b0;
        pe_pfxcnt_r = 8'd0;
        wr_out_r = 2'd0;
        opc_valid_r = 1'b0; opc_byte_r = 8'd0; pop_is_first_r = 1'b1;
        ld_b_r = 8'd0; ld_pla_r = 14'd0; ld_ext_r = 1'b0; ld_page_r = 3'd0;
        ld_hasrm_r = 1'b0; ld_rm_r = 8'd0; ld_disp_r = 16'd0; ld_dlo_r = 8'd0;
        ld_grpd_r = 1'b0; ld_byte_r = 1'b0; ld_preread_r = 1'b0; ld_ripe_prev_r = 1'b0;
        st_r = S_OPC_POP; chg_r = 2'd0; ending_r = 1'b0; poste_r = 1'b0;
        rowq_r = 2'd0; row_posted_r = 1'b0; row_paired_r = 1'b0; rloop_n_r = 16'd0;
        suppress_commit_r = 1'b0; first_pop_seen_r = 1'b0;
        rowb0_r = 8'd0; rowb1_r = 8'd0; poste_r = 1'b0;
        // the pin pipelines come out of reset holding the LEVEL they have been
        // seeing -- a shift register clocked since power-on cannot hold
        // anything else, and it is what `poll_busy()` / the INT sample assume.
        poll_pipe_r = {3{pin_poll_n}};
        int_p_r = {4{pin_int}}; nmi_p_r = {5{pin_nmi}}; ie_p_r = 4'd0;
        rep_chained = 1'b0;
        nmi_latch_r = 1'b0; irq_shadow_r = 1'b0; bnd_armed_r = 1'b0;
        irq_sel_nmi_r = 1'b0; unhalt_pend_r = 1'b0;
        irq_fast_inta_r = 1'b0;
        irq_halt_entry_r = 1'b0;
        irq_sel_brk_r = 1'b0; brk_p_r = '0; brk_arm_r = 1'b0;
        brk_smp_r = 1'b0;
        if (bkd_load) begin
            gpr_r[0] = bkd_regs[  0 +: 16];  gpr_r[1] = bkd_regs[ 16 +: 16];
            gpr_r[2] = bkd_regs[ 32 +: 16];  gpr_r[3] = bkd_regs[ 48 +: 16];
            gpr_r[4] = bkd_regs[ 64 +: 16];  gpr_r[5] = bkd_regs[ 80 +: 16];
            gpr_r[6] = bkd_regs[ 96 +: 16];  gpr_r[7] = bkd_regs[112 +: 16];
            sreg_r[0] = bkd_regs[128 +: 16]; sreg_r[1] = bkd_regs[144 +: 16];
            sreg_r[2] = bkd_regs[160 +: 16]; sreg_r[3] = bkd_regs[176 +: 16];
            pc_r = bkd_regs[192 +: 16];
            psw_r = (bkd_regs[208 +: 16] & PSW_WRITABLE) | PSW_FORCED;
        end else begin
            // F25 -- POWER-ON RESET IS A MICROCODE MARCH, not a state.
            // `CpuT::reset()` runs the ROM's own sequence at page 7 opcode
            // 00000011 (01D0..01D5: ZEROS -> DS/FLAGS/ES/SS, ONES -> CS,
            // ZEROS -> PC, FLUSH, MFS) and only THEN does the decoder see its
            // first byte.  The EU came out of reset in S_OPC_POP, so the whole
            // boot was seven clocks early and `check_boot --core ucore` broke
            // at release+7 (the real part shows the march's queue flush; the
            // EU had already popped).  A BACKDOOR-LOADED case starts mid-
            // stream and must NOT run it -- that is what `bkd_load` selects,
            // and it is why every v0.1 rung is unaffected.
            //
            // `run_timed_boot` states the geometry and the capture pins it:
            // the part comes out of reset with the PREFETCHER SUSPENDED (there
            // is no fetch pointer until 01D3 loads PS:PC and flushes), and the
            // internal dispatch is FOUR CLOCKS -- 01D0 runs at release+4, the
            // FLUSH row 01D3 at release+7 where the capture shows its `E`
            // blip, and the first CODE T1 at release+9.  Four clocks is the
            // one constant, not a per-row cost.
            upc_page_r = 3'd7;
            upc_opc_r  = 8'h03;
            upc_loc_r  = 4'd0;
            rst_ctr_r  = 3'd0;
            st_r = S_RESET;
        end
        ie_p_r = {4{psw_r[FIE]}};      // ...and so does the IE gate's own pipeline
end

//==========================================================================
// THE NEXT-STATE SHADOW  (U4 pass 3 -- the ENABLE-FORM refactor, sec.51.7)
//==========================================================================
// One `_n` per state register.  The clocked body below is now an `always @*`
// that preloads these from the flops and works on them with the SAME blocking
// assignments it always used -- so `_n` IS what a blocking write to the
// register meant there, and a module-level wire still reads the FLOP, i.e.
// the PRE-EDGE view this whole module is built on (F11b; see the recognition
// block's `EVERY read of these registers from inside the clocked step goes
// through these wires' note).  That is why the flops keep their names and the
// body was renamed, and not the other way round: nothing outside the body
// moves, so no combinational reader changes what it sees.
//
// THE POINT IS THE COMMIT.  `always @(posedge clk) if (ss_we||srst||ce)` puts
// CE on the register's ENABLE PORT.  Before this, `ce` was threaded through
// the EU's 61-level combinational cone to every FF's DATA input; Quartus
// extracted no clock enable (`report_timing`: `div_cnt[1]` -> `m_kind[0]`,
// 61 logic levels, terminating on `datac`/`dataf` and no `ena` node anywhere),
// so the registers clocked every SYS clock and the multicycle exception the
// divided CPU clock earns was INVALID BY ITS OWN FALSIFIER (sec.51.7).  `ce`
// does not appear in this cone at all now -- the body's third arm is the
// unconditional `else`.
//
// `upc_page_n` / `upc_opc_n` / `upc_loc_n` exist as wires as a free
// consequence -- the only thing a registered microcode ROM ever needed.
//
// *Falsifier*: a `v30u_eu` state register with no `ena` in the post-fit
// netlist, or a ladder cell that moves.  This is a SYNTHESIS-SHAPE change and
// the expectation is zero deltas.
reg     [15:0] gpr_n [0:7];
reg     [15:0] sreg_n [0:3];
reg     [15:0] pc_n;
reg     [15:0] psw_n;
reg     [15:0] tmpa_n;
reg            tmpa_byte_n, tmpb_byte_n, tmpc_byte_n;
reg            opr_byte_n;
reg     [15:0] tmpb_n;
reg     [15:0] tmpc_n;
reg     [15:0] ea_residue_n;
reg     [15:0] ea_pair_rhs_n;
reg            ea_pair_valid_n;
reg     [15:0] opr_n;
reg     [15:0] ind_n;
reg     [15:0] count_n;
reg      [7:0] pfxcnt_n;
reg     [15:0] stat_n;
reg            sign_neg_n;
reg      [3:0] bit_n_n;
reg      [4:0] al_op_n;
reg      [1:0] al_tmp_n;
reg            al_eaconst_n;
reg     [15:0] al_eaval_n;
reg      [1:0] al_adjust_n;
reg      [1:0] al_adjtmp_n;
reg            al_bitarm_n;
reg      [3:0] al_bitn_n;
reg            al_spent_n;
reg      [2:0] upc_page_n;
reg      [7:0] upc_opc_n;
reg      [3:0] upc_loc_n;
reg            seg_override_n;
reg      [1:0] seg_ovr_n;
reg      [2:0] rep_kind_n;
reg            lock_pfx_n;
reg      [7:0] opc_reg_n;
reg            op8_n;
reg            imm8_n;
reg      [4:0] opc_base_n;
reg            opc_from_modrm_n;
reg      [2:0] modrm_reg_n;
reg      [3:0] xop_n;
reg      [1:0] rep_test_n;
reg            rep_pol_n;
reg            bus_word_n;
reg            opc8080_n;
reg            mode8080_n;
reg            intr_pending_n;
reg            eu_halted_n;
reg      [3:0] int_p_n;
reg      [4:0] nmi_p_n;
reg            nmi_latch_n;
reg      [3:0] ie_p_n;
reg            rep_chain_n;
reg            irq_shadow_n;
reg            bnd_armed_n;
reg            irq_sel_nmi_n;
reg            irq_sel_brk_n;
reg [BRK_FLOOR-1:0] brk_p_n;
reg            brk_arm_n;
reg            brk_smp_n;
reg            unhalt_pend_n;
reg            irq_fast_inta_n;
reg            irq_halt_entry_n;
reg      [1:0] m_kind_n;
reg      [1:0] r_kind_n;
reg      [1:0] wb_kind_n;
reg      [2:0] m_idx_n;
reg      [2:0] r_idx_n;
reg      [2:0] wb_idx_n;
reg     [15:0] m_ea_n;
reg     [15:0] r_ea_n;
reg     [15:0] wb_ea_n;
reg      [2:0] m_seg_n;
reg      [2:0] r_seg_n;
reg      [2:0] wb_seg_n;
reg            m_byte_n;
reg            r_byte_n;
reg            wb_byte_n;
reg            pend_active_n;
reg     [15:0] pend_off_n;
reg      [2:0] pend_seg_n;
reg            pend_byte_n;
reg            pend_io_n;
reg            opr_fresh_n;
reg            opr_loaded_n;
reg            rdp0_byte_n, rdp1_byte_n;
reg            rdq0_byte_n, rdq1_byte_n;
reg     [15:0] rdq0_n;
reg     [15:0] rdq1_n;
reg      [1:0] rdq_n_n;
reg      [1:0] rd_pending_n;
reg            ghost_rd_discard_n;
reg      [1:0] rd_done_cnt_n;
reg            rd_age0_n;
reg            iend_owed_n;
reg      [2:0] rst_ctr_n;
reg     [15:0] tsel_n;
reg      [7:0] pe_opc_reg_n;
reg            pe_opc8080_n;
reg            pe_op8_n;
reg      [7:0] pe_pfxcnt_n;
reg      [1:0] wr_out_n;
reg            opc_valid_n;
reg      [7:0] opc_byte_n;
reg            pop_is_first_n;
reg      [7:0] ld_b_n;
reg     [13:0] ld_pla_n;
reg            ld_ext_n;
reg      [2:0] ld_page_n;
reg            ld_hasrm_n;
reg      [7:0] ld_rm_n;
reg     [15:0] ld_disp_n;
reg      [7:0] ld_dlo_n;
reg            ld_grpd_n;
reg            ld_byte_n;
reg            ld_preread_n;
reg            ld_ripe_prev_n;
reg      [5:0] st_n;
reg      [1:0] chg_n;
reg            ending_n;
reg      [1:0] rowq_n;
reg            row_posted_n;
reg            row_paired_n;
reg     [15:0] rloop_n_n;
reg            suppress_commit_n;
reg            first_pop_seen_n;
reg      [7:0] rowb0_n;
reg      [7:0] rowb1_n;
reg            poste_n;
reg      [2:0] poll_pipe_n;

//============================================================================
// THE CLOCK
//============================================================================
`ifndef JTV30_SYNTHESIS
reg eutrace = 0;
initial if ($test$plusargs("eutrace")) eutrace = 1;
// §86 -- THE ARM'S OWN INSTRUMENT, and it is the one the model already has
// (`V30SIM_BRKTRACE`).  One line per SAMPLE INSTANT and one per TAKE, so the
// RTL's coordinate can be checked against the model's retire stream on
// captures with TF CLEAR -- no trap in the loop, which is what makes it a
// ruler rather than a score.  §85.2a's acceptance test, RTL side.
reg brktrace = 0;
initial if ($test$plusargs("brktrace")) brktrace = 1;
// the CE clock index, on the same contract the eutrace line number carries
// ("row index == CE clock index"): cleared by `srst`, advanced once per
// enabled clock.  Simulation only.
int unsigned ce_clk = 0;
// §86.G -- THE TWO FLAG-WRITE PROBES, and they are why `mc1/721` is decided.
// `1BL` reports every ONE_BYTE_LOGIC execute strobe's PSW before and after;
// `PE` reports every POST-`E` discharge's, with the row it is discharging.
// Together they say WHICH of two writes to the same register landed and IN
// WHAT ORDER -- which the save-state map's PSW word alone cannot, because both
// orders can end on the same value.  Simulation only, `+brktrace`, and they read registers.
reg [15:0] trc_1bl_pre, trc_1bl_post; reg trc_1bl_hit;
reg [15:0] trc_pe_pre, trc_pe_post; reg trc_pe_hit; reg [11:0] trc_pe_upc;
// wrfuzz W3.5 -- THE 1BL DECODE PROBE, and it exists to answer ONE question
// with a measurement instead of an assumption: `wrfuzz_provenance.md` §7.8
// booked "`irq_shadow` is a FLOP, so `brk_arm` and `brk_take` are not
// interchangeable in the RTL -- MEASURE it, do not assume it."  The thing that
// actually has to be measured is narrower and it is the ARM'S AVAILABILITY:
// `S_DECODE2`'s 1BL arm runs INSIDE the chain that the opcode pop rode, and
// `brk_smp` -- the sample instant §85.2a fixed at pop + 1 -- has not happened
// yet.  This line reports, at every 1BL decode, the four bits the gate could
// be written on (`q_ripe_lead_n`, `brk_seen`, `brk_arm`, `brk_smp_n`) so the
// difference between them is a number in a log and not a claim.
// Simulation only, `+brktrace`; reads registers and settled comb.
reg trc_1bld_hit, trc_1bld_ripe, trc_1bld_seen, trc_1bld_arm, trc_1bld_smp;
reg trc_1bld_shd;   // ...and `irq_shadow_n`, which §7.8 names by hand
reg chain_report = 0;
initial if ($test$plusargs("chaindepth")) chain_report = 1;
reg [3:0] chain_hi = 4'd0;
reg [3:0] chain_used;   // <- now a COMB output of the next-state block
// WAVE 7: `stop` still low when the FLATTENED pass runs out of positions.
// The loop's own `!stop` test used to say this; the flat pass has to record
// it, because it must ALSO end the edge (see the pass, and the observer).
reg        chain_open;
// the eutrace SNAPSHOT: the flop-valued fields the trace line used to
// read MID-EDGE (after blocks (a)/(b), before the chain).  Everything
// else it prints is a module-level wire, which the observer reads at the
// edge and therefore reads pre-edge exactly as the old code did.
reg      [5:0] trc_st;
reg      [2:0] trc_upc_page;
reg      [7:0] trc_upc_opc;
reg      [3:0] trc_upc_loc;
reg      [1:0] trc_wr_out;
reg     [15:0] trc_pc;
reg     [15:0] trc_ind;
reg     [15:0] trc_opr;
reg            trc_opr_fresh;
reg            trc_pend_active;
reg            trc_poste;
reg      [1:0] trc_rdq_n;
reg      [1:0] trc_rd_done_cnt;
reg     [15:0] trc_tmpa;
reg     [15:0] trc_tmpb;
reg     [15:0] trc_tmpc;
reg [5:0] chain_first;
`ifdef CHAIN_PROBE
reg cp_seen [0:1023];
integer cpi;
// WAVE 7: the probe's file handle is a MODULE-LEVEL name, not a `begin : x`
// local, because `v30u_eu_chain_pos.svh` is elaborated once per chain
// position and a named block may not be declared ten times in one scope.
integer cp_fd;
initial for (cpi = 0; cpi < 1024; cpi = cpi + 1) cp_seen[cpi] = 1'b0;
//--------------------------------------------------------------------------
// WAVE 6 (THE CHAIN FLATTENING STUDY) -- THE SEQUENCE CENSUS.
//
// `cp_seen` above answers "which (position, state) PAIRS occur"; that is what
// sec.51.2 measured and it cannot say which SEQUENCES a clock actually walks.
// This records the ORDERED tuple of states occupying positions 0..chain_used-1
// of one CE edge, de-duplicates it, and counts it.
//
// ⚠ THE TUPLE IS FILLED IN THE COMBINATIONAL CHAIN BLOCK AND READ IN THE
// CLOCKED OBSERVER, which is the SAME discipline `stop` / `chain_used` /
// `chain_first` already use and for the same reason: a comb block re-evaluates
// many times per delta, so a census taken inside it would count settling.  The
// observer runs ONCE per CE clock on the settled values.
//
// SIM-ONLY AND OFF BY DEFAULT.  `CHAIN_PROBE` is undefined unless a driver
// defines it; nothing here is compiled otherwise, and no synthesis flow
// defines it.
localparam int CP_SLOTS = 8192;          // linear-probed, power of two
reg [41:0] cp_key  [0:CP_SLOTS-1];       // 7 positions x 6 bits, 6'h3F = absent
reg        cp_val  [0:CP_SLOTS-1];
integer    cp_cnt  [0:CP_SLOTS-1];
reg  [5:0] cp_seq  [0:15];               // this edge's occupancy, by position
integer    cp_used;                      // ...how many of them are live
integer    cp_nseq;                      // distinct sequences seen
integer    cp_edges;                     // CE edges censused
integer    cpj;
initial begin
    for (cpi = 0; cpi < CP_SLOTS; cpi = cpi + 1) begin
        cp_val[cpi] = 1'b0;
        cp_key[cpi] = 42'd0;
        cp_cnt[cpi] = 0;
    end
    for (cpi = 0; cpi < 16; cpi = cpi + 1) cp_seq[cpi] = 6'h3F;
    cp_nseq = 0;
    cp_edges = 0;
    cp_used = 0;
end
`endif
`endif

// The bounded zero-cost chain.  See THE FLATTENED PASS at the bottom of the
// clocked block: `CHAIN_MAX` is how many of the model's zero-cost steps may
// ride one clock.
//
// ⚠ WHAT THIS NUMBER COSTS CHANGED AT WAVE 7, AND WHAT IT CLAIMS DID NOT.
// It used to be the count of UNROLLED COPIES of the 33-arm step case, so the
// bound was enforced by construction and the `$fatal` detected the
// enforcement biting.  The pass is now FLAT -- position 0's case once, then
// the nine chainable arms once each in topological order -- so it provides
// nine positions >= 1 structurally and `CHAIN_MAX` costs NOTHING.  It is
// therefore a PURE CLAIM now, and it is checked directly against the measured
// depth in the observer (`chain_used > CHAIN_MAX - 1`).  **The claim is the
// same claim; it is asserted more directly than before, and the value is
// unchanged so that every historical figure stays comparable.**
//
// **7 = the derived maximum occupancy 6, PLUS ONE SPARE POSITION**, because
// fabric has no assertion.  It was 12 until 2026-08-12.
//
// THE BOUND IS 6 AND THREE SOURCES SAY SO, none of which is a gate:
//   1. sec.51.2's transition-graph argument -- only NINE of the 24 states hand
//      over without setting `stop` -- plus its (position, state) census over
//      347 golden forms x 12 waits and the boot march: 24 / 9 / 5 / 3 / 2 / 1.
//   2. `m72_downstream_timing_2026-08-12.md` sec.3: the same graph re-derived
//      independently in another repo, same nine states, same depth 6.
//   3. `hdl/tb/tb_chain_lfsr.sv`: an ALL-LFSR environment executing arbitrary
//      bytes -- nothing in common with the golden suite -- reporting
//      CHAIN_DEPTH_MAX 6, entry state 25 (`S_EPOP`), on every seed.
//
// **THE GATE IS THE `CHAIN OVERFLOW` $fatal BELOW**, and it is what makes the
// tightening safe rather than merely agreed-upon.  sec.51.2 declined to tighten
// precisely because tightening MAKES a claim; the claim is now made, and it is
// asserted continuously over every population this tree runs.
//
// ⚠ THE `[3:0]` WIDTH DOES NOT NARROW WITH THE BOUND.  `chain_used` counts
// positions and is compared against `CHAIN_MAX - 1`; at `[2:0]` the count and
// the bound would both wrap and the check would silently stop meaning what it
// says.  It also keys `CHAIN_PROBE`'s `{position, st_n}` census.  The width is
// what makes 8 representable and it stays.
//
// ⚠ AND THE DECLARATION'S SHAPE IS PART OF A GATE.  `sw/chain_lfsr_gate.py`
// READS THIS LINE -- it refuses to carry a second copy of the number it is
// checking -- and its `--nonvacuity` mode rewrites it to `4'd4` in a scratch
// copy and REQUIRES the `$fatal`.  Change the text and you change a gate.
localparam bit [3:0] CHAIN_MAX = 4'd7;

integer i;
integer ci;                 // the commit block's own index
reg        stop;
reg  [3:0] chain;
reg [15:0] v1, v2;
reg        bsw;             // the row's byte-source flag (Q / CONST)
reg        wb1, wb2;        // ...and the two transfers' OPERAND-WIDTH tags
reg        rdh_byte;        // the completing read's tag, off the record's head
reg [13:0] pv;
reg  [3:0] nloc;
reg        carry, taken, bubble, retire_now;
reg        rep_chained;  // ...and the value `rep_chain` had at THIS boundary
reg        ie_now;      // block (g): the IE the gate's pipeline takes
reg        brk_now;     // §86: ...and the TF the arm's pipeline takes
reg [15:0] ea;
reg  [2:0] rseg;
reg  [1:0] rmmod;
reg  [2:0] rmreg, rmrm;
reg  [1:0] tk;
reg  [2:0] ti, ts;
reg [15:0] te;
reg        tb;

`define SETPSW(v) begin psw_n = ((v) & PSW_WRITABLE) | PSW_FORCED; end

// commit_flags
task automatic commit_flags(input [15:0] mask, input [15:0] fl);
    begin
        psw_n = ((psw_n & ~mask) | (fl & mask));
        psw_n = (psw_n & PSW_WRITABLE) | PSW_FORCED;
    end
endtask

//--------------------------------------------------------------------------
// THE NEXT-STATE FUNCTION.  This was `always @(posedge clk)` with blocking
// assignments; it is the SAME code on `_n`, and the only behavioural change
// is that `ce` no longer appears in it -- the third arm is the unconditional
// `else`, because a CE-low clock is now expressed by the COMMIT BLOCK not
// capturing rather than by this block not running.
//--------------------------------------------------------------------------
//==========================================================================
// THE CUT SET -- STAGE 1's WIRE CONE, GIVEN A NAME STAGE 2 CANNOT REACH
//                                                     (WAVE 4, 2026-09-08)
//==========================================================================
// WAVE 2 put the loop-carried `_n` set in the shadow and MEASURED that the
// binding path did not touch it: 103 arrival points, ZERO named it
// (`phase_split_landing_results_2026-09-08.md` §11.6).  The reason is in the
// source and not in the netlist -- `row` and its field decodes are
// module-level WIRES, and the chain body reads them LIVE.  A register beside
// a loop is not a cut of it.
//
// SO THE CROSSING SET IS *EVERY MODULE-LEVEL WIRE THE NEXT-STATE BLOCK
// READS*, and it is derived from the source rather than chosen:
// `sw/cutset_census.py` walks the module's continuous assignments, taints
// from `r7_lint`'s own live set (the three asynchronous pins, the ONE
// declared live-`READY` carrier `eu_rd_edge` with its data twin, and the TWO
// declared UNRESOLVED carriers `eu_slot_busy_n` / `q_ripe_lead_n`), and
// returns 80 names / 283 bits with **ZERO live-tainted**.
// The union of module INPUTS their cones reach is seven -- `eu_access_active`,
// `eu_opr_free`, `eu_rd_done_n`, `eu_slot_busy`, `eu_wr_done_n`, `eu_wr_eval`,
// `q_byte` -- every one of them the BIU's own REGISTERED view (v30u_biu.sv's
// "THE EU CONTRACT"), and none of them downstream of `t1_half2`, which has
// zero consumers in the BIU's next-state logic.  So the whole cone is
// PHASE-STABLE and the set is not a subset chosen for convenience.
//
// HOW STAGE 2 IS MADE UNABLE TO NAME THE PRE-CUT VALUE, WHICH IS THE WHOLE
// POINT: each wire keeps its logic under the name `s1w_<x>` and the SHORT
// name becomes one of these `reg`s.  STAGE 1 assigns `<x> = s1w_<x>` once,
// at its head; the reg joins the pack and the unpack; and every reference
// inside the block -- `v30u_eu_step.svh` included, which is NOT EDITED BY
// THIS -- now binds to the shadowed reg.  A stage-2 read of the live value
// would have to write `s1w_`, and `sw/cutset_lint.py` fails if it ever does.
//
// ⚠ THE MODULE'S COMBINATIONAL OUTPUTS STILL READ `s1w_*` LIVE, AND THAT IS
// DELIBERATE.  The act decode (`q_pop`, `eu_post`, `eu_pair`, `eu_addr`, ...)
// is consumed by the BIU on the clock that names it and must be decided from
// the level DURING that clock; feeding it the shadow would be identical by
// the phase-stability theorem and would put a `ce_half` flop in front of a
// pin for no reason.  Those paths are `ce -> ce` and are NOT divided by this
// cut; C-8 measures them.
reg [28:0]     row;
reg [4:0]      r_aluop;
reg [1:0]      r_alutmp;
reg [3:0]      r_cond;
reg [3:0]      r_loc;
reg [4:0]      r_farloc;
reg [4:0]      e_s1;
reg [4:0]      e_d1;
reg [3:0]      e_s2;
reg [1:0]      e_d2;
reg            e_f;
reg            e_w;
reg            e_e;
reg [1:0]      e_type;
reg [3:0]      e_ictl;
reg [2:0]      e_ectl;
reg            e_farjmp;
reg            e_nopmv;
reg            e_is_rloop;
reg            e_have1;
reg            e_have2;
reg            ext4s_early_e;
reg            ext4s_early_wblock;
reg            ext4s_early_post;
reg            ext4s_arch_d1;
reg            row_reads_opr;
reg            nr_wait;
reg            retire_ok_n;
reg            opr_free_now;
reg            poll_busy;
reg            irq_pin_int;
reg            irq_nmi_lvl;
reg            irq_rep_1st;
reg            irq_rep_chn;
reg            row_q1;
reg            row_q2;
reg [1:0]      row_qn;
reg            row_need_q;
reg            row_is_wr;
reg            row_is_wb;
reg            row_is_inta;
reg            row_bus;
reg            ghost_read_stale_alu;
reg [2:0]      acc_seg;
reg            acc_byte;
reg            acc_io;
reg            pr_byte;
reg            op8_eff;
reg [4:0]      nxt_op;
reg            al_width_byte;
reg [15:0]     sig_flags;
reg [15:0]     sig_mask;
reg            sig_commits;
reg [15:0]     acc_off_nog;
reg            acc_split_wr;
reg            row_blocked;
reg            vector_first;
reg            row_slot_wait;
reg            retire_ok_e;
reg            pend_after;
reg            qripe_pop;      // WAVE 15 C2: the shadowed 1BL-lead select
reg            q_ripe_lead_n;  // ...and the level it selects, stage 2 only
reg            row_flush;
reg            bnd_opc;
reg            irq_take;
reg            brk_seen;
reg            brk_take;
reg            bnd_take;
reg            bnd_fire;
reg            q_bnd_pop;
reg            row_pre_wait;
reg            inta_first;
reg [15:0]     s1_val;
reg            s1_byte;
reg            s1_wbyte;
reg [15:0]     s2_val;
reg            s2_wbyte;
reg [15:0]     it_val;
reg [15:0]     it_tmpa;
reg [15:0]     it_flags;
reg [15:0]     it_fmask;
reg            it_writes_tmpa;

always @* begin
    `include "v30u_eu_preload.svh"

    // ***  THE CUT SET  ***  -- STAGE 1's wire cone, captured ONCE, here.
    // These are pure functions of `ce`-committed registers (see the block
    // above), so reading them here is reading them anywhere in this block:
    // nothing between this line and THE CUT can change one.  What it buys is
    // that the NAME the chain body uses is a shadowed reg and not the wire.
    row                    = s1w_row;
    r_aluop                = s1w_r_aluop;
    r_alutmp               = s1w_r_alutmp;
    r_cond                 = s1w_r_cond;
    r_loc                  = s1w_r_loc;
    r_farloc               = s1w_r_farloc;
    e_s1                   = s1w_e_s1;
    e_d1                   = s1w_e_d1;
    e_s2                   = s1w_e_s2;
    e_d2                   = s1w_e_d2;
    e_f                    = s1w_e_f;
    e_w                    = s1w_e_w;
    e_e                    = s1w_e_e;
    e_type                 = s1w_e_type;
    e_ictl                 = s1w_e_ictl;
    e_ectl                 = s1w_e_ectl;
    e_farjmp               = s1w_e_farjmp;
    e_nopmv                = s1w_e_nopmv;
    e_is_rloop             = s1w_e_is_rloop;
    e_have1                = s1w_e_have1;
    e_have2                = s1w_e_have2;
    ext4s_early_e          = s1w_ext4s_early_e;
    ext4s_early_wblock     = s1w_ext4s_early_wblock;
    ext4s_early_post       = s1w_ext4s_early_post;
    ext4s_arch_d1          = s1w_ext4s_arch_d1;
    row_reads_opr          = s1w_row_reads_opr;
    nr_wait                = s1w_nr_wait;
    retire_ok_n            = s1w_retire_ok_n;
    opr_free_now           = s1w_opr_free_now;
    poll_busy              = s1w_poll_busy;
    irq_pin_int            = s1w_irq_pin_int;
    irq_nmi_lvl            = s1w_irq_nmi_lvl;
    irq_rep_1st            = s1w_irq_rep_1st;
    irq_rep_chn            = s1w_irq_rep_chn;
    row_q1                 = s1w_row_q1;
    row_q2                 = s1w_row_q2;
    row_qn                 = s1w_row_qn;
    row_need_q             = s1w_row_need_q;
    row_is_wr              = s1w_row_is_wr;
    row_is_wb              = s1w_row_is_wb;
    row_is_inta            = s1w_row_is_inta;
    row_bus                = s1w_row_bus;
    ghost_read_stale_alu   = s1w_ghost_read_stale_alu;
    acc_seg                = s1w_acc_seg;
    acc_byte               = s1w_acc_byte;
    acc_io                 = s1w_acc_io;
    pr_byte                = s1w_pr_byte;
    op8_eff                = s1w_op8_eff;
    nxt_op                 = s1w_nxt_op;
    al_width_byte          = s1w_al_width_byte;
    sig_flags              = s1w_sig_flags;
    sig_mask               = s1w_sig_mask;
    sig_commits            = s1w_sig_commits;
    acc_off_nog            = s1w_acc_off_nog;
    acc_split_wr           = s1w_acc_split_wr;
    row_blocked            = s1w_row_blocked;
    vector_first           = s1w_vector_first;
    row_slot_wait          = s1w_row_slot_wait;
    retire_ok_e            = s1w_retire_ok_e;
    pend_after             = s1w_pend_after;
    row_flush              = s1w_row_flush;
    bnd_opc                = s1w_bnd_opc;
    irq_take               = s1w_irq_take;
    brk_seen               = s1w_brk_seen;
    brk_take               = s1w_brk_take;
    bnd_take               = s1w_bnd_take;
    bnd_fire               = s1w_bnd_fire;
    q_bnd_pop              = s1w_q_bnd_pop;
    qripe_pop              = s1w_qripe_pop;
    row_pre_wait           = s1w_row_pre_wait;
    inta_first             = s1w_inta_first;
    s1_val                 = s1w_s1_val;
    s1_byte                = s1w_s1_byte;
    s1_wbyte               = s1w_s1_wbyte;
    s2_val                 = s1w_s2_val;
    s2_wbyte               = s1w_s2_wbyte;
    it_val                 = s1w_it_val;
    it_tmpa                = s1w_it_tmpa;
    it_flags               = s1w_it_flags;
    it_fmask               = s1w_it_fmask;
    it_writes_tmpa         = s1w_it_writes_tmpa;

    // ***  STAGE 1 RUNS UNCONDITIONALLY  ***  -- the ce/ce_half PHASE SPLIT.
    // Blocks (a)-(f) used to sit in the `else` arm of `if (ss_we)`.  They do
    // not any more, and the reason is THE SS RESUME: the phase-split shadow
    // must be re-derived from the FULLY RESTORED register file before the
    // first resumed `ce`, and the only edge on which that is possible is the
    // resume-drain edge -- the clock the A2 contract already requires, where
    // `ss_we_q` is still high and every stream word has landed.  Stage 1
    // evaluated THERE is stage 1 of the restored machine.  The `ss_we` arm,
    // which now opens AT THE CUT, re-runs the preload so that stage 1's `_n`
    // writes do not survive into it.
        //====================================================================
        // (a) the BIU's completion pulses, sampled on the clock they ride
        //====================================================================
`ifndef JTV30_SYNTHESIS
        trc_1bl_hit = 1'b0; trc_pe_hit = 1'b0; trc_1bld_hit = 1'b0;
`endif
        // ...and the IE the gate's own pipeline is about to take, frozen HERE
        // because the chain below may write `psw` (see block (g)).
        ie_now = psw_n[FIE];
        brk_now = psw_n[FBRK];
        // A maskable request present when IE rises is remembered while the
        // existing three-clock IE floor matures.  `ie_now` and `int_p[0]` are
        // the two signals sampled on the same preceding clock; the older
        // boundary tap (`int_p[2]`) would retain a pin that had already fallen.
        if (ie_now && !ie_p_n[0] && int_p[0])
            intr_pending_n = 1'b1;
        // §86 -- THE ARM'S TWO EVENTS, BOTH READ OFF REGISTERS ONLY, AND BOTH
        // BEFORE THE CHAIN.  The SAMPLE lands one clock past the boundary's own
        // F pop (`brk_smp`, raised below on the pop's own clock); the TAKE is
        // in the chain, at the four arms that reach `S_IRQ_D`, and it CLEARS
        // the arm.  Ordering them this way round is what makes a take that
        // coincides with a sample resolve as the model resolves it -- the model
        // takes first and samples second, in one statement:
        //     if (brk_take_) { brk_arm_ = false; } else { brk_arm_ = seen; }
        if (brk_smp) brk_arm_n = brk_seen;
        // ...and the F pop that ENDS this boundary, which is exactly the pop
        // the `QS = 1` pins announce (`q_first`).  A PREFIX retires with one of
        // its own, so this single predicate is §85.3's "the retire boundaries
        // AND the prefix hand-over" with no second term.
        //
        // fz2 P2 / `L-A` -- **...AND A BOUNDARY THAT WALKS THROUGH THE EXTERNAL
        // DOOR STILL SAMPLES THE ARM.**  §86's predicate is the SUCCESSOR'S
        // POP, and `at_bnd` implies `!opc_valid` on all three of its arms: a
        // boundary that DISPATCHES an interrupt does not pop a successor, so
        // under the pop-only predicate it never sampled.  That is the second
        // half of `C1`'s defect and it is the same sentence one clause on --
        // `C1` landed *an external recognition does not SPEND the arm*; this is
        // *...and it does not SKIP THE SAMPLE either*.
        //
        // MEASURED, on the banked FLASH #14 A/B captures, chip against fabric
        // core, with the core's own `+brktrace` beside them
        // (`docs/notes/fz2_p2_prereg_2026-08-10.md` §2.1).  Exemplar
        // `fz2c/407024`: an `IRET` pops a PSW that restores `TF` (`BRKR` at
        // clock 3000), the terminating NMI is recognised at that IRET's OWN
        // retire boundary (`BRKT clk=3006`, and the pushed IP is the IP the
        // IRET just popped), and there is NO `BRKS` anywhere between them --
        // six clocks, so the floor is met and `brk_seen` is 1.  The chip pays
        // the trap after exactly one handler prefetch, which is `C1`'s law
        // working; the ucore had nothing to preserve.
        //
        // THE TRAP'S OWN TAKE IS DELIBERATELY NOT A SAMPLING EVENT.  At a trap
        // take `irq_take` is 0, so the five `S_IRQ_D` sites' `brk_arm_n =
        // brk_arm_n && irq_take` clear the arm and nothing re-arms it.  Adding
        // `brk_take` here would re-sample `psw[FBRK]` one clock into the
        // entry, before `I_CITF` has cleared it, and storm.
        //
        // The sample INSTANT is unmoved: still one clock past the boundary,
        // where §85.2a measured it.  No flop, no wire, no save-state address.
        // *Falsifier*: a capture in which the chip recognises an external
        // interrupt at a boundary with `PSW.TF` armed and does NOT then read
        // vector 1 before the handler's first instruction retires.
        //
        // KM (2026-08-11) -- `q_first` -> `q_bnd_pop`.  §86's sentence above is
        // right in KIND and wrong in COUNT, and its second half was never in
        // the RTL at all; the erratum and the silicon it is written on are at
        // the `q_bnd_pop` declaration and in `ucore_provenance.md` §86 ERRATUM.
        brk_smp_n = (q_pop && q_ripe && q_bnd_pop) || (bnd_fire && irq_take);
        unhalt_pend_n = 1'b0;
        if (bnd_fire)
            irq_fast_inta_n = bnd_opc || eu_bnd_post;
        if (eu_post && inta_first) begin
            irq_fast_inta_n = 1'b0;
            irq_halt_entry_n = 1'b0;
        end
        if (vector_first) irq_fast_inta_n = 1'b0;
        rd_age0_n = 1'b0;
        if (eu_rd_done_n) begin
            // (the two completed-read SVAs are in the clocked observer below --
            //  a combinational block fires them once per SETTLE, not once per CE
            //  clock.  They read only flop values, which is what they read here
            //  too: nothing above this point touches either counter.)
            // ...AND THE COUNTERS SATURATE RATHER THAN WRAP.  The assertions
            // above live inside `ifndef SYNTHESIS`, so in the BITSTREAM they do
            // not exist: the only thing standing between an over-deep store and
            // silently-wrong behaviour is what the counter itself does.  Before
            // this, `rd_done_cnt` went 3 -> 0 and DROPPED FOUR COMPLETIONS
            // (`nr_have` reads `rd_done_cnt != 0`, so the EU would then wait
            // forever on reads that had already landed), and `rdq_n` went 2 -> 3
            // and handed `rdq1` out twice.  Saturation is the house rule the BIU
            // already follows for every one of its bounded counters -- `sev`
            // (v30u_biu.sv:1377), `cdage` (:1270), `rq_n` (:957, :1287) -- and
            // it is what a store with a fixed number of slots physically does.
            // Inert on every graded path by sec.27.1's proof; load-bearing in
            // fabric, where the in-silicon fuzz runs with no assertions at all.
            // The record's head belongs to THIS completion (the bus returns
            // words in order); take it, then close the record up.
            rdh_byte = rdp0_byte_n;
            rdp0_byte_n = rdp1_byte_n;
            if (rd_pending_n != 2'd0) rd_pending_n = rd_pending_n - 2'd1;
            // THE 8F GHOST READ'S DISCARD -- ONE PREDICATE.
            //
            // The mod3 POP's stack read reaches the bus but has no result to
            // deliver, and the bus has NO RESULT TAGS: it returns words in
            // order, so every completion in the chain is taken by the OLDEST
            // requester still waiting.  That is the one-place displacement.
            // Its consequence is that exactly ONE completion at the end of the
            // chain has nobody waiting for it -- the UNMATCHED TAIL -- and
            // `rd_pending_n == 0` after the decrement above IS that condition.
            // Drop it; everything before it stores normally and is displaced.
            //
            // No counter and no second token: the discard bit is armed when
            // the ghost row posts (`v30u_eu_row.svh`) and spent here.  This is
            // also what keeps the completed-read store from SATURATING on a
            // ghost with no successor -- `timed_fuzz`'s `BOUND WARNINGS`.
            if (ghost_rd_discard_n && (rd_pending_n == 2'd0)) begin
                ghost_rd_discard_n = 1'b0;
            end else begin
                if (rd_done_cnt_n == 2'd0) rd_age0_n = 1'b1;
                if (rd_done_cnt_n != 2'd3) rd_done_cnt_n = rd_done_cnt_n + 2'd1;
                if (rdq_n_n == 2'd0) begin
                    rdq0_n = eu_rdata_n; rdq0_byte_n = rdh_byte;
                end else begin
                    rdq1_n = eu_rdata_n; rdq1_byte_n = rdh_byte;
                end
                if (rdq_n_n != 2'd2) rdq_n_n = rdq_n_n + 2'd1;
            end
        end
        if (eu_wr_done_n && (wr_out_n != 2'd0)) wr_out_n = wr_out_n - 2'd1;
        if (q_pop && q_ripe && q_first && !first_pop_seen_n) first_pop_seen_n = 1'b1;

        //--------------------------------------------------------------------
        // ...AND THE FLAG REGISTER IS FED BY THE DATA LATCH, NOT BY THE ROW.
        //--------------------------------------------------------------------
        // A row's destination write-enable is a LEVEL for as long as the row
        // STANDS.  For every other destination that is unobservable -- nothing
        // between the row's arrival and its release can read the register --
        // but FLAGS is wired to the outside world twice over (S5 on the status
        // pins, and the IE gate of the recognition pipeline), so on the two
        // rows whose destination is FLAGS and whose source is the read latch
        // the early load is VISIBLE.  `interrupt_model.md`, verbatim:
        //
        //     "POP PSW consumes the popped image at its read's data edge
        //      (the new IE shows in the PS bits during the read's own T4)"
        //
        // MEASURED, `INT.9D idx 1`: the golden's PS nibble is 5 on row 9 --
        // the read's T4, so the register already held the popped image when
        // that clock OPENED, i.e. it was loaded on the T3 -> T4 edge -- while
        // the `OPR -> FLAGS` row itself does not release until row 10.  Two
        // clocks, and they are exactly the two that decide the NEXT boundary:
        // `ie_p[2]` is IE at c-3, the boundary stands on row 13, and IE has to
        // be up by row 10 for it to be seen.  All 89 failing cases were
        // pre-IE=0 pops -- the 111 pre-IE=1 ones never needed it.
        //
        // The rule names NO OPCODE.  `OPR -> FLAGS ... F` is exactly two ROM
        // rows, 007A (POP PSW) and 01EA (RETI) -- which is the same pair E1
        // measured on silicon ("mu01EA's flag commit obeys the SAME race table
        // as POP PSW's mu007A", 108/108 H-IDENTICAL).  One rule, both rows.
        //
        // The row still performs its own `OPR -> FLAGS` when it releases; the
        // value is the same word, so the commit is idempotent.  (The frozen
        // FSM core renders this as `opc == 8'h9D && eu_rd_now` plus a second
        // copy for `iret_pw`; this is that behaviour with the opcode test and
        // the duplication taken out.)
        // SM3 sitting 12 (R7'): the write that used to stand HERE is now
        // `rd_edge_psw_take` / `rd_edge_psw` on the `psw` register's own `D`
        // pin -- see the declaration beside `row_blocked` for the measurement,
        // the two-case exactness argument and the two falsifiers.  Nothing
        // about the RULE changed; `ie_now` above still reads the un-overridden
        // `psw_n`, exactly as it did when the write was here.

        //====================================================================
        // (b) the post-E row's work, owed to THIS clock: it overlaps the
        //     successor's decode (exec_impl.h's cadence note) and the model
        //     runs it BEFORE the successor's step.
        //====================================================================
        if (poste_n) begin
            poste_n = 1'b0;
`ifndef JTV30_SYNTHESIS
            trc_pe_hit = 1'b1; trc_pe_pre = psw_n;
            trc_pe_upc = {upc_opc_n, upc_loc_n};
`endif
            `include "v30u_eu_poste.svh"
            if (tmpa_n != tmpa) ea_residue_n = tmpa_n;
            if (tmpb_n != tmpb) ea_pair_valid_n = 1'b0;
`ifndef JTV30_SYNTHESIS
            trc_pe_post = psw_n;
`endif
        end
        // F22: ...and the successor's latch reset it was standing in front of.
        if (iend_owed_n) begin
            iend_owed_n = 1'b0;
            `include "v30u_eu_iend_late.svh"
        end

`ifndef JTV30_SYNTHESIS
        //-- the eutrace SNAPSHOT (the $display is in the clocked observer)
        trc_st = st_n;
        trc_upc_page = upc_page_n;
        trc_upc_opc = upc_opc_n;
        trc_upc_loc = upc_loc_n;
        trc_wr_out = wr_out_n;
        trc_pc = pc_n;
        trc_ind = ind_n;
        trc_opr = opr_n;
        trc_opr_fresh = opr_fresh_n;
        trc_pend_active = pend_active_n;
        trc_poste = poste_n;
        trc_rdq_n = rdq_n_n;
        trc_rd_done_cnt = rd_done_cnt_n;
        trc_tmpa = tmpa_n;
        trc_tmpb = tmpb_n;
        trc_tmpc = tmpc_n;
`endif
        //====================================================================
        // ***  THE CUT  ***  -- the ce/ce_half PHASE SPLIT.
        //====================================================================
        // Everything ABOVE is STAGE 1, evaluated in the `ce -> ce_half`
        // window.  Everything BELOW is STAGE 2, evaluated in the
        // `ce_half -> ce` window.  The boundary is the ENTRY TO THE CHAIN
        // PASS: stage 2 is the chain, block (g) and the tail, and stage 1 is
        // everything that feeds them.
        //
        // ⚠ 2026-09-09, WAVE 9 -- THE JUSTIFICATION THIS PARAGRAPH USED TO
        // CARRY IS GONE AND IS NOT REPLACED BY A BETTER ONE.  It read: *"the
        // boundary is WAVE 1's named cut -- `Decoder28#1`, the ENTRY TO THE
        // UNROLLED CHAIN LOOP ... it is the one place in this cone where the
        // RTL has a boundary the netlist also has: FOUR UNROLLED COPIES of ONE
        // source line stand in series on the worst path and are 22.3 ns of its
        // 48.2."*  **WAVE 7 DELETED THE UNROLL** (`2ceb8c3ba3`): there are no
        // copies in series any more, the arc fell 43.5 -> 33.0 ns, and the
        // whole `CHAIN` bucket is 9.4 ns.  The cut is at the SAME PLACE, and
        // it is there now because it is the block's one structural seam --
        // NOT because four copies of a decoder stand behind it.  Whether that
        // seam BALANCES is a measurement, not an argument, and it is
        // `docs/notes/phase_split_reland_results_2026-09-09.md` J-9's.
        //
        // THE MEMBERSHIP RULE, and it is mechanical: every `_n` or scratch
        // name STAGE 1 ASSIGNS.  A `_n` stage 1 never touches still reads as
        // its own flop in stage 2 and crosses nothing, so it is not here.
        // `sw/phase_split_width.py` derives the set from the source.
        //
        // THE PACK AND THE UNPACK ARE ONE LIST, WRITTEN TWICE AND CHECKED.
        s1_bus = {
        al_adjtmp_n, al_adjust_n, al_bitarm_n, al_bitn_n, al_eaconst_n,
        al_op_n, al_spent_n, al_tmp_n, brk_arm_n, brk_now, brk_smp_n, bsw,
        count_n, ea_pair_valid_n, ea_residue_n, first_pop_seen_n,
        ghost_rd_discard_n, gpr_n[0], gpr_n[1], gpr_n[2], gpr_n[3], gpr_n[4],
        gpr_n[5], gpr_n[6], gpr_n[7], ie_now, iend_owed_n, ind_n,
        intr_pending_n, irq_fast_inta_n, irq_halt_entry_n, m_idx_n, m_kind_n,
        mode8080_n, modrm_reg_n, opc_base_n, opc_from_modrm_n, opr_byte_n,
        opr_fresh_n, opr_loaded_n, opr_n, pc_n, poll_pipe_n, poste_n, psw_n,
        r_idx_n, r_kind_n, rd_age0_n, rd_done_cnt_n, rd_pending_n, rdh_byte,
        rdp0_byte_n, rdq0_byte_n, rdq0_n, rdq1_byte_n, rdq1_n, rdq_n_n,
        sign_neg_n, sreg_n[0], sreg_n[1], sreg_n[2], sreg_n[3], stat_n,
        tmpa_byte_n, tmpa_n, tmpb_byte_n, tmpb_n, tmpc_byte_n, tmpc_n,
        unhalt_pend_n, v1, v2, wb1, wb2, wb_kind_n, wr_out_n,
        // ...AND THE WIRE CONE (WAVE 4).  Same list, same order, both sides.
        row, r_aluop, r_alutmp, r_cond, r_loc, r_farloc, e_s1, e_d1, e_s2,
        e_d2, e_f, e_w, e_e, e_type, e_ictl, e_ectl, e_farjmp, e_nopmv,
        e_is_rloop, e_have1, e_have2, ext4s_early_e, ext4s_early_wblock,
        ext4s_early_post, ext4s_arch_d1, row_reads_opr, nr_wait,
        retire_ok_n, opr_free_now, poll_busy, irq_pin_int, irq_nmi_lvl,
        irq_rep_1st, irq_rep_chn, row_q1, row_q2, row_qn, row_need_q,
        row_is_wr, row_is_wb, row_is_inta, row_bus, ghost_read_stale_alu,
        acc_seg, acc_byte, acc_io, pr_byte, op8_eff, nxt_op, al_width_byte,
        sig_flags, sig_mask, sig_commits, acc_off_nog, acc_split_wr,
        row_blocked, vector_first, row_slot_wait, retire_ok_e, pend_after,
        row_flush, bnd_opc, irq_take, brk_seen, brk_take, bnd_take,
        bnd_fire, q_bnd_pop, row_pre_wait, inta_first, s1_val, s1_byte,
        s1_wbyte, s2_val, s2_wbyte, it_val, it_tmpa, it_flags, it_fmask,
        it_writes_tmpa, qripe_pop
        };

        if (ss_we) begin
            // ...and STAGE 1 IS UNDONE HERE.  An `ss_we` clock commits `_n`
            // for EVERY register, so a `_n` the stream has not addressed yet
            // must read as its own flop.  Re-running the block's own head is
            // exactly that, and it makes this arm byte-identical to the
            // pre-split one.  (`s1_bus` above is already packed, from stage 1
            // evaluated on the register file as it stands -- which on the
            // resume-drain edge is the FULLY RESTORED one.)
            `include "v30u_eu_preload.svh"
            `include "v30u_eu_ss_write.svh"
            // WAVE 15 C2: `q_ripe_lead_n` is a stage-2 value and this arm never
            // reads it, but an `always @*` reg must be written on every path or
            // it infers a LATCH -- and G6 gates on 0 latches.
            q_ripe_lead_n = q_ripe_lead_n0;
        end else begin
        //====================================================================
        // STAGE 2 -- evaluated `ce_half -> ce`, committed on `ce`
        //====================================================================
        // The unpack.  CHARACTER-IDENTICAL to the pack above; that identity is
        // the whole of the correctness argument and `sw/phase_split_lint.py`
        // is its falsifier.
        {
        al_adjtmp_n, al_adjust_n, al_bitarm_n, al_bitn_n, al_eaconst_n,
        al_op_n, al_spent_n, al_tmp_n, brk_arm_n, brk_now, brk_smp_n, bsw,
        count_n, ea_pair_valid_n, ea_residue_n, first_pop_seen_n,
        ghost_rd_discard_n, gpr_n[0], gpr_n[1], gpr_n[2], gpr_n[3], gpr_n[4],
        gpr_n[5], gpr_n[6], gpr_n[7], ie_now, iend_owed_n, ind_n,
        intr_pending_n, irq_fast_inta_n, irq_halt_entry_n, m_idx_n, m_kind_n,
        mode8080_n, modrm_reg_n, opc_base_n, opc_from_modrm_n, opr_byte_n,
        opr_fresh_n, opr_loaded_n, opr_n, pc_n, poll_pipe_n, poste_n, psw_n,
        r_idx_n, r_kind_n, rd_age0_n, rd_done_cnt_n, rd_pending_n, rdh_byte,
        rdp0_byte_n, rdq0_byte_n, rdq0_n, rdq1_byte_n, rdq1_n, rdq_n_n,
        sign_neg_n, sreg_n[0], sreg_n[1], sreg_n[2], sreg_n[3], stat_n,
        tmpa_byte_n, tmpa_n, tmpb_byte_n, tmpb_n, tmpc_byte_n, tmpc_n,
        unhalt_pend_n, v1, v2, wb1, wb2, wb_kind_n, wr_out_n,
        // ...AND THE WIRE CONE (WAVE 4).  Same list, same order, both sides.
        row, r_aluop, r_alutmp, r_cond, r_loc, r_farloc, e_s1, e_d1, e_s2,
        e_d2, e_f, e_w, e_e, e_type, e_ictl, e_ectl, e_farjmp, e_nopmv,
        e_is_rloop, e_have1, e_have2, ext4s_early_e, ext4s_early_wblock,
        ext4s_early_post, ext4s_arch_d1, row_reads_opr, nr_wait,
        retire_ok_n, opr_free_now, poll_busy, irq_pin_int, irq_nmi_lvl,
        irq_rep_1st, irq_rep_chn, row_q1, row_q2, row_qn, row_need_q,
        row_is_wr, row_is_wb, row_is_inta, row_bus, ghost_read_stale_alu,
        acc_seg, acc_byte, acc_io, pr_byte, op8_eff, nxt_op, al_width_byte,
        sig_flags, sig_mask, sig_commits, acc_off_nog, acc_split_wr,
        row_blocked, vector_first, row_slot_wait, retire_ok_e, pend_after,
        row_flush, bnd_opc, irq_take, brk_seen, brk_take, bnd_take,
        bnd_fire, q_bnd_pop, row_pre_wait, inta_first, s1_val, s1_byte,
        s1_wbyte, s2_val, s2_wbyte, it_val, it_tmpa, it_flags, it_fmask,
        it_writes_tmpa, qripe_pop
        } = s1q;

        // WAVE 15 C2 -- THE SELECTION, OFF THE SHADOW.  Both inputs are BIU
        // register cones and `qripe_pop` is a flop, so nothing in this
        // expression launches in stage 1.
        q_ripe_lead_n = qripe_pop ? q_ripe_lead_n1 : q_ripe_lead_n0;

        stop = 1'b0;
`ifndef JTV30_SYNTHESIS
        chain_used = 4'd0;
        chain_first = st_n;
`ifdef CHAIN_PROBE
        cp_used = 0;                     // WAVE 6: this edge's tuple, cleared
`endif
`endif
        //==================================================================
        // THE ZERO-COST CHAIN, FLAT.  (WAVE 7,
        // docs/notes/chainflat_landing_prereg_2026-09-09.md; the measurement
        // that authorised it is docs/notes/chainflat_results_2026-09-09.md.)
        //
        // THIS USED TO BE `for (chain = 0; chain < CHAIN_MAX; ...)`, i.e.
        // SEVEN FULL COPIES of the 33-arm step case.  It is now position 0's
        // case ONCE, then the NINE chainable arms ONCE EACH.  Nothing about
        // the function changed -- 169,000/169,000 and four byte-identical
        // LFSR signatures across the substitution -- and the combinational
        // ALUTs of this entity fell by about a third with NOT ONE FLOP added.
        //
        // WHY IT IS EXACT, IN ONE SENTENCE: the fall-through graph over the
        // nine `st_zero_ok` states is a **DAG**, so one edge's walk visits
        // each state AT MOST ONCE and is therefore a SUBSEQUENCE of any
        // topological order of them.  Emitting each arm once in such an order
        // executes exactly the states the loop would have, in the same order,
        // with the same values.
        //
        // ⚠ THAT IS AN ARGUMENT, SO IT IS ALSO ASSERTED.  The single way the
        // substitution can be wrong is a fall-through edge that runs BACKWARD
        // through the order below -- a step would be silently dropped.  It
        // cannot hide: the walk would leave this pass with `stop` still low,
        // which is `chain_open`, which `$fatal`s in the observer.  The order
        // is re-derivable from the source at any time by
        // `sw/chainflat_graph.py`, which refuses on a cycle.
        //
        // ⚠ AND THE UNROLL WAS AN ARTIFACT, NOT A DESCRIPTION OF THE DIE.
        // The nine states are exactly the SPEC's statement positions with no
        // `biu.charge()` between them and their predecessor -- program-counter
        // positions of a straight-line C++ function, which a state machine has
        // to re-serialise and the die does not: it settles the whole clock's
        // decode in one combinational cone.  The CLOCK BOUNDARIES are physical
        // (every one is a measured `charge(n)`); the MULTIPLICITY was not.
        //==================================================================

        //-- POSITION 0: any of the 33 arms ---------------------------------
        chain = 4'd0;
        `include "v30u_eu_chain_pos.svh"
        `include "v30u_eu_step.svh"

        //-- POSITIONS >= 1: the nine chainable arms, ONCE EACH, in the
        //   topological order sw/chainflat_graph.py derives -----------------
        //
        //     S_TAIL_POP  S_TAIL  S_INSTR_END  S_TAKE_OPC  S_EA_CALC
        //     S_DECODE    S_DECODE2  S_BIND  S_ENTER
        //
        // `chain` is 1 from here on and that is the whole of what the 24
        // guarded arms ever asked it: v30u_eu_step.svh's `if (chain == 4'd0)`
        // means "position 0 only".  It is left true-valued rather than deleted
        // because it is the machine-readable record of WHICH arms are
        // position-0-only -- the complement of `st_zero_ok`, and what
        // sw/chainflat_graph.py's PC-A1 cross-derives that function from.
        chain = 4'd1;

        // THE FAIL-SAFE, applied once at the entry to positions >= 1 instead
        // of once per loop iteration.  If a state that is NOT one of the nine
        // ever stood here, no block below would match it, and the edge would
        // end with `stop` low and `$fatal` in simulation.  In FABRIC there is
        // no assertion, so this spends the clock instead -- the state is
        // unchanged, and the next clock re-enters it at position 0 where its
        // arm is unguarded.  **Costing a clock is survivable; the pass has no
        // loop left to hang in.**
        if (!stop && !st_zero_ok(st_n)) stop = 1'b1;

        if (!stop && (st_n == S_TAIL_POP)) begin
            `include "v30u_eu_chain_pos.svh"
            `include "v30u_eu_arm_tail_pop.svh"
        end
        if (!stop && (st_n == S_TAIL)) begin
            `include "v30u_eu_chain_pos.svh"
            `include "v30u_eu_arm_tail.svh"
        end
        if (!stop && (st_n == S_INSTR_END)) begin
            `include "v30u_eu_chain_pos.svh"
            `include "v30u_eu_arm_instr_end.svh"
        end
        if (!stop && (st_n == S_TAKE_OPC)) begin
            `include "v30u_eu_chain_pos.svh"
            `include "v30u_eu_arm_take_opc.svh"
        end
        if (!stop && (st_n == S_EA_CALC)) begin
            `include "v30u_eu_chain_pos.svh"
            `include "v30u_eu_arm_ea_calc.svh"
        end
        if (!stop && (st_n == S_DECODE)) begin
            `include "v30u_eu_chain_pos.svh"
            `include "v30u_eu_arm_decode.svh"
        end
        if (!stop && (st_n == S_DECODE2)) begin
            `include "v30u_eu_chain_pos.svh"
            `include "v30u_eu_arm_decode2.svh"
        end
        if (!stop && (st_n == S_BIND)) begin
            `include "v30u_eu_chain_pos.svh"
            `include "v30u_eu_arm_bind.svh"
        end
        if (!stop && (st_n == S_ENTER)) begin
            `include "v30u_eu_chain_pos.svh"
            `include "v30u_eu_arm_enter.svh"
        end

`ifndef JTV30_SYNTHESIS
        // The pass is over.  Anything still running has left the declared
        // graph; the observer turns that into the CHAIN OVERFLOW $fatal.
        chain_open = !stop;
`endif
        // (CHAIN OVERFLOW and the depth tracker are in the clocked observer:
        //  `stop` / `chain_used` / `chain_first` / `chain_open` are comb
        //  outputs of this block, and the check must run ONCE per CE clock on
        //  the SETTLED values.)

        //====================================================================
        // (g) THE PIN PIPELINES, ADVANCED AT THE *END* OF THE EDGE
        //====================================================================
        // Not a style choice.  These registers are read from BOTH sides of the
        // module -- by the combinational act decode (`bnd_fire` gates `q_pop`)
        // and by the clocked step -- and the two MUST see the same clock, or
        // the demand and the take drift (F11, again).  Shifting them in block
        // (a) put the clock-c+1 view in front of the step while the act decode
        // still had clock c: MEASURED, `HLT.NMI` woke one clock early on every
        // case (entry at A+6 where the golden has A+7), because the step read
        // `nmi_latch` the moment block (a) set it.
        //
        // Advanced here, the registers carry the clock-c view for the WHOLE
        // edge and nothing depends on read order.  (The trap that made this
        // necessary: a wire that is a PURE ALIAS of a register -- `wire w = r;`
        // -- is substituted by the simulator, so it is NOT the pre-edge view
        // the rest of this module gets from a wire with real logic in it.
        // F11b's trap, third form.)
        int_p_n = {int_p_n[2:0], pin_int};
        nmi_p_n = {nmi_p_n[3:0], pin_nmi};
        // ...AND THE POLL PIN'S PIPELINE, WHICH MOVED HERE FROM BLOCK (a) AT
        // THE PHASE SPLIT AND BELONGED HERE ALL ALONG.  It is the third of the
        // three pin pipelines and it was the only one advanced at the START of
        // the edge instead of the END.  Nothing between the two positions
        // reads `poll_pipe_n` -- the module's other readers read the FLOP
        // `poll_pipe` -- so the move is a no-op by inspection, and it is a
        // REQUIREMENT of the split by construction: `pin_poll_n` is a live
        // asynchronous input and stage 1 may not contain one (P-11), which the
        // phase-stability `$fatal` beside the shadow would otherwise report on
        // the first clock the pin moved mid-cycle.
        poll_pipe_n = {poll_pipe_n[1:0], pin_poll_n};
        ie_p_n  = {ie_p_n[2:0], ie_now};
        // §86 -- `psw[FBRK]` on the SAME pipeline, frozen at the same instant
        // and shifted in the same place, because it answers the same kind of
        // question: a flag written into the PSW reaches a recognition decision
        // through flops, and the arm may not act on one that rose too recently.
        brk_p_n = BRK_FLOOR'({brk_p_n, brk_now});
        // ...AND THE SAMPLE INSTANT IS ONE CLOCK PAST THE OPCODE POP.  Not a
        // choice: §85.2a MEASURED it in the model, engine-vs-chip with no trap
        // in the loop, by pairing every `brk_retire` clock with the chip's own
        // `QS = 1` pops on TF-CLEAR captures -- `90 9D 8B 8E B8 E7 CF` at
        // pop + 1, 459 of 459, and `F8` at pop + 0 until that path was
        // corrected, 70 of 70 at both wait levels, 0 violators over 2,900
        // boundaries afterwards.  `brk_smp` is that clock and nothing else.
        //
        // AND THIS IS WHY THERE IS NO PREFIX SPECIAL CASE.  §85.3 asks for the
        // retire boundaries AND the prefix hand-over; `q_bnd_pop` is ONE
        // predicate that is both, because a prefix retires as its own 2-clock
        // instruction with its own F pop (`prefix_retire()` -> `pop_is_first`).
        // "A PREFIX BYTE ENDS AN INSTRUCTION BOUNDARY" is already what the pop
        // stream says.
        //
        // ⚠ ERRATUM (KM, 2026-08-11) -- THIS PARAGRAPH USED TO END *"and the
        // `0F` escape's first byte does too"*.  THAT WAS NEVER IMPLEMENTED
        // (`S_EXT_CHG1` sets nothing) AND, AS WRITTEN, NAMES THE WRONG BYTE:
        // silicon counts the escape's SECOND byte -- the opcode -- which the
        // pins announce SUBSEQUENT on both engines.  The predicate is therefore
        // NOT `q_first`, and the term that makes it right is at `q_bnd_pop`.
        // §86's own count is wrong in the other direction too: a prefix STACK
        // is ONE extra unit whatever its depth, so "the sampling boundaries are
        // simply the opcode pops the `QS = 1` pins announce" is refuted in BOTH
        // directions, engine-free (cell §6, `pfx4` = five pins / two units).
        // Contrast
        // `bnd_armed`, which the INT recognition needs precisely to EXCLUDE the
        // prefix hand-over ("the measured *no sample between 26 and 8B*"):
        // sample and take are different events at the same boundary, and the
        // two lines that say so live in block (a) above, BEFORE the chain, so
        // that a boundary's own TAKE (which clears the arm inside the chain)
        // can never be overwritten by a sample landing on the same clock.

        // the NMI LATCH is an EDGE, set three clocks after it: `nmi_p[3]` is
        // the pin at c-3 and `nmi_p[4]` the pin at c-4, so the latch reads true
        // from c+1 = edge+4 -- "latest catching edge = B-4".
        if (nmi_p_n[3] && !nmi_p_n[4]) nmi_latch_n = 1'b1;
    end
end


//==========================================================================
// THE PHASE SPLIT -- `ce_half` CAPTURES STAGE 1
//   WAVE 2 2026-09-08 (reverted) -> WAVE 4's CUT SET 2026-09-08 (reverted)
//   -> WAVE 9 2026-09-09, RE-DERIVED ON THE FLATTENED TREE.
//==========================================================================
// WAVE 1 (`docs/notes/phase_split_anatomy_2026-09-08.md`) measured that 96 %
// of the binding `ce -> ce` cone is PHASE-STABLE -- pin-dependence enters only
// in the last 1.5-5 ns of a 48-51 ns arc -- and named the cut: `Decoder28#1`,
// the ENTRY to the unrolled chain loop.  This is that cut, at the same place.
// ⚠ THE UNROLL IS GONE (WAVE 7, `2ceb8c3ba3`) AND THE ARC IS 33.0 ns, NOT
// 48-51: what survives of WAVE 1 here is the PHASE-STABILITY measurement,
// which is about pins and not about copies, and the seam's LOCATION.  The
// BALANCE is re-measured, not inherited.
//
// THE THEOREM.  A node in the `ce -> ce` cone outside every input pin's
// combinational fanout depends only on registers that commit on `ce`.  Its
// value is therefore CONSTANT ACROSS THE WHOLE CPU CYCLE -- identical at
// `ce_half(n)` and at `ce(n+1)`.  Capturing it on `ce_half` and consuming it
// on `ce` is bit-exact BY CONSTRUCTION and moves no pin on any clock.  One
// 2-period arc becomes two 1-period arcs, and `hdl/nec_test.sdc`'s CE
// multicycle -- 2,100 registers of exception every downstream integrator has
// to re-derive and copy -- is DELETED.
//
// THE PREMISE IS ASSERTED, NOT ARGUED.  `ifndef SYNTHESIS` below,
// `s1q !== s1_bus` at every `ce` is a `$fatal`.  Every golden case, every
// `ulockstep` scenario and all 4 x 400,000 `chain_lfsr` clocks run under it,
// so "the pin identity held" is a MEASUREMENT and not an inference.  It is
// what caught the one place the premise did NOT hold: `poll_pipe_n` used to
// shift `pin_poll_n` in block (a), i.e. in stage 1, where a pin cannot go; it
// now shifts in block (g) beside `int_p_n` and `nmi_p_n`, which is where the
// other two pin pipelines have always been advanced and is the same clock.
//
// THE COMMIT CONDITION IS `(ss_we || srst || ce_half)` -- the register bank's
// own condition with `ce_half` in place of `ce`, and for the bank's own three
// reasons:
//   * `ce_half` is the capture edge, which is the whole point;
//   * `srst` is in it so the shadow tracks stage 1 THROUGHOUT RESET.  That is
//     what answers "the first `CE` of a run may not have had a `CE_HALF`
//     before it" (`v30_core.sv`'s `ce_half_since_ce` starts asserted, exactly
//     so that first CE is legal): RESET is asserted at the head of every run,
//     so the shadow is current at that CE whether or not a CE_HALF preceded
//     it.  No `_r` mirror is needed and none is written -- stage 1 evaluated
//     on the reset state IS the value wanted, where a mirror would be a second
//     source of truth for it;
//   * `ss_we` is in it so the RESUME-DRAIN edge re-derives it.  The A2 resume
//     contract already requires a clock on which `ss_we_q` is high and every
//     stream word has landed; stage 1 evaluated there is stage 1 of the
//     restored machine, which is exactly what the first resumed `ce` needs.
//     This is why stage 1 runs unconditionally and the `ss_we` arm re-runs the
//     preload instead.
//
// IT IS DERIVED STATE AND IT IS NOT SAVE-STATE MAPPED.  `s1q` is a pure
// function of registers that ARE SSA-mapped, recomputed from the same
// expression, and the place that is CHECKABLE BY EYE is the one above: the
// pack `s1_bus = { ... }` and the unpack `{ ... } = s1q` at THE CUT carry
// character-identical concatenations, and `sw/phase_split_lint.py` fails if
// they ever differ or if their summed declared widths stop equalling S1W.
// `sw/ss_flop_whitelist_ucore.txt`, DERIVED class.
localparam int S1W = 779;   // WAVE 15 C2: 778 + `qripe_pop`, THE ONE FLOP
                           // THIS ARM ADDS AND THE ONLY ONE.  `s1q` is
                           // DERIVED state and is deliberately NOT
                           // save-state mapped, so `SS_COUNT` does not
                           // move -- see THE PHASE SPLIT below.
                            // 495 loop-carried + 283 wire cone.  RE-DERIVED
                           // on the flattened tree at WAVE 9 and IDENTICAL to
                           // WAVE 4's 778 -- the wire cone is WAVE 4's 80 names
                           // NAME FOR NAME.  STOP threshold was 900.
reg [S1W-1:0] s1_bus;      // STAGE 1's output, packed AT THE CUT
reg [S1W-1:0] s1q = '0;    // ...and the shadow that carries it to `ce`

always @(posedge clk) begin
    if (ss_we || srst || ce_half) s1q <= s1_bus;
end

`ifndef JTV30_SYNTHESIS
// THE FALSIFIER FOR THE THEOREM, ON EVERY CLOCK OF EVERY GATE LEG.  At a `ce`
// the live stage 1 and the shadow must agree: that IS the phase-stability
// premise, and if any pin or mid-cycle signal ever reaches stage 1 this fires
// on the clock it does.  Excluded: `srst` and `ss_we`, where the register bank
// is not taking stage 1's answer either.
always @(posedge clk) begin
    if (ce && !srst && !ss_we && (s1q !== s1_bus))
        $fatal(1, "v30u_eu: PHASE-SPLIT PREMISE VIOLATED at %0t -- stage 1 is not constant across the CPU cycle.  The shadow captured at ce_half differs from stage 1 evaluated at this ce: s1q=%h s1_bus=%h.  Something in stage 1 depends on a pin or on a mid-cycle signal; move that term into stage 2 (block (g)), as `poll_pipe_n` was.  docs/notes/phase_split_landing_prereg_2026-09-08.md P-10.",
               $time, s1q, s1_bus);
end
`endif


// L1 -- THE DECODE'S ADDRESS, AND IT IS THE COMMIT'S OWN SELECTION.
//
// Character for character the `upc_page`/`upc_opc`/`upc_loc` lines in THE
// COMMIT below, so `dec_q` cannot disagree with `upc_*` on any clock without
// those three lines disagreeing with themselves.  It is placed HERE, next to
// the block it mirrors, rather than beside `u_ucrom` where it is consumed,
// because the mirroring is the whole of the correctness argument.
//
// FALSIFIER, one grep: this expression and the three `upc_*` commit lines must
// select on the SAME condition (`srst && !ss_we`) and from the SAME pair of
// sources (`upc_*_r`, `upc_*_n`).  If a future edit gives `upc_opc` a third arm
// -- as `psw` has for the read's data edge -- this line must gain it too.
assign dec_addr_next = (srst && !ss_we)
        ? {upc_page_r, upc_opc_r, upc_loc_r[3:2]}
        : {upc_page_n, upc_opc_n, upc_loc_n[3:2]};

//--------------------------------------------------------------------------
// THE COMMIT -- the ONLY place an EU state register is written, and the only
// place `ce` appears.  This is the clock-enable port.
//
// ⚠ 2026-09-08, THE PHASE SPLIT: `ce_half` now gates ONE register of its own,
// `s1q` (see THE PHASE SPLIT above).  That does NOT weaken this sentence --
// `s1q` is DERIVED state, not EU state: it is not save-state mapped, it is on
// `sw/ss_flop_whitelist_ucore.txt`'s DERIVED class, and every architectural
// register is still written HERE and only here, on `ce`.  What DID change is
// that this block's `_n` now come from a cone that starts at `s1q` rather than
// at the flops directly.
//--------------------------------------------------------------------------
always @(posedge clk) begin
    //-- ss_we > srst > ce, exactly the priority the one clocked block had
    if (ss_we || srst || ce) begin
        for (ci = 0; ci < 8; ci = ci + 1)
            gpr[ci] <= (srst && !ss_we) ? gpr_r[ci] : gpr_n[ci];
        for (ci = 0; ci < 4; ci = ci + 1)
            sreg[ci] <= (srst && !ss_we) ? sreg_r[ci] : sreg_n[ci];
        pc <= (srst && !ss_we) ? pc_r : pc_n;
        // SM3 sitting 12 (R7'): the read's data edge is applied HERE, on the
        // `D` pin, instead of at the head of the chain.  Priority is unchanged
        // -- `ss_we` > `srst` > the data edge > the chain -- because the old
        // write sat inside the `else` of `if (ss_we)` and `srst` took `psw_r`
        // regardless of it.
        psw <= (srst && !ss_we)             ? psw_r
             : (rd_edge_psw_take && !ss_we) ? rd_edge_psw
             :                                psw_n;
        tmpa <= (srst && !ss_we) ? tmpa_r : tmpa_n;
        tmpa_byte <= (srst && !ss_we) ? tmpa_byte_r : tmpa_byte_n;
        tmpb_byte <= (srst && !ss_we) ? tmpb_byte_r : tmpb_byte_n;
        tmpc_byte <= (srst && !ss_we) ? tmpc_byte_r : tmpc_byte_n;
        opr_byte  <= (srst && !ss_we) ? opr_byte_r  : opr_byte_n;
        tmpb <= (srst && !ss_we) ? tmpb_r : tmpb_n;
        tmpc <= (srst && !ss_we) ? tmpc_r : tmpc_n;
        ea_residue <= (srst && !ss_we) ? ea_residue_r : ea_residue_n;
        ea_pair_rhs <= (srst && !ss_we) ? ea_pair_rhs_r : ea_pair_rhs_n;
        ea_pair_valid <= (srst && !ss_we) ? ea_pair_valid_r : ea_pair_valid_n;
        opr <= (srst && !ss_we) ? opr_r : opr_n;
        ind <= (srst && !ss_we) ? ind_r : ind_n;
        count <= (srst && !ss_we) ? count_r : count_n;
        pfxcnt <= (srst && !ss_we) ? pfxcnt_r : pfxcnt_n;
        stat <= (srst && !ss_we) ? stat_r : stat_n;
        sign_neg <= (srst && !ss_we) ? sign_neg_r : sign_neg_n;
        bit_n <= (srst && !ss_we) ? bit_n_r : bit_n_n;
        al_op <= (srst && !ss_we) ? al_op_r : al_op_n;
        al_tmp <= (srst && !ss_we) ? al_tmp_r : al_tmp_n;
        al_eaconst <= (srst && !ss_we) ? al_eaconst_r : al_eaconst_n;
        al_eaval <= (srst && !ss_we) ? al_eaval_r : al_eaval_n;
        al_adjust <= (srst && !ss_we) ? al_adjust_r : al_adjust_n;
        al_adjtmp <= (srst && !ss_we) ? al_adjtmp_r : al_adjtmp_n;
        al_bitarm <= (srst && !ss_we) ? al_bitarm_r : al_bitarm_n;
        al_bitn <= (srst && !ss_we) ? al_bitn_r : al_bitn_n;
        al_spent <= (srst && !ss_we) ? al_spent_r : al_spent_n;
        upc_page <= (srst && !ss_we) ? upc_page_r : upc_page_n;
        upc_opc <= (srst && !ss_we) ? upc_opc_r : upc_opc_n;
        upc_loc <= (srst && !ss_we) ? upc_loc_r : upc_loc_n;
        // L1: ...and the DECODE of the micro-address those three lines are
        // committing, taken on this same edge from the same three expressions.
        // It is not state -- it is `ucdecode` of the state, one clock early --
        // so it is DERIVED and whitelisted rather than SSA-mapped, which would
        // give one fact two sources of truth.  See the header at u_ucrom.
        dec_q <= {dec_valid_next, dec_bank_next};
        seg_override <= (srst && !ss_we) ? seg_override_r : seg_override_n;
        seg_ovr <= (srst && !ss_we) ? seg_ovr_r : seg_ovr_n;
        rep_kind <= (srst && !ss_we) ? rep_kind_r : rep_kind_n;
        lock_pfx <= (srst && !ss_we) ? lock_pfx_r : lock_pfx_n;
        opc_reg <= (srst && !ss_we) ? opc_reg_r : opc_reg_n;
        op8 <= (srst && !ss_we) ? op8_r : op8_n;
        imm8 <= (srst && !ss_we) ? imm8_r : imm8_n;
        opc_base <= (srst && !ss_we) ? opc_base_r : opc_base_n;
        opc_from_modrm <= (srst && !ss_we) ? opc_from_modrm_r : opc_from_modrm_n;
        modrm_reg <= (srst && !ss_we) ? modrm_reg_r : modrm_reg_n;
        xop <= (srst && !ss_we) ? xop_r : xop_n;
        rep_test <= (srst && !ss_we) ? rep_test_r : rep_test_n;
        rep_pol <= (srst && !ss_we) ? rep_pol_r : rep_pol_n;
        bus_word <= (srst && !ss_we) ? bus_word_r : bus_word_n;
        opc8080 <= (srst && !ss_we) ? opc8080_r : opc8080_n;
        mode8080 <= (srst && !ss_we) ? mode8080_r : mode8080_n;
        intr_pending <= (srst && !ss_we) ? intr_pending_r : intr_pending_n;
        eu_halted <= (srst && !ss_we) ? eu_halted_r : eu_halted_n;
        int_p <= (srst && !ss_we) ? int_p_r : int_p_n;
        nmi_p <= (srst && !ss_we) ? nmi_p_r : nmi_p_n;
        nmi_latch <= (srst && !ss_we) ? nmi_latch_r : nmi_latch_n;
        ie_p <= (srst && !ss_we) ? ie_p_r : ie_p_n;
        rep_chain <= (srst && !ss_we) ? rep_chain_r : rep_chain_n;
        irq_shadow <= (srst && !ss_we) ? irq_shadow_r : irq_shadow_n;
        bnd_armed <= (srst && !ss_we) ? bnd_armed_r : bnd_armed_n;
        irq_sel_nmi <= (srst && !ss_we) ? irq_sel_nmi_r : irq_sel_nmi_n;
        irq_sel_brk <= (srst && !ss_we) ? irq_sel_brk_r : irq_sel_brk_n;
        brk_p <= (srst && !ss_we) ? brk_p_r : brk_p_n;
        brk_arm <= (srst && !ss_we) ? brk_arm_r : brk_arm_n;
        brk_smp <= (srst && !ss_we) ? brk_smp_r : brk_smp_n;
        unhalt_pend <= (srst && !ss_we) ? unhalt_pend_r : unhalt_pend_n;
        irq_fast_inta <= (srst && !ss_we) ? irq_fast_inta_r
                                          : irq_fast_inta_n;
        irq_halt_entry <= (srst && !ss_we) ? irq_halt_entry_r
                                           : irq_halt_entry_n;
        m_kind <= (srst && !ss_we) ? m_kind_r : m_kind_n;
        r_kind <= (srst && !ss_we) ? r_kind_r : r_kind_n;
        wb_kind <= (srst && !ss_we) ? wb_kind_r : wb_kind_n;
        m_idx <= (srst && !ss_we) ? m_idx_r : m_idx_n;
        r_idx <= (srst && !ss_we) ? r_idx_r : r_idx_n;
        wb_idx <= (srst && !ss_we) ? wb_idx_r : wb_idx_n;
        m_ea <= (srst && !ss_we) ? m_ea_r : m_ea_n;
        r_ea <= (srst && !ss_we) ? r_ea_r : r_ea_n;
        wb_ea <= (srst && !ss_we) ? wb_ea_r : wb_ea_n;
        m_seg <= (srst && !ss_we) ? m_seg_r : m_seg_n;
        r_seg <= (srst && !ss_we) ? r_seg_r : r_seg_n;
        wb_seg <= (srst && !ss_we) ? wb_seg_r : wb_seg_n;
        m_byte <= (srst && !ss_we) ? m_byte_r : m_byte_n;
        r_byte <= (srst && !ss_we) ? r_byte_r : r_byte_n;
        wb_byte <= (srst && !ss_we) ? wb_byte_r : wb_byte_n;
        pend_active <= (srst && !ss_we) ? pend_active_r : pend_active_n;
        pend_off <= (srst && !ss_we) ? pend_off_r : pend_off_n;
        pend_seg <= (srst && !ss_we) ? pend_seg_r : pend_seg_n;
        pend_byte <= (srst && !ss_we) ? pend_byte_r : pend_byte_n;
        pend_io <= (srst && !ss_we) ? pend_io_r : pend_io_n;
        opr_fresh <= (srst && !ss_we) ? opr_fresh_r : opr_fresh_n;
        opr_loaded <= (srst && !ss_we) ? opr_loaded_r : opr_loaded_n;
        rdp0_byte <= (srst && !ss_we) ? rdp0_byte_r : rdp0_byte_n;
        rdp1_byte <= (srst && !ss_we) ? rdp1_byte_r : rdp1_byte_n;
        rdq0_byte <= (srst && !ss_we) ? rdq0_byte_r : rdq0_byte_n;
        rdq1_byte <= (srst && !ss_we) ? rdq1_byte_r : rdq1_byte_n;
        rdq0 <= (srst && !ss_we) ? rdq0_r : rdq0_n;
        rdq1 <= (srst && !ss_we) ? rdq1_r : rdq1_n;
        rdq_n <= (srst && !ss_we) ? rdq_n_r : rdq_n_n;
        rd_pending <= (srst && !ss_we) ? rd_pending_r : rd_pending_n;
        ghost_rd_discard <= (srst && !ss_we) ? ghost_rd_discard_r
                                             : ghost_rd_discard_n;
        rd_done_cnt <= (srst && !ss_we) ? rd_done_cnt_r : rd_done_cnt_n;
        rd_age0 <= (srst && !ss_we) ? rd_age0_r : rd_age0_n;
        iend_owed <= (srst && !ss_we) ? iend_owed_r : iend_owed_n;
        rst_ctr <= (srst && !ss_we) ? rst_ctr_r : rst_ctr_n;
        tsel <= (srst && !ss_we) ? tsel_r : tsel_n;
        pe_opc_reg <= (srst && !ss_we) ? pe_opc_reg_r : pe_opc_reg_n;
        pe_opc8080 <= (srst && !ss_we) ? pe_opc8080_r : pe_opc8080_n;
        pe_op8 <= (srst && !ss_we) ? pe_op8_r : pe_op8_n;
        pe_pfxcnt <= (srst && !ss_we) ? pe_pfxcnt_r : pe_pfxcnt_n;
        wr_out <= (srst && !ss_we) ? wr_out_r : wr_out_n;
        opc_valid <= (srst && !ss_we) ? opc_valid_r : opc_valid_n;
        opc_byte <= (srst && !ss_we) ? opc_byte_r : opc_byte_n;
        pop_is_first <= (srst && !ss_we) ? pop_is_first_r : pop_is_first_n;
        ld_b <= (srst && !ss_we) ? ld_b_r : ld_b_n;
        ld_pla <= (srst && !ss_we) ? ld_pla_r : ld_pla_n;
        ld_ext <= (srst && !ss_we) ? ld_ext_r : ld_ext_n;
        ld_page <= (srst && !ss_we) ? ld_page_r : ld_page_n;
        ld_hasrm <= (srst && !ss_we) ? ld_hasrm_r : ld_hasrm_n;
        ld_rm <= (srst && !ss_we) ? ld_rm_r : ld_rm_n;
        ld_disp <= (srst && !ss_we) ? ld_disp_r : ld_disp_n;
        ld_dlo <= (srst && !ss_we) ? ld_dlo_r : ld_dlo_n;
        ld_grpd <= (srst && !ss_we) ? ld_grpd_r : ld_grpd_n;
        ld_byte <= (srst && !ss_we) ? ld_byte_r : ld_byte_n;
        ld_preread <= (srst && !ss_we) ? ld_preread_r : ld_preread_n;
        ld_ripe_prev <= (srst && !ss_we) ? ld_ripe_prev_r : ld_ripe_prev_n;
        st <= (srst && !ss_we) ? st_r : st_n;
        chg <= (srst && !ss_we) ? chg_r : chg_n;
        ending <= (srst && !ss_we) ? ending_r : ending_n;
        rowq <= (srst && !ss_we) ? rowq_r : rowq_n;
        row_posted <= (srst && !ss_we) ? row_posted_r : row_posted_n;
        row_paired <= (srst && !ss_we) ? row_paired_r : row_paired_n;
        rloop_n <= (srst && !ss_we) ? rloop_n_r : rloop_n_n;
        suppress_commit <= (srst && !ss_we) ? suppress_commit_r : suppress_commit_n;
        first_pop_seen <= (srst && !ss_we) ? first_pop_seen_r : first_pop_seen_n;
        rowb0 <= (srst && !ss_we) ? rowb0_r : rowb0_n;
        rowb1 <= (srst && !ss_we) ? rowb1_r : rowb1_n;
        poste <= (srst && !ss_we) ? poste_r : poste_n;
        poll_pipe <= (srst && !ss_we) ? poll_pipe_r : poll_pipe_n;
    end
end

`ifndef JTV30_SYNTHESIS
//--------------------------------------------------------------------------
// THE CLOCKED OBSERVER -- everything that must happen ONCE PER CE CLOCK.
//--------------------------------------------------------------------------
// A combinational block fires its side effects once per SETTLE, not once per
// clock, so none of this can live in the next-state function: `sw/uscope.py`'s
// contract is `row index == CE clock index == +eutrace line number`, and a
// $fatal on a transient value would take a run down for a state the machine
// never stood in.  Everything read here is either a FLOP or a comb value that
// has SETTLED by the edge, which is the same value the old in-line code read.
always @(posedge clk) begin
    if (srst) ce_clk <= 0;
    else if (ce && !ss_we) ce_clk <= ce_clk + 1;
    if (ce && !srst && !ss_we) begin
        // campaign risk #2 / F48: the completed-read store's bound.  Read off
        // the flops, which is what the old in-line assertions read too --
        // nothing before block (a) touches either counter.
        if (eu_rd_done_n) begin
            assert (rdq_n != 2'd2)
                else $warning("v30u_eu: completed-read store overflow (rdq_n=2)");
            assert (rd_done_cnt != 2'd3)
                else $warning("v30u_eu: rd_done_cnt saturated");
        end
        // SM3 sitting 12 (R7') -- THE TWO FALSIFIERS FOR THE DATA-EDGE PSW
        // MOVE (`sm3_s12b_prereg_2026-08-04.md` §3).  They are on the RAW take
        // -- without the `row_blocked` term -- so they see every clock the old
        // block-(a) write would have fired on.  They STAY: they are the only
        // thing between this pass and a silent behavioural change if the F
        // interlock's shape, or the `OPR -> FLAGS` row's own act set, ever
        // moves.
        if (rd_edge_take_raw && s1w_row_blocked)
            assert (!poste && !iend_owed)
                else $error("v30u_eu: R7' falsifier (A): data-edge PSW load with the chain stopped but poste=%0d iend_owed=%0d owed -- they read-modify-write psw_n between the old write site and the commit, so the D-pin form is NOT equivalent here (upc=%0d.%02X.%0d)",
                            poste, iend_owed, upc_page, upc_opc, upc_loc);
        if (rd_edge_take_raw && !s1w_row_blocked)
            assert (row_acts_ok && s1w_e_have1)
                else $error("v30u_eu: R7' falsifier (B): data-edge PSW load with the chain RUNNING but the row not performing its own OPR->FLAGS (row_acts_ok=%0d e_have1=%0d) -- the deleted block-(a) write was NOT dead here (f_wait=%0d nr_wait=%0d rd_done_cnt=%0d rd_pending=%0d upc=%0d.%02X.%0d)",
                            row_acts_ok, s1w_e_have1, f_wait, s1w_nr_wait,
                            rd_done_cnt, rd_pending,
                            upc_page, upc_opc, upc_loc);
        // v30u_eu_poste.svh's two shape assertions.  `poste` is not touched
        // before the post-E block, so the flop IS the value that guarded them.
        if (poste && s1w_row_bus)
            $error("v30u_eu: a post-E row carries a bus cycle (upc %0d.%02X.%0d)",
                   upc_page, upc_opc, upc_loc);
        if (poste && (s1w_row_q1 || s1w_row_q2))
            $error("v30u_eu: a post-E row pops a queue byte");
        if (brktrace && trc_pe_hit)
            $display("PE  clk=%0d pre=%04x post=%04x upc=%03X",
                     ce_clk, trc_pe_pre, trc_pe_post, trc_pe_upc);
        if (brktrace && trc_1bl_hit)
            $display("1BL clk=%0d pre=%04x post=%04x psw=%04x pswn=%04x",
                     ce_clk, trc_1bl_pre, trc_1bl_post, psw, psw_n);
        // wrfuzz W3.5: the 1BL DECODE, with the four bits a lead gate could
        // read.  `smp` is `brk_smp_n` -- "the opcode pop rode THIS clock, so
        // the arm is sampled at the END of the next one".
        if (brktrace && trc_1bld_hit)
            $display("1BLD clk=%0d ripe_lead=%0d seen=%0d arm=%0d smp=%0d shd=%0d",
                     ce_clk, trc_1bld_ripe, trc_1bld_seen, trc_1bld_arm,
                     trc_1bld_smp, trc_1bld_shd);
        if (brktrace) begin
            // the RISE stamp, in the same sense the model's `sample_ie()`
            // means it: at THIS clock the PSW carries TF and at the previous
            // one it did not.
            if (brk_now && !brk_p[0])
                $display("BRKR clk=%0d", ce_clk);
            if (brk_smp)
                $display("BRKS clk=%0d seen=%0d psw_brk=%0d brk_p=%0d arm=%0d",
                         ce_clk, s1w_brk_seen, psw[FBRK], brk_p, brk_arm);
            if (s1w_bnd_fire)
                $display("BRKT clk=%0d arm=%0d irq=%0d sel_brk=%0d",
                         ce_clk, brk_arm, s1w_irq_take, !s1w_irq_take);
        end
        if (eutrace)
            $display("EU st=%0d upc=%0d.%02X.%0d row=%07x q=%02x ripe=%0d slot=%0d post=%0d bs=%0d a=%05x pair=%0d wd=%04x rdd=%0d wrd=%0d oprf=%0d wr_out=%0d pc=%04x ind=%04x opr=%04x of=%0d pnd=%0d pe=%0d rdq=%0d rdc=%0d a=%04x b=%04x c=%04x sig=%04x pfx=%0d",
                     trc_st, trc_upc_page, trc_upc_opc, trc_upc_loc, s1w_row, q_byte, q_ripe,
                     eu_slot_busy_n, eu_post, eu_bs, eu_addr, eu_pair,
                     eu_wdata,
                     eu_rd_done_n, eu_wr_done_n, eu_opr_free, trc_wr_out, trc_pc,
                     trc_ind, trc_opr, trc_opr_fresh, trc_pend_active, trc_poste, trc_rdq_n,
                     trc_rd_done_cnt, trc_tmpa, trc_tmpb, trc_tmpc, sigma, pfxcnt_eff);
        // THE CHAIN BOUND IS A CLAIM, SO IT IS CHECKED.  `CHAIN_MAX` is the
        // number of ZERO-COST model steps that may ride one clock; running out
        // while `stop` is still low would silently push the remainder into the
        // NEXT clock -- a cadence error, not a hang, and therefore invisible
        // without this line.
        //
        // ⚠ WAVE 7 SPLIT IT IN TWO, because the loop's single `!stop` test was
        // conflating two things that the FLAT pass separates.  Both are the
        // same claim as before and both still say CHAIN OVERFLOW.
        //
        //   (i)  THE WALK TERMINATED INSIDE THE PASS.  With one copy per arm
        //        in topological order, `stop` can only still be low here if
        //        some arm handed over to a state the order has already passed
        //        -- a BACKWARD edge in a graph asserted to be a DAG -- or to a
        //        state `st_zero_ok` does not name.  This is the falsifier for
        //        the flattening itself.
        //   (ii) THE DEPTH BOUND, which used to be structural (there were
        //        only CHAIN_MAX copies) and is now measured.  `chain_used`
        //        counts positions entered, and the bound is the derived
        //        maximum 6 = CHAIN_MAX - 1.
        if (chain_open)
            $fatal(1, "v30u_eu: CHAIN OVERFLOW -- the flattened chain pass ended with stop still low (entered in st=%0d, now st=%0d, st_zero_ok=%0d, depth=%0d)",
                   chain_first, st_n, st_zero_ok(st_n), chain_used);
        if (chain_used > CHAIN_MAX - 4'd1)
            $fatal(1, "v30u_eu: CHAIN OVERFLOW at CHAIN_MAX=%0d -- depth %0d (entered in st=%0d, now st=%0d)",
                   CHAIN_MAX, chain_used, chain_first, st_n);
        if (chain_used > chain_hi) begin
            chain_hi = chain_used;
            if (chain_report)
                $display("CHAIN_DEPTH_MAX %0d entry_st %0d", chain_hi, chain_first);
            `ifdef CHAIN_PROBE
            begin : probe
                integer fd;
                fd = $fopen(`CHAIN_PROBE, "a");
                $fwrite(fd, "%0d %0d\n", chain_hi, chain_first);
                $fclose(fd);
            end
            `endif
        end
        //------------------------------------------------------------------
        // WAVE 6 -- THE SEQUENCE CENSUS, ONCE PER CE EDGE ON SETTLED VALUES.
        //------------------------------------------------------------------
        `ifdef CHAIN_PROBE
        begin : cpcensus
            reg [41:0] k;
            integer h, probe_i, slot;
            k = 42'd0;
            for (cpj = 0; cpj < 7; cpj = cpj + 1)
                k = {k[35:0], (cpj < cp_used) ? cp_seq[cpj] : 6'h3F};
            // linear probing; the table is 8,192 wide against a static bound
            // of a few dozen distinct sequences, so it cannot fill -- and if
            // it ever did, the OVERFLOW line below says so rather than
            // silently dropping a sequence.
            h = int'(k % CP_SLOTS);
            slot = -1;
            for (probe_i = 0; probe_i < CP_SLOTS; probe_i = probe_i + 1) begin
                integer idx;
                idx = (h + probe_i) % CP_SLOTS;
                if (!cp_val[idx]) begin
                    cp_val[idx] = 1'b1;
                    cp_key[idx] = k;
                    cp_cnt[idx] = 0;
                    cp_nseq = cp_nseq + 1;
                    slot = idx;
                    break;
                end else if (cp_key[idx] == k) begin
                    slot = idx;
                    break;
                end
            end
            cp_edges = cp_edges + 1;
            if (slot < 0) begin : cpovf
                integer fd;
                fd = $fopen(`CHAIN_PROBE, "a");
                $fwrite(fd, "SEQ_TABLE_OVERFLOW\n");
                $fclose(fd);
            end else begin
                cp_cnt[slot] = cp_cnt[slot] + 1;
                if (cp_cnt[slot] == 1) begin : cpnew
                    integer fd;
                    fd = $fopen(`CHAIN_PROBE, "a");
                    $fwrite(fd, "SEQ %0d", cp_used);
                    for (cpj = 0; cpj < cp_used; cpj = cpj + 1)
                        $fwrite(fd, " %0d", cp_seq[cpj]);
                    $fwrite(fd, "\n");
                    $fclose(fd);
                end
            end
        end
        `endif
    end
end

`ifdef CHAIN_PROBE
// WAVE 6 -- the COUNTS, written once at the end of the run.  The streaming
// `SEQ` lines above say WHICH sequences occurred; this says HOW OFTEN, which
// is what deliverable B's distribution needs.
final begin : cpfinal
    integer fd, i2, j2;
    fd = $fopen(`CHAIN_PROBE, "a");
    $fwrite(fd, "SEQ_EDGES %0d SEQ_DISTINCT %0d\n", cp_edges, cp_nseq);
    for (i2 = 0; i2 < CP_SLOTS; i2 = i2 + 1)
        if (cp_val[i2]) begin
            $fwrite(fd, "SEQCOUNT %0d", cp_cnt[i2]);
            for (j2 = 6; j2 >= 0; j2 = j2 - 1)
                if (cp_key[i2][j2*6 +: 6] != 6'h3F)
                    $fwrite(fd, " %0d", cp_key[i2][j2*6 +: 6]);
            $fwrite(fd, "\n");
        end
    $fclose(fd);
end
`endif
`endif

//============================================================================
// save-state READ mux (arm #2 of the exactly-twice discipline)
//============================================================================
always @(posedge clk) begin
    `include "v30u_eu_ss_read.svh"
end

wire _unused_eu = &{1'b0, q_cnt, halted, lock_pfx, nmi_p[2:0], int_p[0],
                    int_p[3], ie_p[3], ie_p[1:0],
                    ar_full, ar_m, row_paired, imm8,
                    r_ictl, r_ectl, r_sr, r_f, r_w, r_e, r_type, r_nopmove,
                    r_hasconst, r_s1, r_d1, r_s2, r_d2, r_r, dec_valid,
                    SR_ES, SR_SS, SR_DS, R_CW, R_DW, R_SP, BS_PASV,
                    A_SHL6, A_NOT, A_PASS, C_OPC, I_SUSP, I_FLUSH, E_MEMR,
                    TEST_NONE, tk, ti, ts, te, tb, ea, rseg, nloc};

endmodule
