//==========================================================================
//  v30u_eu_arm_tail.svh -- ONE CHAINABLE ARM OF THE MODEL'S STEP,
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
//    exec_impl.h:1629-1634 -- `if (pend_.active) { if (!opr_fresh_) deliver_read(); emit_pending(); }` after the row loop breaks
//==========================================================================
    // ZERO-COST: run_micro's tail -- a staged write still owes the bus data.
    if (pend_active_n) st_n = S_TAIL_W;
    else if (opc_valid_n) st_n = S_INSTR_END;
    else st_n = S_TAIL_POP;
    if (st_n != S_INSTR_END) stop = 1'b1;
