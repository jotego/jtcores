//==========================================================================
//  v30u_eu_arm_take_opc.svh -- ONE CHAINABLE ARM OF THE MODEL'S STEP,
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
//    loader_impl.h:240-245 -- `pop_opcode()`'s `bool pre = biu.opcode_pending(); ... if (!pre) biu.charge(1);`: when `pre` is true there is NO charge
//==========================================================================
    // ZERO-COST: the successor's opcode was pre-popped on the E row's clock.
    ld_b_n = opc_byte_n;
    opc_valid_n = 1'b0;
    pc_n = pc_n + 16'd1;
    st_n = S_DECODE;
