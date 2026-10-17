/* SPDX-License-Identifier: GPL-3.0-or-later */
module jttms10_ctrl(
    input             rst, clk, enable, ready,
    input      [15:0]  md,
    input      [4:0]   shift_count,
    input              lmo_more,
    input              multi_bit,
    input      [4:0]   multi_steps,
    input              multi_load,
    input      [4:0]   mul_count,
    input              div_early_cond,
    output            execute, active,
    output            vector, fetch, imm, pcinc, ld_ir, ni, halt,
    output            wr_reg, bsrc, wrsrc, stld, wr_sp,
    output            shiftkinit, shiftrinit, shift_step, shift_finish,
    output            setf, exgf, btstfinish, lmoinit, lmoscan, lmofinish,
    output            multiinit, multiadvance, ptrwr, listwr,
    output            mulinit, mulstep, mulcorrq, mulcorrm,
                      mulfinish, mulwrhi, mulwrlo,
    output            divinit, divload, divnega, divnegmd,
                      divnegb, divcheck, divstep,
    output     [4:0]  a_sel,
    output     [3:0]  alu_sel,
    output     [1:0]  b_sel, md_sel, stack_sel, tmp_sel, st_sel,
    output     [3:0]  cc_sel,
    output     [2:0]  pc_sel,
    output     [1:0]  mem_sel,
    output     [2:0]  ea_sel
);
    /* verilator lint_off UNUSEDPARAM */
    `include "tms10_param.vh"
    /* verilator lint_on UNUSEDPARAM */
    wire dispatch;
    wire multiskip;
    wire [1:0] multi_sel;
    wire [3:0] mul_sel;
    wire [1:0] lmo_sel;
    wire [2:0] shift_sel;
    wire [1:0] misc_sel;
    assign setf = misc_sel==SETF_MISC;
    assign exgf = misc_sel==EXGF_MISC;
    assign btstfinish = misc_sel==BTSTFINISH_MISC;
    assign shiftkinit = shift_sel==KINIT_SHIFT;
    assign shiftrinit = shift_sel==RINIT_SHIFT;
    assign shift_step = shift_sel==STEP_SHIFT;
    assign shift_finish = shift_sel==FINISH_SHIFT;
    assign lmoinit = lmo_sel==INIT_LMO;
    assign lmoscan = lmo_sel==SCAN_LMO;
    assign lmofinish = lmo_sel==FINISH_LMO;
    assign multiinit = multi_sel==INIT_MULTI;
    assign multiskip = multi_sel==SKIP_MULTI;
    assign multiadvance = multi_sel==ADVANCE_MULTI;
    assign mulinit = mul_sel==INIT_MUL;
    assign mulstep = mul_sel==STEP_MUL;
    assign mulcorrq = mul_sel==CORRQ_MUL;
    assign mulcorrm = mul_sel==CORRM_MUL;
    assign mulfinish = mul_sel==FINISH_MUL;
    assign mulwrhi = mul_sel==WRHI_MUL;
    assign mulwrlo = mul_sel==WRLO_MUL;
    assign divinit = mul_sel==INITDIV_MUL;
    assign divload = mul_sel==LOADDIV_MUL;
    assign divnega = mul_sel==NEGDIV_MUL;
    assign divnegmd = mul_sel==NEGMD_MUL;
    assign divnegb = mul_sel==NEGB_MUL;
    assign divcheck = mul_sel==CHECKDIV_MUL;
    assign divstep = mul_sel==STEPDIV_MUL;
    wire [3:0] jsr_sel;
    reg cen;
    // JTFRAME's existing latch_ucode template uses a blocking ROM read.
    /* verilator lint_off BLKSEQ */
    `include "tms10.vh"
    /* verilator lint_on BLKSEQ */

    // cen=0 primes the synchronous ROM; cen=1 executes the latched word.
    // A waiting transaction leaves cen and uaddr unchanged. enable may pause
    // execution independently of the memory response capture in the datapath.
    assign execute = cen && enable && ready && !halt;
    assign active = cen;
    // Dispatch addresses match the six ops' class IDs in ucode/tms10.yaml.
    localparam [10:0] ADDIW_ENTRY = 11'h190,
                      SUBIW_ENTRY = 11'h1a0,
                      CMPIW_ENTRY = 11'h1b0,
                      ADDIL_ENTRY = 11'h1c0,
                      SUBIL_ENTRY = 11'h1d0,
                      CMPIL_ENTRY = 11'h1e0;
    reg [10:0] entry;
    always @* begin
        entry = 11'h7f0;
        casez(md)
            16'h0300: entry = NOP_SEQA;
            16'h0320: entry = CLRC_SEQA;
            16'h0de0: entry = SETC_SEQA;
            16'h0360: entry = DINT_SEQA;
            16'h0d60: entry = EINT_SEQA;
            16'b00000011100?????: entry = ABS_SEQA;
            16'b00000011101?????: entry = NEG_SEQA;
            16'b00000011110?????: entry = NEGB_SEQA;
            16'b00000011111?????: entry = NOT_SEQA;
            16'b00001011100?????: entry = ANDI_SEQA;
            16'b00001011101?????: entry = ORI_SEQA;
            16'b00001011110?????: entry = XORI_SEQA;
            16'b001000??????????,
            16'b001001??????????,
            16'b001010??????????,
            16'b001011??????????,
            16'b001100??????????: entry = SHIFTK_SEQA;
            16'b0110000?????????,
            16'b0110001?????????,
            16'b0110010?????????,
            16'b0110011?????????,
            16'b0110100?????????: entry = SHIFTR_SEQA;
            16'b000001?101??????: entry = SETF_SEQA;
            16'b000001?1000?????: entry = SEXT_SEQA;
            16'b000001?1001?????: entry = ZEXT_SEQA;
            16'b110101?1000?????: entry = EXGF_SEQA;
            16'b000111??????????,
            16'b0100101?????????: entry = BTST_SEQA;
            16'b0110101?????????: entry = LMO_SEQA;
            16'b00001001100?????: entry = MMTM_SEQA;
            16'b00001001101?????: entry = MMFM_SEQA;
            16'b010111??????????: entry = MPY_SEQA;
            16'b010110??????????,
            16'b011011??????????: entry = DIV_SEQA;
            16'h01e0: entry = PUSHST_SEQA;
            16'h01c0: entry = POPST_SEQA;
            16'h0d5f: entry = CALLA_SEQA;
            16'h0d3f: entry = CALLR_SEQA;
            16'h0940: entry = RETI_SEQA;
            16'b00001001001?????: entry = CALLRS_SEQA;
            16'b00001001011?????: entry = RETS_SEQA;
            16'b00001001000?????: entry = md[4:0]==0 ? TRAP0_SEQA : TRAP_SEQA;
            16'b000110??????????: entry = MOVK_SEQA;
            16'b000100??????????: entry = ADDK_SEQA;
            16'b000101??????????: entry = SUBK_SEQA;
            16'b00001001110?????: entry = MOVIW_SEQA;
            16'b00001001111?????: entry = MOVIL_SEQA;
            16'b00001011000?????: entry = ADDIW_ENTRY;
            16'b00001011111?????: entry = SUBIW_ENTRY;
            16'b00001011010?????: entry = CMPIW_ENTRY;
            16'b00001011001?????: entry = ADDIL_ENTRY;
            16'b00001101000?????: entry = SUBIL_ENTRY;
            16'b00001011011?????: entry = CMPIL_ENTRY;
            16'b010011??????????: entry = MOVE_SEQA;
            16'b0100000?????????: entry = ADD_SEQA;
            16'b0100001?????????: entry = ADDC_SEQA;
            16'b0100010?????????: entry = SUB_SEQA;
            16'b0100011?????????: entry = SUBB_SEQA;
            16'b0100100?????????: entry = CMP_SEQA;
            16'b0101000?????????: entry = AND_SEQA;
            16'b0101001?????????: entry = ANDN_SEQA;
            16'b0101010?????????: entry = OR_SEQA;
            16'b0101011?????????: entry = XOR_SEQA;
            16'b00000001011?????: entry = JUMP_SEQA;
            16'b00000001010?????: entry = GETPC_SEQA;
            16'b00000001001?????: entry = EXGPC_SEQA;
            16'b00000000001?????: entry = REV_SEQA;
            16'b00000001100?????: entry = GETST_SEQA;
            16'b00000001101?????: entry = PUTST_SEQA;
            16'b100000??????????: entry = STORE_SEQA;
            16'b100001??????????: entry = LOAD_SEQA;
            16'b100100??????????: entry = STOREPI_SEQA;
            16'b100101??????????: entry = LOADPI_SEQA;
            16'b101000??????????: entry = STOREPD_SEQA;
            16'b101001??????????: entry = LOADPD_SEQA;
            16'b101100??????????: entry = STOREOFF_SEQA;
            16'b101101??????????: entry = LOADOFF_SEQA;
            16'b000001?1100?????: entry = STOREABS_SEQA;
            16'b000001?1101?????: entry = LOADABS_SEQA;
            16'b1000110?????????: entry = STORE_SEQA;    // MOVB
            16'b1000111?????????: entry = LOAD_SEQA;
            16'b1010110?????????: entry = STOREOFF_SEQA;
            16'b1010111?????????: entry = LOADOFF_SEQA;
            16'b00000101111?????: entry = STOREABS_SEQA;
            16'b00000111111?????: entry = LOADABS_SEQA;
            16'b100010??????????: entry = MOVEIND_SEQA;
            16'b100110??????????: entry = MOVEPI_SEQA;
            16'b101010??????????: entry = MOVEPD_SEQA;
            16'b101110??????????: entry = MOVEOFF_SEQA;
            16'b110100??????????: entry = MOVEOFFPI_SEQA;
            16'b110101?0000?????: entry = MOVEABSPI_SEQA;
            16'b000001?111000000: entry = MOVEABS_SEQA;
            16'b1001110?????????: entry = MOVEIND_SEQA; // MOVB
            16'b1011110?????????: entry = MOVEOFF_SEQA;
            16'h0340: entry = MOVEABS_SEQA;
            16'b1100????????????: begin
                if(md[7:0]==8'h00) entry = JRL_SEQA;
                else if(md[7:0]==8'h80) entry = JACC_SEQA;
                else entry = JR_SEQA;
            end
            default:;
        endcase
    end

    always @(posedge clk) begin
        if(rst) begin
            cen <= 0;
            uaddr <= RESET_SEQA;
            jsr_ret <= 0;
        end else if(!cen) begin
            cen <= 1;
        end else if(execute) begin
            cen <= 0;
            uaddr[3:0] <= uaddr[3:0]+1'b1;
            if(jsr_en) begin
                // Zero-count shifts skip the helper while retaining C=0.
                if((jsr_sel==SHIFTLOOP_JSR && shift_count==0) ||
                   (jsr_sel==LMOLOOP_JSR && !lmo_more))
                    uaddr <= uaddr+11'd1;
                else begin
                    uaddr <= jsr_ua;
                    if(jsr_sel!=RET_JSR) jsr_ret <= uaddr+11'd1;
                end
            end
            // The helper's RET_JSR returns on its final one-bit shift.
            if(shift_step && shift_count>5'd1) uaddr <= SHIFTLOOP_SEQA;
            if(lmoscan && lmo_more) uaddr <= LMOLOOP_SEQA;
            if(multiskip && !multi_bit) uaddr <= MULTINEXT_SEQA;
            if(multiadvance && multi_steps>5'd1)
                uaddr <= multi_load ? MMFMLOOP_SEQA : MMTMLOOP_SEQA;
            if(mulstep && mul_count!=5'd1) uaddr <= MULLOOP_SEQA;
            if(divcheck && div_early_cond) uaddr <= DIVFAIL_SEQA;
            if(divstep && mul_count!=5'd1) uaddr <= DIVLOOP_SEQA;
            if(ni) uaddr <= FETCH_SEQA;
            if(dispatch) uaddr <= entry;
        end
    end
endmodule
