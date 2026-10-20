//============================================================================
//  v30u_eu_row.svh -- ONE micro-row's work, exec_impl.h::run_micro's body.
//  Reached with the F interlock clear, every queue byte the row asked for
//  already taken, and its bus request already posted (all three are acts of
//  THIS clock; see the combinational output block in v30u_eu.sv).
//============================================================================
begin
    // --- the two parallel transfers -----------------------------------
    if (e_have1 && !e_is_rloop) begin
        // F21: `opr` is a LIVE BLOCKING variable here -- the `F` interlock's
        // delivery (S_ROW, just above) has already written it, and the model
        // does the delivery at the TOP of the row, before the transfers.
        // `s1_val` is a WIRE off the REGISTER, so it still holds the pre-edge
        // word: `58`'s `OPR -> M` wrote AX = 0 in 500/500 cases.  F11b's trap,
        // third instance -- in this EU a wire named like a step variable is
        // not that step variable.
        v1  = (e_s1 == 5'd7) ? {8'd0, rowb0_n}
            : (e_s1 == 5'd6) ? opr_n
            : s1_val;
        // ...and the WIDTH TAG follows the SAME three arms, for the same
        // reason: `opr_n` is the word the `F` delivery just put there, so its
        // tag has to be the one that came out of the store with it.
        wb1 = (e_s1 == 5'd7) ? 1'b1
            : (e_s1 == 5'd6) ? opr_byte_n
            : s1_wbyte;
        bsw = s1_byte;
        if (e_s1 == 5'd6) opr_fresh_n = 1'b0;      // reading OPR CONSUMES it
        if (e_s1 == 5'd20) begin
            if (sig_mask != 16'd0)
                stat_n = (stat_n & ~sig_mask) | (sig_flags & sig_mask);
        end
        if ((e_s1 == 5'd20) && !sig_commits) begin
            // CMP: the ALU does not drive the result bus, so neither the
            // register/OPR write nor its memory commit happens
            if ((e_d1 == 5'd19) && (m_kind_n == OK_MEM)) suppress_commit_n = 1'b1;
        end else begin
            `include "v30u_eu_wd1.svh"
        end
    end
    if (e_have2 && !e_is_rloop) begin
        v2  = (e_s2 == 4'd5) ? {8'd0, rowb1_n} : s2_val;
        wb2 = (e_s2 == 4'd5) ? 1'b1           : s2_wbyte;
        if (e_s2 == 4'd4) begin
            if (sig_mask != 16'd0)
                stat_n = (stat_n & ~sig_mask) | (sig_flags & sig_mask);
        end
        if (!((e_s2 == 4'd4) && !sig_commits)) begin
            case (e_d2)
                2'd0: begin tmpa_n = v2; tmpa_byte_n = wb2; end
                2'd1: begin tmpb_n = v2; tmpb_byte_n = wb2; end
                2'd2: ind_n  = v2;
                default: ;
            endcase
        end
    end
    // --- flag write ----------------------------------------------------
    if (!e_is_rloop && e_w && !ext4s_early_wblock && (sig_mask != 16'd0))
        commit_flags(sig_mask, sig_flags);

    // --- row type ------------------------------------------------------
    nloc  = upc_loc_n + 4'd1;
    carry = (upc_loc_n == 4'hF);
    taken = 1'b0;
    bubble = 1'b0;

    if (e_type == TY_ALU) begin
        // the NEXT latched operation
        al_adjust_n  = (al_op_n == A_ADJD) ? 2'd1 : (al_op_n == A_ADJA) ? 2'd2 : 2'd0;
        al_adjtmp_n  = al_tmp_n;
        al_bitarm_n  = (al_op_n == A_BIT);
        al_bitn_n    = bit_n_n;
        al_spent_n   = 1'b0;
        al_op_n      = r_aluop;
        al_tmp_n     = r_alutmp;
        // `al_byte_n = op8_n` STOOD HERE AND IS THE DEFECT.  Nothing latches
        // the width now: `al_width_byte` reads the tag of the register the
        // ALU's port takes its operand from, AT THE INSTANT THE CONSUMING ROW
        // EVALUATES -- which it has to be, because `80/81/83` latch `ALU OPC
        // tmpa` here at 003E and only load port A with the r/m operand at
        // 003F, one row later.
        al_eaconst_n = 1'b0;
        // An armed ADJD/ADJA the next latched op does NOT consume DISCHARGES:
        // the adjust unit writes its plain truncation back (030B, EXT).
        if ((al_adjust_n != 2'd0) && (nxt_op != A_ADD) && (nxt_op != A_SUB)) begin
            case (al_adjtmp_n)
                2'd0: tmpa_n = tmpa_n & ((al_adjust_n == 2'd2) ? 16'h000F : 16'h00FF);
                2'd1: tmpb_n = tmpb_n & ((al_adjust_n == 2'd2) ? 16'h000F : 16'h00FF);
                default: tmpc_n = tmpc_n & ((al_adjust_n == 2'd2) ? 16'h000F : 16'h00FF);
            endcase
            al_adjust_n = 2'd0;
        end
        // F29 -- ...AND SO DO THE ARMING CAPTURES.  `exec_impl.h` builds its
        // `tmps[]` from the LIVE `m_.tmpa/b/c` in the ALU-latch block, which
        // runs AFTER the row's transfers -- and the rows that arm BIT and ABS
        // are exactly the rows that load the tmp they read (`0F10`:
        // `02AC  M -> tmpb  CX -> tmpa  ALU BIT tmpa`).  `tmps_lat` is a WIRE
        // off the REGISTERS, so the bit index came from the PREVIOUS
        // instruction's tmpa and the whole 0F 10-1F block tested the wrong bit.
        // F11b's trap again.
        case (r_alutmp)
            2'd0: tsel_n = tmpa_n;
            2'd1: tsel_n = tmpb_n;
            2'd2: tsel_n = tmpc_n;
            default: tsel_n = 16'd0;
        endcase
        if (r_aluop == A_BIT)
            bit_n_n = tsel_n[3:0] & (op8_n ? 4'd7 : 4'd15);
        if (r_aluop == A_ABS)
            sign_neg_n = op8_n ? tsel_n[7] : tsel_n[15];
    end else if (e_type == TY_JMP) begin
        `include "v30u_eu_cond.svh"
        if (taken) begin
            nloc  = r_loc;
            carry = 1'b0;
            // M11: NO bubble on a jump BACK BY ONE ROW -- the target is the
            // row the sequencer read one clock ago.
            if ((r_loc + 4'd1) != upc_loc_n) bubble = 1'b1;
        end
    end else begin
        // --- CTL -------------------------------------------------------
        if (e_farjmp) begin
            upc_page_n = 3'd7;
            upc_opc_n  = {r_farloc, 3'd0};
            nloc  = 4'd0;
            carry = 1'b0;
            bubble = 1'b1;              // a FARJMP pays the redirect bubble
        end else begin
            case (e_ictl)
                I_MFS:     mode8080_n = 1'b0;
                I_MFC:     mode8080_n = 1'b1;
                I_ENDEM:   mode8080_n = 1'b0;
                I_CITF:    begin psw_n[FIE] = 1'b0; psw_n[FBRK] = 1'b0; end
                I_CLRCYV:  begin psw_n[FCY] = 1'b0; psw_n[FV] = 1'b0; end
                I_SETCYV:  begin psw_n[FCY] = 1'b1; psw_n[FV] = 1'b1; end
                I_SIGNTGL: sign_neg_n = sign_neg_n ^ (op8_n ? tmpb_n[7] : tmpb_n[15]);
                I_BCDINIT: begin psw_n[FCY] = 1'b0; sign_neg_n = 1'b1; end
                I_BCDNZ:   if (!stat_n[FZ]) sign_neg_n = 1'b0;
                default: ;                // SUSP / FLUSH rode this clock
            endcase
            psw_n = (psw_n & PSW_WRITABLE) | PSW_FORCED;
        end
        // --- the bus cycle (posted combinationally on this clock) ------
        if (e_ectl == E_INTATAIL) bus_word_n = 1'b1;
        // F20: `if (pend_.active) { if (!opr_fresh_) deliver_read();
        // emit_pending(); }` -- a staged store runs BEFORE this row's own
        // cycle, and it is given the completed-read store's head if the row's
        // transfers did not already refresh OPR.  The wire the BIU reads is
        // `opr_now`'s `row_pre_deliver` arm: same event, same expression.
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
        if (row_bus) begin
            if (row_is_wr || row_is_wb) begin
                pend_active_n = 1'b1;
                pend_off_n  = acc_off_nog;
                pend_seg_n  = acc_seg;
                pend_byte_n = acc_byte;
                pend_io_n   = acc_io;
                // F48/U4, the same house rule as `rdq_n`/`rd_done_cnt` in
                // v30u_eu.sv: a bounded counter SATURATES, it does not wrap.
                // `wr_out` and `rd_pending` are the two the bound audit found
                // with NO guard of any kind -- not even a simulation-only
                // assertion -- so before this they wrapped in simulation and in
                // fabric alike.  Both are decremented with an explicit
                // `!= 2'd0` floor already; this is the matching ceiling.
                if (acc_split_wr) wr_out_n = (wr_out_n >= 2'd2) ? 2'd3
                                                         : wr_out_n + 2'd2;
                else if (wr_out_n != 2'd3) wr_out_n = wr_out_n + 2'd1;
            end else begin
                // ...AND THE POSTED READ'S WIDTH GOES INTO THE RECORD WITH
                // IT, oldest first, because the completion that brings the
                // word back carries no tag of its own.  An INTA acknowledge
                // delivers ONE byte on the low lane (`bus_inta`), whatever
                // the row's operand width says.
                if (rd_pending_n == 2'd0)
                    rdp0_byte_n = row_is_inta ? 1'b1 : acc_byte;
                else if (rd_pending_n == 2'd1)
                    rdp1_byte_n = row_is_inta ? 1'b1 : acc_byte;
                if (rd_pending_n != 2'd3) rd_pending_n = rd_pending_n + 2'd1;
                // The 8F ghost read ARMS the discard here, on the clock its
                // own row posts.  The guard is the regime the mechanism is
                // measured in: an empty read pipeline, so this row IS the
                // chain's head.  Behind an older read the baseline delivery
                // is retained rather than inventing a tag queue.
                if (ghost_read_stale_alu && (rd_pending_n == 2'd1))
                    ghost_rd_discard_n = 1'b1;
            end
        end
    end

    // --- the write-data pairing latch (`emit_pending`) -----------------
    if (pend_active_n && opr_fresh_n) begin
        pend_active_n = 1'b0;
        opr_fresh_n   = 1'b0;
    end

    // --- cadence -------------------------------------------------------
    // F26 -- AN `R` ROW KEEPS THE SEQUENCER WHILE IT ITERATES.  The loop is
    // `while (m_.count != 0) { ... wr_dst1(op.d1, ...) }` INSIDE the row's own
    // iteration, so every step writes THE R ROW'S Dest1.  Advancing `upc`
    // before entering S_RLOOP handed the loop its SUCCESSOR's row word:
    // `D1.4`'s `0116 SIGMA -> tmpb  W R ALU OPC` wrote through `0117`'s
    // `SIGMA -> M` instead, so the shift result never reached tmpb and every
    // shift/rotate form left its operand untouched.  The advance now happens
    // where the loop ENDS -- which is also where the model leaves the row.
    if (!e_is_rloop || (count_n == 16'd0)) begin
        upc_loc_n = nloc;
        if (carry) upc_opc_n = upc_opc_n + 8'd1;
    end
    rowq_n = 2'd0; row_posted_n = 1'b0; row_paired_n = 1'b0;

    if (e_is_rloop) begin
        // `R`: the row's own operation runs COUNT times, one step per clock
        if (count_n == 16'd0) begin
            al_spent_n = 1'b1;
            st_n = S_ROW;
        end else begin
            rloop_n_n = count_n;
            st_n = S_RLOOP;
        end
        stop = 1'b1;
    end else if (e_e || ext4s_early_e) begin
        // the successor's opcode pop rides the E row's own clock; a store the
        // pairing latch still owes data defers it to the sequence tail.
        // F11, stated the only way that cannot drift: the demand and the take
        // read THE SAME WIRES.  `retire_ok_e` and `pend_after` are the exact
        // post-row values this block would otherwise recompute from its live
        // blocking copies -- reconstructing them twice is what let the two
        // sides disagree in pass 1.  (`retire_ok_n` reads the REGISTER `wr_out`
        // and is NOT this predicate.)
        // F24 is a term of the TAKE as well as of the demand: a row that
        // FLUSHES has already emptied the queue by the time the model reaches
        // `opcode_prefetch`, so it cannot keep a byte either.
        retire_now = retire_ok_e;
        // S9a -- A RECOGNISED BOUNDARY RUNS THE RETIRE DEADLINE AND KEEPS THE
        // BYTE.  The sequence still finishes its post-`E` row (which costs no
        // clocks but does carry datapath work -- `9D`'s `SIGMA -> SP` lives
        // there); only the successor's decode is what does not happen.
        if (bnd_fire) begin
            irq_sel_nmi_n = irq_nmi_lvl;
            irq_sel_brk_n = !irq_take;                            // §86
            brk_arm_n = brk_arm_n && irq_take;                    // fz2 C1
            poste_n = 1'b1; pe_opc_reg_n = opc_reg_n; pe_opc8080_n = opc8080_n;
            pe_op8_n = op8_n; pe_pfxcnt_n = pfxcnt_n;
            st_n = S_IRQ_D;
            stop = 1'b1;
        end else if (!pend_after && !opc_valid_n && retire_now && q_ripe &&
                     !row_flush)
        begin
            // the POP is what closes the boundary window, so it is the pop
            // that spends the shadow -- "the chip re-enables the boundary
            // sample at the shadowed instruction's successor pop".
            irq_shadow_n = 1'b0;
            opc_byte_n = q_byte;
            opc_valid_n = 1'b1;
            pop_is_first_n = 1'b0;
            poste_n = 1'b1; pe_opc_reg_n = opc_reg_n; pe_opc8080_n = opc8080_n;  // F23
            pe_op8_n = op8_n; pe_pfxcnt_n = pfxcnt_n;                     // D1 / F22
            st_n = S_TAIL;
        end else if (!pend_after && !opc_valid_n) begin
            st_n = S_EPOP;
            stop = 1'b1;
        end else begin
            poste_n = 1'b1; pe_opc_reg_n = opc_reg_n; pe_opc8080_n = opc8080_n;  // F23
            pe_op8_n = op8_n; pe_pfxcnt_n = pfxcnt_n;                     // D1 / F22
            st_n = S_TAIL;
        end
    end else begin
        st_n = bubble ? S_ROW_CHG : S_ROW;
        stop = 1'b1;
    end
end
