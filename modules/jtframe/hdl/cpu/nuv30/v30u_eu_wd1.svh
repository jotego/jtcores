//============================================================================
//  v30u_eu_wd1.svh -- exec_impl.h::wr_dst1(c, v1, bsrc1, wbyte), verbatim.
//  Inputs: `e_d1` (the row's Dest1 field), `v1`, `bsw` (the byte-SOURCE flag,
//  i.e. lane replication) and `wb1` (the DATUM WIDTH tag -- see the Source1
//  classification in v30u_eu.sv; the two are different properties).
//============================================================================
case (e_d1)
    5'd0, 5'd1, 5'd2, 5'd3: sreg_n[e_d1[1:0]] = v1;
    5'd4:  pc_n = v1;
    5'd5:  ind_n = v1;
    5'd6:  begin opr_n = v1; opr_byte_n = wb1;
                 opr_fresh_n = 1'b1; opr_loaded_n = 1'b1; end
    5'd7:  ;                                        // NULL
    5'd8:  gpr_n[R_AW][7:0] = v1[7:0];                // AL
    5'd12: begin tmpa_n = v1; tmpa_byte_n = wb1; end
    5'd13: begin tmpb_n = v1; tmpb_byte_n = wb1; end
    5'd14: begin tmpc_n = v1; tmpc_byte_n = wb1; end
    5'd15: psw_n = (v1 & PSW_WRITABLE) | PSW_FORCED;
    5'd16: gpr_n[R_AW][15:8] = v1[7:0];               // AH
    5'd17: count_n = v1;
    5'd18: begin                                    // wr_operand(R, v)
        case (r_kind_n)
            OK_REG:  if (r_byte_n) begin
                         if (r_idx_n[2]) gpr_n[r_idx_n[1:0]][15:8] = v1[7:0];
                         else          gpr_n[r_idx_n[1:0]][7:0]  = v1[7:0];
                     end else gpr_n[r_idx_n] = v1;
            OK_SREG: sreg_n[r_idx_n[1:0]] = v1;
            // `wr_operand`'s OPR tag is the OPERAND REF's OWN width, not the
            // source's: this rail is going back out to memory as an operand.
            OK_MEM:  begin opr_n = v1; opr_byte_n = r_byte_n;
                           opr_fresh_n = 1'b1; opr_loaded_n = 1'b1; end
            default: ;
        endcase
    end
    5'd19: begin                                    // wr_operand(M, v)
        case (m_kind_n)
            OK_REG:  if (m_byte_n) begin
                         if (m_idx_n[2]) gpr_n[m_idx_n[1:0]][15:8] = v1[7:0];
                         else          gpr_n[m_idx_n[1:0]][7:0]  = v1[7:0];
                     end else gpr_n[m_idx_n] = v1;
            OK_SREG: sreg_n[m_idx_n[1:0]] = v1;
            OK_MEM:  begin opr_n = v1; opr_byte_n = m_byte_n;
                           opr_fresh_n = 1'b1; opr_loaded_n = 1'b1; end
            default: ;
        endcase
    end
    // tmpaL zero-extends, tmpbL SIGN-extends (ledger, "L-half writes").
    // BOTH CLEAR THE TAG.  AN EXTENDER IS A WIDENER: it drives the high half
    // ITSELF, with zero or with the sign, and either way that half is a
    // correct part of the 16-bit value.  Nothing foreign survives there, so
    // what comes out is a WORD.  This is why `83` and `6B` -- word operations
    // whose sign-extended byte immediate never reaches an H-half write -- come
    // out at word width, and why the `0F 31/39` bit-field block, which carries
    // its 4-bit offsets through tmpaL, stays at word width like the rest of a
    // word instruction.  The L-half ASYMMETRY IS THE WIDTH.
    5'd20: begin tmpa_n = {8'd0, v1[7:0]};          tmpa_byte_n = 1'b0; end
    5'd21: begin tmpb_n = {{8{v1[7]}}, v1[7:0]};    tmpb_byte_n = 1'b0; end
    // the H-half write takes bus bits 15:8; a byte source presents its byte
    // there.  AN H-HALF WRITE COMPLETES A 16-BIT DATUM, so it clears the tag
    // too -- and that is how the ROM builds a word immediate and how the ALU
    // learns the width without being told: 003C `Q -> tmpbL` / `JMP OP8 2` /
    // 003D `Q -> tmpbH`, where the L-only path leaves a BYTE and the L+H path
    // a WORD.
    5'd22: begin tmpa_n[15:8] = bsw ? v1[7:0] : v1[15:8]; tmpa_byte_n = 1'b0; end
    5'd23: begin tmpb_n[15:8] = bsw ? v1[7:0] : v1[15:8]; tmpb_byte_n = 1'b0; end
    default: if (e_d1 >= 5'd24) gpr_n[e_d1[2:0]] = v1;
endcase
