//==========================================================================
//  v30u_eu_arm_instr_end.svh -- ONE CHAINABLE ARM OF THE MODEL'S STEP,
//  carried in its own file so that the flattened chain and the
//  33-arm case can both `include it and there is exactly ONE copy
//  of the body in the tree (WAVE 7, G-11).
//
//  IT IS INCLUDED IN TWO PLACES AND NOWHERE ELSE:
//    * v30u_eu_step.svh's `case (st_n)`, i.e. chain POSITION 0;
//    * v30u_eu.sv's flattened pass, i.e. chain POSITION >= 1.
//  Both sites supply the surrounding `begin` / `end`, so this file
//  is a STATEMENT LIST and nothing else.  It declares nothing and
//  carries no block label: it is elaborated twice in one scope.
//
//  THE SPEC POSITION IT IS A CUT POINT IN (WAVE 6 sec.1, and it is
//  why this arm is zero-cost at all -- there is no `charge()`
//  between it and its predecessor):
//    exec_impl.h:1114-1117 / loader_impl.h:190-211 -- `step()` returns; the successor's `begin_sequence()` / `clear_consumed()` and the per-instruction latch reset
//==========================================================================
    // ZERO-COST: `step()` returns; the successor's `clear_consumed()` and
    // `loader_decode()`'s per-instruction latch reset run here.
    seg_override_n = 1'b0; seg_ovr_n = 2'd3; rep_kind_n = REP_NONE; lock_pfx_n = 1'b0;
    rep_test_n = TEST_NONE; rep_pol_n = 1'b0; bus_word_n = 1'b0; opc8080_n = 1'b0;
    // F22 SETTLED: `pfxcnt` is reset HERE, with the rest of the prologue, and
    // NOT in `iend_late` -- the prefix arm below writes it on this same edge,
    // so a deferred reset would land on top of the successor's own count.  The
    // post-`E` row reads its travelling copy (`pfxcnt_eff`).
    pfxcnt_n = 8'd0;
    ld_ext_n = 1'b0; ld_hasrm_n = 1'b0; ld_grpd_n = 1'b0; ld_preread_n = 1'b0;
    ld_rm_n = 8'd0; ld_disp_n = 16'd0;
    // F22: the four latches the post-`E` row still reads are reset AFTER it,
    // which is the model's own order.  When the discharge has not happened yet
    // the reset is OWED and the `poste` block pays it.
    if (poste_n) iend_owed_n = 1'b1;
    else begin
        `include "v30u_eu_iend_late.svh"
    end
    ending_n = 1'b0; rowq_n = 2'd0; row_posted_n = 1'b0; row_paired_n = 1'b0;
    rep_chain_n = 1'b0;                    // `begin_sequence()`: rep_elems_ = 0
    // S9b: a form the PRE-DECODE executed (`FA` `FB` `F5` `F8` ... -- no `E`
    // row, so no boundary was taken above) retires at a boundary too, and it
    // is the cold pop that follows.  Everything else has already had its.
    if (!opc_valid_n) begin
        pop_is_first_n = 1'b1;                            // clear_consumed()
        bnd_armed_n = 1'b1;
    end
    st_n = opc_valid_n ? S_TAKE_OPC : S_OPC_POP;
    if (st_n == S_OPC_POP) stop = 1'b1;
