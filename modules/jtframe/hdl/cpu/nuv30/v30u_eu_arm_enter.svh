//==========================================================================
//  v30u_eu_arm_enter.svh -- ONE CHAINABLE ARM OF THE MODEL'S STEP,
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
//    loader_impl.h:512-515 / exec_impl.h:1185-1188 -- `out.entry = {page, opc, 0}` and `run_micro`'s prologue
//==========================================================================
    // ZERO-COST: micro-row 0 opens on the clock the caller handed over
    upc_page_n = ld_page_n;
    upc_opc_n  = opc_reg_n;
    upc_loc_n  = 4'd0;
    ending_n = 1'b0; rowq_n = 2'd0; row_posted_n = 1'b0; row_paired_n = 1'b0;
    suppress_commit_n = 1'b0;
    st_n = S_ROW;
    stop = 1'b1;
