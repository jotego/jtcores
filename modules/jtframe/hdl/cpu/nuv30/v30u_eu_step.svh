//============================================================================
//  v30u_eu_step.svh -- ONE step of the model's program.
//
//  Included at CHAIN POSITION 0 of v30u_eu.sv's flattened chain pass, and
//  ONLY there.  Each arm either
//    * STALLS  (`stop = 1'b1`, `st` unchanged) -- a `while (...) tick()`, or
//    * COMPLETES and hands over to a state that occupies the NEXT clock
//      (`st = ...; stop = 1'b1;`), or
//    * is ZERO-COST and falls through to the next arm inside this same edge
//      (`st = ...;` with no `stop`) -- the model's steps that charge nothing.
//
//  Governance: sim/loader_impl.h and sim/exec_impl.h are the SPEC.
//
//  --- THE NINE ZERO-COST ARMS LIVE IN THEIR OWN FILES (WAVE 7) --------------
//
//  Each of the nine arms that can be reached WITHOUT a `stop` is one line
//  here -- an `include of `v30u_eu_arm_<state>.svh` -- because v30u_eu.sv's
//  flattened pass needs the SAME body at a position >= 1 and the tree may not
//  carry two copies of it.  The body is RELOCATED, never rewritten.  A cut
//  point is a cut point in the SPEC's control flow; each arm file names the
//  `sim/` statement position it stands for.
//
//  --- `if (chain == 4'd0)` -- WHY 24 OF THE 33 ARMS CARRY IT (U4 pass 2) ----
//
//  ⚠ READ THIS FIRST, WAVE 7: this file is now included at position 0 ONLY,
//  so `chain` is 0 wherever the guard is read and all 24 guards are
//  VACUOUSLY TRUE.  They cost nothing (the synthesiser folds a constant) and
//  they are KEPT because they are the machine-readable record of which arms
//  are position-0-only -- the exact complement of `st_zero_ok`, and what
//  `sw/chainflat_graph.py`'s control PC-A1 cross-derives that function from,
//  by a third route, out of this file's text.  **A future edit that makes an
//  arm reachable at a position >= 1 must move it into an arm file and take
//  its guard off, and the two must stay complements.**  What follows is why
//  they were written, and it is still why the nine are the nine.
//
//  The chain loop in v30u_eu.sv USED TO BE UNROLLED: every position cost a
//  full copy of this file, and at CHAIN_MAX = 12 that copy was measured at
//  ~2,200 logic cells -- 12 x 2,200 is what made the EU 30,621 cells and the
//  design unroutable (ucore_provenance.md sec.51).  But a state can only
//  STAND at chain position >= 1 if some arm hands over to it WITHOUT setting
//  `stop`, and only NINE do:
//
//      S_TAKE_OPC  S_DECODE  S_DECODE2  S_EA_CALC  S_BIND
//      S_ENTER     S_TAIL    S_TAIL_POP S_INSTR_END
//
//  Every other arm's predecessors all set `stop` -- read them: S_ROW is
//  entered only from S_ENTER / S_ROW_CHG / S_RLOOP / S_IRQ_D / S_RESET and all
//  five stop; S_DECODE2 stops on every path, which makes S_MODRM, S_NORM_CHG,
//  S_HALTED, S_1BL_LEAD and S_1BL_CHG position-0-only; S_BIND's
//  `if (st != S_ENTER) stop` makes S_PRERD and S_GRPD_CHG position-0-only; and
//  so on.  The 24 guarded arms are therefore UNREACHABLE at chain >= 1 -- so
//  the flat pass does not emit them there at all, which is where the area
//  went -- and the property is falsifiable two ways: the CHAIN OVERFLOW
//  `$fatal` in v30u_eu.sv fires if the pass ever ends with a state still
//  running, and the `st_zero_ok` fail-safe at the entry to positions >= 1
//  spends a clock rather than hanging if one ever did in fabric.  MEASURED as
//  well as argued: a (position, state) census over the golden suite + boot
//  saw exactly those nine states at position >= 1, and WAVE 6 re-measured it
//  over 8,447,821 CE edges from two populations with nothing in common.
//============================================================================
case (st_n)

//----------------------------------------------------------------------------
// loader_impl.h -- `pop_opcode`, the prefix loop
//----------------------------------------------------------------------------
S_OPC_POP: if (chain == 4'd0) begin
    // pop_opcode with an EMPTY latch: the pop rides this clock, then the
    // decoder spends one (`if (!pre) biu.charge(1)`).
    //
    // ...and when this pop is an INSTRUCTION BOUNDARY (`bnd_armed` -- a
    // pre-decode-executed predecessor, or the wake from HALT) the recognition
    // is tested FIRST and needs no byte.
    if (bnd_armed_n && bnd_take) begin
        bnd_armed_n   = 1'b0;
        irq_shadow_n  = 1'b0;
        irq_fast_inta_n = 1'b1;
        irq_sel_nmi_n = irq_nmi_lvl;
        irq_sel_brk_n = !irq_take;      // §86: an EXTERNAL recognition wins
        brk_arm_n     = brk_arm_n && irq_take;   // ...BUT IT DOES NOT SPEND
                                                 //    THE ARM (fz2 C1)
        st_n = S_IRQ_D;
        stop = 1'b1;
    end else if (!q_ripe) stop = 1'b1;
    else begin
        // the pop closes the window and spends the shadow
        bnd_armed_n = 1'b0; irq_shadow_n = 1'b0;
        ld_b_n = q_byte;
        pc_n   = pc_n + 16'd1;
        pop_is_first_n = 1'b0;
        st_n = S_DECODE;
    end
end

S_TAKE_OPC: begin
    `include "v30u_eu_arm_take_opc.svh"
end

S_DECODE: begin
    `include "v30u_eu_arm_decode.svh"
end

S_PFX_CHG: if (chain == 4'd0) begin
    pop_is_first_n = 1'b1;                        // prefix_retire()
    st_n = S_OPC_POP;
    stop = 1'b1;
end

S_EXT_CHG1: if (chain == 4'd0) begin
    st_n = S_EXT_POP;
    stop = 1'b1;
end

S_EXT_POP: if (chain == 4'd0) begin
    // the second byte of the 0F page IS the opcode, and it pops as an S
    if (!q_ripe) stop = 1'b1;
    else begin
        ld_b_n = q_byte;
        pc_n   = pc_n + 16'd1;
        st_n = S_DECODE2;
    end
end

//----------------------------------------------------------------------------
// loader_impl.h -- the post-prefix-loop decode
//----------------------------------------------------------------------------
S_DECODE2: begin
    `include "v30u_eu_arm_decode2.svh"
end

S_1BL_LEAD: if (chain == 4'd0) begin
    // `wait_retire_lead`, and NOTHING ELSE: the execute strobe is the clock
    // BEFORE the successor's opcode pop, so a late queue takes the flag write
    // with it -- but the write itself is made on the edge that hands over to
    // the clock it must be visible during (see S_DECODE2).
    if (!q_ripe_lead_n) stop = 1'b1;
    else begin
        `include "v30u_eu_1bl.svh"
        st_n = S_1BL_CHG;
        stop = 1'b1;
    end
end

S_1BL_CHG: if (chain == 4'd0) begin
    // "pre-decode-executed forms retire in 2 clocks" -- the trailing
    // `biu.charge(1)`, which both arms of the strobe owe.
    st_n = S_INSTR_END;
end

//----------------------------------------------------------------------------
// loader_impl.h -- ModR/M, displacement, effective address
//----------------------------------------------------------------------------
S_MODRM: if (chain == 4'd0) begin
    if (!q_ripe) stop = 1'b1;
    else begin
        ld_rm_n = q_byte;
        pc_n = pc_n + 16'd1;
        ld_disp_n = 16'd0;
        ld_ripe_prev_n = 1'b0;
        chg_n = 2'd0;
        if (q_byte[7:6] == 2'd1)                        st_n = S_D8_A;
        else if (q_byte[7:6] == 2'd2)                   st_n = S_D16_LO;
        else if ((q_byte[7:6] == 2'd0) && (q_byte[2:0] == 3'd6))
                                                        st_n = S_D16_LO;
        else if (q_byte[7:6] != 2'd3)                   st_n = S_EA_CHG;
        else                                            st_n = S_BIND;
        if (st_n != S_BIND) stop = 1'b1;
    end
end

S_D8_A: if (chain == 4'd0) begin
    // opcode+2: no byte is demanded.  M8's `pen` needs to know whether the
    // byte was ALREADY poppable when the demand arrives.
    ld_ripe_prev_n = q_ripe;
    st_n = S_D8_B;
    stop = 1'b1;
end

S_D8_B: if (chain == 4'd0) begin
    if (!q_ripe) stop = 1'b1;
    else if (!ld_ripe_prev_n && (chg_n == 2'd0)) begin
        chg_n = 2'd1;                                     // the `pen` clock
        stop = 1'b1;
    end else begin
        ld_disp_n = {{8{q_byte[7]}}, q_byte};
        pc_n = pc_n + 16'd1;
        st_n = S_EA_CALC;          // ...and the trailing charge(1) spent this clk
    end
end

S_D16_LO: if (chain == 4'd0) begin
    if (!q_ripe) stop = 1'b1;
    else begin
        ld_dlo_n = q_byte;
        pc_n = pc_n + 16'd1;
        st_n = S_D16_A;
        stop = 1'b1;
    end
end

S_D16_A: if (chain == 4'd0) begin
    ld_ripe_prev_n = q_ripe;
    chg_n = 2'd0;
    st_n = S_D16_HI;
    stop = 1'b1;
end

S_D16_HI: if (chain == 4'd0) begin
    if (!q_ripe) stop = 1'b1;
    else if (!ld_ripe_prev_n && (chg_n == 2'd0)) begin
        chg_n = 2'd1;
        stop = 1'b1;
    end else begin
        ld_disp_n = {q_byte, ld_dlo_n};
        pc_n = pc_n + 16'd1;
        st_n = S_EA_CALC;          // ...and the trailing charge(1) spent this clk
    end
end

S_EA_CHG: if (chain == 4'd0) begin
    st_n = S_EA_CALC;              // the EA-compute clock is THIS one
end

S_EA_CALC: begin
    `include "v30u_eu_arm_ea_calc.svh"
end

//----------------------------------------------------------------------------
// loader_impl.h -- group dispatch, OPC select, operand binding
//----------------------------------------------------------------------------
S_NORM_CHG: if (chain == 4'd0) begin
    st_n = S_BIND;                 // the opcode+1 clock is THIS one
end

S_BIND: begin
    `include "v30u_eu_arm_bind.svh"
end

S_PRERD: if (chain == 4'd0) begin
    // the pre-decode operand read; `wait_opr` opens micro-row 0 at its T4 + 2
    if (!row_posted_n) begin
        if (eu_slot_busy_n) stop = 1'b1;
        else begin
            row_posted_n = 1'b1;
            // The pre-read fills OPR at the OPERAND's width, exactly as a
            // microcoded read does; the tag rides with the datum
            // (`loader_impl.h`: `m.opr_byte = mo.byte`).  Note it is the
            // OPERAND's width and not the bus cycle's: `eu_word` forces a word
            // cycle on the ghost pre-read tail, and the DATUM is still the
            // decoder's byte there.
            if (rd_pending_n == 2'd0)      rdp0_byte_n = pr_byte;
            else if (rd_pending_n == 2'd1) rdp1_byte_n = pr_byte;
            // F48/U4: saturate, do not wrap (see v30u_eu_row.svh).
            if (rd_pending_n != 2'd3) rd_pending_n = rd_pending_n + 2'd1;
            stop = 1'b1;
        end
    end else if (rd_done_cnt_n == 2'd0) begin
        stop = 1'b1;
    end else begin
        rd_done_cnt_n = rd_done_cnt_n - 2'd1;
        if (rdq_n_n != 2'd0) begin
            opr_n = rdq0_n; rdq0_n = rdq1_n; rdq_n_n = rdq_n_n - 2'd1;
                    // ...and the width tag pops out of the same slot
                    opr_byte_n = rdq0_byte_n; rdq0_byte_n = rdq1_byte_n;
            opr_loaded_n = 1'b1;                              // §87.A
        end
        // F27 -- THE PRE-DECODE READ DOES NOT MAKE OPR "FRESH".  The loader
        // assigns `m.opr = biu.mem_read(...)` DIRECTLY (loader_impl.h:495) and
        // never touches `opr_fresh_`, which `begin_sequence()` left false --
        // the pairing latch is armed by a `-> OPR` TRANSFER, not by a read.
        // With it set, `86`/`87`'s write-back row emitted the store the instant
        // it posted, handing the bus the operand the pre-read had just brought
        // IN (`86 idx 0`: 9054) instead of the register the post-`E` row
        // `tmpb -> M` is about to swap OUT (9f3e).
        row_posted_n = 1'b0;
        st_n = ld_grpd_n ? S_GRPD_CHG : S_ENTER;
        if (ld_grpd_n) stop = 1'b1;
    end
end

S_GRPD_CHG: if (chain == 4'd0) begin
    st_n = S_ENTER;
end

S_ENTER: begin
    `include "v30u_eu_arm_enter.svh"
end

//----------------------------------------------------------------------------
// exec_impl.h -- run_micro
//----------------------------------------------------------------------------
S_ROW: if (chain == 4'd0) begin
    if (row_blocked) begin
        stop = 1'b1;                                    // stall_opr
    end else if (row_need_q && !q_ripe) begin
        stop = 1'b1;                                    // stall_q
    end else if (row_need_q) begin
        if (row_q1 && (rowq_n == 2'd0)) rowb0_n = q_byte; else rowb1_n = q_byte;
        pc_n = pc_n + 16'd1;
        rowq_n = rowq_n + 2'd1;
        if ({1'b0, rowq_n} < row_qn) stop = 1'b1;         // a second byte
    end else if (row_pre_wait) begin
        stop = 1'b1;                                    // deliver_read
    end else if (row_slot_wait) begin
        // F11 AGAIN, AND THIS TIME IN THE PAIRING DIMENSION.  `bus_write` is
        //     if (pend_.active) { if (!opr_fresh_) deliver_read();
        //                         emit_pending(); }
        //     biu_.write_request(...);        <- the slot wait is IN HERE
        // so the staged write is PAIRED BEFORE the slot is waited on.  The act
        // decode had that right (`eu_pair` carries no slot term, and the BIU
        // took the word), and only the STEP stalled first -- so `pend_active`
        // stayed set, the row re-ran `row_pre_wait` against an OPR the pairing
        // had just re-taken, and the row cost two extra clocks.
        // MEASURED, `F3AA idx 2`: the third store row stands on golden rows
        // 13-17 where the model stands on 13-15, and rows 14-16 are exactly
        // this -- `eu_pair` already asserted on 13 with `pnd` still 1.
        if (row_bus && pend_active_n) begin
            if (!opr_fresh_n) begin
                if (rd_done_cnt_n != 2'd0) rd_done_cnt_n = rd_done_cnt_n - 2'd1;
                if (rdq_n_n != 2'd0) begin
                    opr_n = rdq0_n; rdq0_n = rdq1_n; rdq_n_n = rdq_n_n - 2'd1;
                    // ...and the width tag pops out of the same slot
                    opr_byte_n = rdq0_byte_n; rdq0_byte_n = rdq1_byte_n;
                    opr_loaded_n = 1'b1;                      // §87.A
                end
            end
            pend_active_n = 1'b0;
            opr_fresh_n   = 1'b0;
        end
        // stall_slot -- F11's rule, in the SLOT dimension.  `BiuTimed::post`
        // waits on the slot and THEN takes it, both inside the row, so a row
        // that posts this clock does NOT wait this clock.  `eu_slot_busy_n`
        // already carries this row's OWN post (it is what set it), so without
        // `!eu_post` the step stalls on an event it itself caused and the row
        // runs one clock too long -- invisible on an aligned store (the pairing
        // still lands before T1) and fatal on a SPLIT one, where the extra
        // clocks push the pairing past the FIRST half's T1 (`50 idx 1`, data
        // 0000 on rows 6-8 against the golden's AX).
        stop = 1'b1;
    end
    if (!stop) begin
        // the F interlock's own delivery, taken once
        if (e_f) begin
            if (row_reads_opr && (rd_done_cnt_n != 2'd0))
                rd_done_cnt_n = rd_done_cnt_n - 2'd1;
            if (rdq_n_n != 2'd0) begin
                opr_n = rdq0_n; rdq0_n = rdq1_n; rdq_n_n = rdq_n_n - 2'd1;
                    // ...and the width tag pops out of the same slot
                    opr_byte_n = rdq0_byte_n; rdq0_byte_n = rdq1_byte_n;
                opr_fresh_n = 1'b1;
                opr_loaded_n = 1'b1;                          // §87.A
            end
        end
        `include "v30u_eu_row.svh"
        if (tmpa_n != tmpa) begin
            // 8F row 0058 copies the standing SIGMA into tmpa.  If a distinct
            // ModR/M EA rail was already selected, the absent register-form
            // operand does not overwrite it; otherwise SIGMA becomes the
            // residue.  The next row observes the result directly, so no
            // extra address-history register is needed.
            if (!((upc_page == 3'd0) && (upc_opc == 8'h8f) &&
                  (upc_loc == 4'd0) && (m_kind_n == OK_REG) &&
                  (wb_kind_n == OK_REG) && (ea_residue_n != tmpa)))
                ea_residue_n = tmpa_n;
        end
        // Any real B-input micro-operation replaces what the EA calculation
        // left on the adder's B rail.  This is why an intervening INC or LDS
        // exposes tmpb, while mc2/491's byte load leaves the earlier SI rail
        // standing.
        if (tmpb_n != tmpb) ea_pair_valid_n = 1'b0;
    end
end

S_ROW_CHG: if (chain == 4'd0) begin
    // the taken-JMP / FARJMP redirect bubble (M11 / 7.7)
    st_n = S_ROW;
    stop = 1'b1;
end

S_RLOOP: if (chain == 4'd0) begin
    // `R`: one iterative step per clock, COUNT times.  The row's own ALU
    // latch drives the ONE shared iterative unit; afterwards it is SPENT.
    count_n = count_n - 16'd1;
    rloop_n_n = rloop_n_n - 16'd1;
    if (it_fmask != 16'd0)
        stat_n = (stat_n & ~it_fmask) | (it_flags & it_fmask);
    if (!e_nopmv) begin
        v1 = it_val;
        bsw = 1'b0;
        // The loop's result carries the width the loop RAN at.  It needs no
        // latch: the tag the destination takes is `al_width_byte` itself, and
        // `al_width_byte` is an OR that already contains whichever tag this
        // write moves -- so the value is IDEMPOTENT across the iterations, and
        // that is what `exec_impl.h`'s hoisted `loop_byte` is saying.
        wb1 = al_width_byte;
        `include "v30u_eu_wd1.svh"
    end
    // `alu_step` writes `m.tmpa` DIRECTLY (the multiply/divide low half) and
    // does NOT touch its tag; neither does this.
    if (it_writes_tmpa) tmpa_n = it_tmpa;
    if (tmpa_n != tmpa) ea_residue_n = tmpa_n;
    if (tmpb_n != tmpb) ea_pair_valid_n = 1'b0;
    if (e_w && (it_fmask != 16'd0)) commit_flags(it_fmask, it_flags);
    // `while (count != 0)`: the model runs the operation COUNT times, so the
    // terminator is read AFTER this clock's decrement -- reading it before
    // (`== 1`) runs COUNT-1 iterations and, at COUNT==1, none at all: the
    // counter wraps and the state never leaves.  All sixteen D0.x/D1.x forms
    // (shift-by-1, so COUNT is always 1) hung on it.
    if (rloop_n_n == 16'd0) begin      // this was the last iteration
        al_spent_n = 1'b1;
        // F26: the sequencer leaves the `R` row HERE, not before the loop.
        if (upc_loc_n == 4'hF) upc_opc_n = upc_opc_n + 8'd1;
        upc_loc_n = upc_loc_n + 4'd1;
        st_n = S_ROW;
    end
    stop = 1'b1;
end

S_EPOP: if (chain == 4'd0) begin
    // the E row's successor pop, deferred past the retire deadline
    if (!retire_ok_n) stop = 1'b1;
    // ...and the BOUNDARY is that deadline alone (`boundary_no_pop`'s
    // `wait_bus()`), so it is taken here whether or not the byte is ripe.
    // The post-`E` row still runs -- the model reaches it through the same
    // `ending` pass -- so the debt is raised exactly as the pop path raises it.
    else if (bnd_take) begin
        irq_shadow_n = 1'b0;
        irq_sel_nmi_n = irq_nmi_lvl;
        irq_sel_brk_n = !irq_take;                                // §86
        brk_arm_n = brk_arm_n && irq_take;                        // fz2 C1
        poste_n = 1'b1; pe_opc_reg_n = opc_reg_n; pe_opc8080_n = opc8080_n;
        pe_op8_n = op8_n; pe_pfxcnt_n = pfxcnt_n;
        st_n = S_IRQ_D;
        stop = 1'b1;
    end
    else if (!q_ripe) stop = 1'b1;
    else begin
        irq_shadow_n = 1'b0;
        opc_byte_n = q_byte;
        opc_valid_n = 1'b1;
        pop_is_first_n = 1'b0;
        poste_n = 1'b1; pe_opc_reg_n = opc_reg_n; pe_opc8080_n = opc8080_n;  // F23
        pe_op8_n = op8_n; pe_pfxcnt_n = pfxcnt_n;                         // D1 / F22
        st_n = S_TAIL;          // ...and the E row's own charge(1) spent this clk
    end
end

S_TAIL: begin
    `include "v30u_eu_arm_tail.svh"
end

S_TAIL_W: if (chain == 4'd0) begin
    // `if (!opr_fresh_) deliver_read(); emit_pending();`
    if (!opr_fresh_n && (nr_wait || !opr_free_now)) stop = 1'b1;
    else begin
        if (!opr_fresh_n) begin
            if (rd_done_cnt_n != 2'd0) rd_done_cnt_n = rd_done_cnt_n - 2'd1;
            if (rdq_n_n != 2'd0) begin
                opr_n = rdq0_n; rdq0_n = rdq1_n; rdq_n_n = rdq_n_n - 2'd1;
                    // ...and the width tag pops out of the same slot
                    opr_byte_n = rdq0_byte_n; rdq0_byte_n = rdq1_byte_n;
                opr_loaded_n = 1'b1;                          // §87.A
            end
        end
        pend_active_n = 1'b0;
        opr_fresh_n   = 1'b0;
        // §35.4 -- `emit_pending()` IS ZERO CLOCKS, ALWAYS (it fills a slot the
        // bus has already reserved), and `deliver_read()` is a WAIT: zero when
        // the condition already holds.  So the satisfied arm must FALL THROUGH
        // to the tail's pop inside this same edge, not hand it the next clock.
        // The `stop` that stood here charged one clock against a step the
        // model charges nothing for.
        if (opc_valid_n) begin
            st_n = S_INSTR_END;
        end else if (retire_ok_n && bnd_take) begin
            // the tail's own boundary, taken right where the model takes it
            irq_shadow_n  = 1'b0;
            irq_sel_nmi_n = irq_nmi_lvl;
            irq_sel_brk_n = !irq_take;                            // §86
            brk_arm_n = brk_arm_n && irq_take;                    // fz2 C1
            st_n = S_IRQ_D;
            stop = 1'b1;
        end else begin
            st_n = S_TAIL_POP;
        end
    end
end

S_TAIL_POP: begin
    `include "v30u_eu_arm_tail_pop.svh"
end

S_HALTED: if (chain == 4'd0) begin
    // stall_pin -- and THE WAKE.  A halted part has no boundary of its own, so
    // the decision clock D is simply the first clock the pin pipeline has
    // matured the event on; the would-pop clock is D+1 and the entry, as ever,
    // is two clocks past that.  `eu_unhalt` is combinational off this state
    // (INT) or owed to the entry clock (NMI, where the bus is HELD).
    if (irq_nmi_lvl) begin
        bnd_armed_n = 1'b1;
        st_n = S_OPC_POP;
    end else if (irq_pin_int) begin
        eu_halted_n = 1'b0;              // `eu_unhalt` rides THIS clock
        bnd_armed_n = 1'b1;
        irq_halt_entry_n = 1'b1;
        st_n = S_OPC_POP;
    end
    stop = 1'b1;
end

S_IRQ_D: if (chain == 4'd0) begin
    // The HALT provenance remains visible through the first INTA post.  That
    // single event both withdraws the wake fetch and defers INTA arbitration;
    // the post itself spends the bit.
    // `CpuT::interrupt()`.  ONE internal decision clock (the boundary was the
    // clock before), then the entry's first row.  The loader is BYPASSED, so
    // every latch it would have written is presented explicitly -- in
    // particular `xop`, without which the vector fetch's `SR = IO` would be
    // re-classified as a port access (ledger A24), and `op8`, without which
    // 01EC's `2*vector` truncates.
    // §86 -- THE THIRD DOOR IS THE ONE THAT WAS ALREADY THERE.  The ROM's
    // 01D8 entry is `CONST 1` at row 0 and `CONST 2` at row 2: the single-step
    // vector and the NMI vector are the SAME entry, two rows apart, and the
    // trap needs no new sequence -- only a `loc` of 0 where NMI takes 2.
    // `FBRK` is cleared on the way in by `I_CITF` (v30u_eu_poste.svh vector 1),
    // exactly as `FIE` is, so the arm's own floor drains behind the entry and
    // the handler does not single-step itself.
    upc_page_n = 3'd7;
    upc_opc_n  = (irq_sel_nmi_n || irq_sel_brk_n) ? 8'h00 : 8'h02;
    upc_loc_n  = irq_sel_nmi_n ? 4'd2  : 4'd0;
    if (irq_sel_nmi_n) nmi_latch_n = 1'b0;
    // NMI may still need the boundary-origin bit during row 7.10.0's fixed-
    // vector overlap decision.  BRK has no waited cold-pop overlap; the bit is
    // cleared for both paths no later than the first vector-read row.
    if (irq_sel_brk_n) irq_fast_inta_n = 1'b0;
    seg_override_n = 1'b0; seg_ovr_n = 2'd3; rep_kind_n = REP_NONE; lock_pfx_n = 1'b0;
    pfxcnt_n = 8'd0;
    m_kind_n = OK_NONE; m_idx_n = 3'd0; m_ea_n = 16'd0; m_seg_n = 3'd3; m_byte_n = 1'b0;
    r_kind_n = OK_NONE; r_idx_n = 3'd0; r_ea_n = 16'd0; r_seg_n = 3'd3; r_byte_n = 1'b0;
    wb_kind_n = OK_NONE; wb_idx_n = 3'd0; wb_ea_n = 16'd0; wb_seg_n = 3'd3;
    wb_byte_n = 1'b0;
    opc_base_n = 5'd0; opc_from_modrm_n = 1'b0; modrm_reg_n = 3'd0; opc_reg_n = 8'd0;
    rep_test_n = TEST_NONE; rep_pol_n = 1'b0; xop_n = 4'd0;
    op8_n = 1'b0; imm8_n = 1'b0; bus_word_n = 1'b0; opc8080_n = 1'b0;
    al_op_n = A_ADD; al_tmp_n = 2'd0;
    al_eaconst_n = 1'b0; al_eaval_n = 16'd0;
    al_adjust_n = 2'd0; al_adjtmp_n = 2'd0; al_bitarm_n = 1'b0; al_bitn_n = 4'd0;
    al_spent_n = 1'b0;
    // begin_sequence(): the pairing latch and the completed-read store
    pend_active_n = 1'b0; pend_off_n = 16'd0; pend_seg_n = 3'd3;
    pend_byte_n = 1'b0; pend_io_n = 1'b0; opr_fresh_n = 1'b0;
    opr_loaded_n = 1'b0;                                      // §87.A
    rdq0_n = 16'd0; rdq1_n = 16'd0; rdq_n_n = 2'd0;
    rdq0_byte_n = 1'b0; rdq1_byte_n = 1'b0;   // ...and their width tags
    ld_ext_n = 1'b0; ld_hasrm_n = 1'b0; ld_grpd_n = 1'b0; ld_preread_n = 1'b0;
    ld_rm_n = 8'd0; ld_disp_n = 16'd0;
    ending_n = 1'b0; rowq_n = 2'd0; row_posted_n = 1'b0; row_paired_n = 1'b0;
    suppress_commit_n = 1'b0;
    opc_valid_n = 1'b0; pop_is_first_n = 1'b1; bnd_armed_n = 1'b0;
    irq_shadow_n = 1'b0;
    intr_pending_n = 1'b0;                       // `m_.intr_pending = false`
    rep_chain_n = 1'b0;                          // `begin_sequence()`
    if (eu_halted_n) begin
        eu_halted_n = 1'b0;
        unhalt_pend_n = 1'b1;   // the NMI wake: `unhalt()` AT the entry clock
    end
    st_n = S_ROW;
    stop = 1'b1;
end

S_RESET: if (chain == 4'd0) begin
    // F25: `biu.susp(); biu.charge(kResetEntryClocks);` -- the internal reset
    // dispatch, before the ROM's own reset rows at 7.03.0 (01D0).
    rst_ctr_n = rst_ctr_n + 3'd1;
    if (rst_ctr_n == 3'd4) st_n = S_ROW;
    stop = 1'b1;
end

S_INSTR_END: begin
    `include "v30u_eu_arm_instr_end.svh"
end

default: stop = 1'b1;
endcase
