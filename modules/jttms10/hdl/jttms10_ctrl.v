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
    input              pixel_need_dest,
    input              pixel_abort,
    input              array_active, array_fill, array_convert,
    input              array_binary, array_binary_need_read,
    input              array_zero, array_last,
    input              array_checkpoint, reti_pbx,
    input              line_ir, line_checkpoint, line_empty,
                       line_last, line_abort,
    input              array_window_needed, array_window_done,
                       array_window_abort, array_window_query,
                       array_offset_needed, array_corner_next,
                       array_query_mode, array_canon_needed,
    input      [3:0]   array_index,
    input              irq_req, nmi_req, nmi_nostack, halt_req, emu_run, ie,
    output            execute, active,
    output            hw_take, reserved_opcode, push_entry, push_active, emu_step,
    output            vector, fetch, imm, pcinc, ld_ir, ni, halt,
    output            wr_reg, bsrc, wrsrc, stld, wr_sp,
    output            shiftkinit, shiftrinit, shift_step, shift_finish,
    output            setf, exgf, btstfinish, lmoinit, lmoscan, lmofinish,
    output            multiinit, multiadvance, ptrwr, listwr,
    output            mulinit, mulstep, mulcorrq, mulcorrm,
                      mulfinish, mulwrhi, mulwrlo,
    output            divinit, divload, divnega, divnegmd,
                      divnegb, divcheck, divstep,
    output            dsjfinish, xyx, xyy,
    output            array_init, array_cap, array_srcstep,
                      array_dststep, array_count,
                      array_srcpre, array_dstpre,
    output            array_source_phase, array_wb_src,
    output            array_save_active, array_restore_active,
    output            array_rebase_active,
    output     [1:0]  array_rebase_phase,
    output            line_setup_active, line_prep_active,
                      line_loop_active, line_advance_active,
                      line_write_active,
    output     [3:0]  line_phase,
    output            array_offset_active, array_query_active,
                      array_query_first, array_canon_active,
                      array_canon_dst, array_win,
    output            gfx_step, cvloop_active, wincheck_active,
                      pixconv_active,
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
    localparam [11:0] ILLEGAL_SEQA = DIAGFAULT_SEQA;
    wire dispatch;
    wire multiskip;
    wire [1:0] multi_sel;
    wire [3:0] mul_sel;
    wire [1:0] lmo_sel;
    wire [2:0] shift_sel;
    wire [3:0] misc_sel;
    wire [1:0] bus_sel;
    assign fetch = bus_sel==FETCH_BUS;
    assign imm = bus_sel==IMM_BUS;
    assign vector = bus_sel==VECTOR_BUS;
    assign setf = misc_sel==SETF_MISC;
    assign exgf = misc_sel==EXGF_MISC;
    assign btstfinish = misc_sel==BTSTFINISH_MISC;
    assign dsjfinish = misc_sel==DSJ_MISC;
    assign xyx = misc_sel==X_MISC;
    assign xyy = misc_sel==Y_MISC;
    assign emu_step = misc_sel==EMU_MISC;
    assign array_init = misc_sel==ARRAYINIT_MISC;
    assign array_cap = misc_sel==ARRAYCAP_MISC;
    assign array_srcstep = misc_sel==ARRAYSRCSTEP_MISC;
    assign array_dststep = misc_sel==ARRAYDSTSTEP_MISC;
    assign array_count = misc_sel==ARRAYCOUNT_MISC;
    assign array_srcpre = misc_sel==ARRAYSRCPRE_MISC;
    assign array_dstpre = misc_sel==ARRAYDSTPRE_MISC;
    assign array_win = misc_sel==ARRAYWIN_MISC;
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
    assign gfx_step = mul_sel==GFX_MUL;
    wire [3:0] jsr_sel;
    reg cen;
    reg [11:0] jsr_ret2;
    reg [1:0] jsr_depth;
    reg halted, emu_hold;
    // JTFRAME's existing latch_ucode template uses a blocking ROM read.
    /* verilator lint_off BLKSEQ */
    `include "tms10.vh"
    /* verilator lint_on BLKSEQ */

    // cen=0 primes the synchronous ROM; cen=1 executes the latched word.
    // A waiting transaction leaves cen and uaddr unchanged. enable may pause
    // execution independently of the memory response capture in the datapath.
    assign execute = cen && enable && ready && !halt;
    assign active = cen;
    wire boundary = !cen && uaddr==FETCH_SEQA;
    wire array_boundary = !cen && array_checkpoint &&
                          uaddr==ARRAYLOOP_SEQA;
    wire line_boundary = !cen && line_checkpoint &&
                         uaddr==LINELOOP_SEQA;
    assign hw_take = (boundary || array_boundary || line_boundary) && !rst &&
                     !halted && !emu_hold &&
                     (nmi_req || (irq_req && ie));
    assign push_entry = execute && jsr_en && jsr_sel==PUSH32_JSR;
    assign push_active = uaddr[11:4]==PUSH32_SEQA[11:4];
    assign cvloop_active = uaddr[11:4]==CVLOOP_SEQA[11:4];
    assign wincheck_active = uaddr[11:4]==WINCHECK_SEQA[11:4];
    assign pixconv_active = uaddr[11:4]==PIXCONV_SEQA[11:4];
    assign array_source_phase = uaddr[11:4]==ARRAYLOOP_SEQA[11:4];
    assign array_save_active = uaddr[11:4]==ARRAYSAVE_SEQA[11:4];
    assign array_restore_active = uaddr[11:4]==ARRAYRESTORE_SEQA[11:4];
    assign array_rebase_active = uaddr[11:4]==ARRAYREBASE_SEQA[11:4];
    assign array_rebase_phase = uaddr[1:0];
    assign line_setup_active = uaddr[11:4]==LINESETUP_SEQA[11:4];
    assign line_prep_active = uaddr[11:4]==LINEPREP_SEQA[11:4];
    assign line_loop_active = uaddr[11:4]==LINELOOP_SEQA[11:4];
    assign line_advance_active = uaddr[11:4]==LINEADVANCE_SEQA[11:4];
    assign line_write_active = uaddr[11:4]==LINEWRITE_SEQA[11:4];
    assign line_phase = uaddr[3:0];
    assign array_wb_src = uaddr==ARRAYFINISH_SEQA;
    assign array_offset_active =
        uaddr[11:4]==ARRAYOFFSET_SEQA[11:4];
    assign array_query_active =
        array_query_mode && uaddr[11:4]==ARRAYFINISH_SEQA[11:4];
    assign array_query_first = uaddr==ARRAYFINISH_SEQA;
    assign array_canon_active =
        uaddr[11:4]==ARRAYCANON_SEQA[11:4];
    assign array_canon_dst = array_canon_active && uaddr[3:0]>=4'd3;
    // Only the ranges listed as reserved in TI Table 8-6 take ILLOP.
    // Defined opcodes without a microcode implementation remain diagnostic.
    assign reserved_opcode =
        (md[15:8]==8'h02 || md[15:8]==8'h04 ||
         md[15:8]==8'h08 || md[15:8]==8'h0a ||
         md[15:8]==8'h0c || md[15:8]==8'h0e) ||
        (md[15:10]==6'b001101) ||
        (md[15:12]==4'h7) ||
        (md[15:9]==7'b1001111) ||
        (md[15:9]==7'b1011111) ||
        (md[15:11]==5'b11011 && md[10:8]!=3'b111) ||
        (md[15:9]==7'b1111111);
    wire loop_repeat = (shift_step && shift_count>5'd1) ||
                       (gfx_step && cvloop_active && shift_count>5'd1) ||
                       (lmoscan && lmo_more) ||
                       (multiadvance && multi_steps>5'd1) ||
                       (mulstep && mul_count!=5'd1) ||
                       (divstep && mul_count!=5'd1);
    // Dispatch addresses match the six ops' class IDs in ucode/tms10.yaml.
    localparam [11:0] ADDIW_ENTRY = 12'h190,
                      SUBIW_ENTRY = 12'h1a0,
                      CMPIW_ENTRY = 12'h1b0,
                      ADDIL_ENTRY = 12'h1c0,
                      SUBIL_ENTRY = 12'h1d0,
                      CMPIL_ENTRY = 12'h1e0;
    reg [11:0] entry;
    always @* begin
        entry = ILLEGAL_SEQA;
        casez(md)
            16'h0300: entry = NOP_SEQA;
            16'h0320: entry = CLRC_SEQA;
            16'h0de0: entry = SETC_SEQA;
            16'h0360: entry = DINT_SEQA;
            16'h0d60: entry = EINT_SEQA;
            16'h0100: entry = EMU_SEQA;
            16'h0f00,16'h0f20,16'h0f40,16'h0f60,
            16'h0f80,16'h0fa0,16'h0fc0,16'h0fe0:
                entry = ARRAY_SEQA;
            16'hdf1a,16'hdf9a: entry = LINE_SEQA;
            16'b1110011?????????: entry = CPW_SEQA;
            16'b1110100?????????: entry = CVXYL_SEQA;
            16'b1111000?????????: entry = PIXT_RXY_SEQA;
            16'b1111001?????????: entry = PIXT_XYREG_SEQA;
            16'b1111010?????????: entry = PIXT_XYXY_SEQA;
            16'b1111011?????????: entry = DRAV_SEQA;
            16'b1111100?????????: entry = PIXT_RLIN_SEQA;
            16'b1111101?????????: entry = PIXT_LINREG_SEQA;
            16'b1111110?????????: entry = PIXT_LINLIN_SEQA;
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
            16'b00001101100?????: entry = DSJ_SEQA;
            16'b00001101101?????: entry = DSJ_SEQA;
            16'b00001101110?????: entry = DSJ_SEQA;
            16'b00111???????????: entry = DSJS_SEQA;
            16'b1110110?????????: entry = MOVX_SEQA;
            16'b1110111?????????: entry = MOVY_SEQA;
            16'b1110000?????????: entry = ADDXY_SEQA;
            16'b1110001?????????: entry = SUBXY_SEQA;
            16'b1110010?????????: entry = CMPXY_SEQA;
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
        if(reserved_opcode) entry = HWSAVE_SEQA;
    end

    always @(posedge clk) begin
        if(rst) begin
            cen <= 0;
            uaddr <= RESET_SEQA;
            jsr_ret <= 0;
            jsr_ret2 <= 0;
            jsr_depth <= 0;
            halted <= 0;
            emu_hold <= 0;
        end else if(!cen) begin
            // Host-present reset holds before the first vector fetch until
            // the host releases HLT (TI section 8.8).
            if(uaddr==RESET_SEQA && halt_req) begin
                cen <= 0;
            end else if(boundary && halted) begin
                if(!halt_req && !emu_hold) halted <= 0;
            end else if(boundary && emu_hold) begin
                if(emu_run) emu_hold <= 0;
            end else if(hw_take) begin
                uaddr <= nmi_req && nmi_nostack ? HWNOSAVE_SEQA :
                         array_boundary ? ARRAYSAVE_SEQA : HWSAVE_SEQA;
            end else if(boundary && halt_req) begin
                halted <= 1;
            end else begin
                cen <= 1;
            end
        end else if(execute) begin
            cen <= 0;
            if(emu_step && !emu_run) emu_hold <= 1;
            uaddr[3:0] <= uaddr[3:0]+1'b1;
            if(jsr_en) begin
                // Zero-count shifts skip the helper while retaining C=0.
                if((jsr_sel==SHIFTLOOP_JSR && shift_count==0) ||
                   (jsr_sel==CVLOOP_JSR && shift_count==0) ||
                   (jsr_sel==PIXCONV_JSR && array_active && !array_convert) ||
                   (jsr_sel==PIXDSTREAD_JSR && !pixel_need_dest) ||
                   (jsr_sel==LMOLOOP_JSR && !lmo_more))
                    uaddr <= uaddr+12'd1;
                else begin
                    uaddr <= jsr_ua;
                    if(jsr_sel==RET_JSR) begin
                        uaddr <= jsr_depth==2 ? jsr_ret2 : jsr_ret;
                        if(!loop_repeat && jsr_depth!=0)
                            jsr_depth <= jsr_depth-2'd1;
                    end else if(jsr_depth==0) begin
                        jsr_ret <= uaddr+12'd1;
                        jsr_depth <= 1;
                    end else begin
                        jsr_ret2 <= uaddr+12'd1;
                        jsr_depth <= 2;
                    end
                end
            end
            // The helper's RET_JSR returns on its final one-bit shift.
            if(shift_step && shift_count>5'd1) uaddr <= SHIFTLOOP_SEQA;
            if(gfx_step && cvloop_active && shift_count>5'd1)
                uaddr <= CVLOOP_SEQA;
            // PIXT W1 and clipped W2/W3 leave before the source MTR.
            if(gfx_step && wincheck_active && jsr_sel==RET_JSR &&
               pixel_abort) uaddr <= PIXEND_SEQA;
            if(array_init) uaddr <= line_ir ? LINESETUP_SEQA :
                                  ARRAYSETUP_SEQA;
            if(array_cap && line_setup_active)
                uaddr <= array_index==4'd6 ?
                         (line_empty ? PIXEND_SEQA : LINEPREP_SEQA) :
                         LINESETUP_SEQA;
            if(array_cap && !line_setup_active && !array_restore_active)
                uaddr <= array_index==4'd9 ?
                    (array_zero ? PIXEND_SEQA :
                     array_window_needed ? ARRAYWINDOW_SEQA :
                     ARRAYPREP_SEQA) :
                    ARRAYSETUP_SEQA;
            if(array_win && !line_prep_active &&
               !line_advance_active && !array_canon_active &&
               !array_rebase_active && array_window_done)
                uaddr <= array_window_query ? ARRAYFINISH_SEQA :
                         array_window_abort ? PIXEND_SEQA :
                         array_corner_next ? ARRAYWINDOW_SEQA :
                         array_offset_needed ? ARRAYOFFSET_SEQA :
                         ARRAYPREP_SEQA;
            if(array_win && !line_prep_active &&
               !line_advance_active && !array_canon_active &&
               !array_rebase_active && !array_window_done)
                uaddr <= ARRAYWINDOW_SEQA;
            if(array_active && array_offset_active &&
               a_sel==SAVESRC_A) uaddr <= ARRAYPREP_SEQA;
            if(array_active && array_binary && array_source_phase &&
               array_srcpre && !array_binary_need_read)
                uaddr <= ARRAYBIT_SEQA;
            if(array_active && array_canon_active &&
               a_sel==SAVEDST_A) uaddr <= ARRAYFINISH_SEQA;
            if(array_active && !array_canon_active &&
               a_sel==SAVEDST_A)
                uaddr <= ARRAYLOOP_SEQA;
            if(array_active && cc_sel==SRCADDR_CC && array_fill)
                uaddr <= ARRAYDST_SEQA;
            if(array_active && a_sel==SRCCAP_A)
                uaddr <= ARRAYDST_SEQA;
            if(array_count)
                uaddr <= array_last ?
                    (array_canon_needed ? ARRAYCANON_SEQA :
                     ARRAYFINISH_SEQA) : ARRAYLOOP_SEQA;
            if(array_save_active && listwr)
                uaddr <= array_index==4'd6 ? HWSAVE_SEQA :
                         ARRAYSAVE_SEQA;
            if(array_restore_active && array_cap)
                uaddr <= array_index==4'd10 ? ARRAYREBASE_SEQA :
                         ARRAYRESTORE_SEQA;
            if(array_rebase_active && array_win &&
               array_rebase_phase==2'd2)
                uaddr <= ARRAYLOOP_SEQA;
            if(line_prep_active && array_win && line_phase==4'd1)
                uaddr <= LINELOOP_SEQA;
            if(line_loop_active && mem_sel==WRITE_MEM)
                uaddr <= LINEADVANCE_SEQA;
            if(line_advance_active && array_win && line_phase==4'd3)
                uaddr <= LINEWRITE_SEQA;
            if(line_write_active && listwr && line_phase==4'd2)
                uaddr <= line_last || line_abort ? PIXEND_SEQA :
                         LINELOOP_SEQA;
            if(lmoscan && lmo_more) uaddr <= LMOLOOP_SEQA;
            if(multiskip && !multi_bit) uaddr <= MULTINEXT_SEQA;
            if(multiadvance && multi_steps>5'd1)
                uaddr <= multi_load ? MMFMLOOP_SEQA : MMTMLOOP_SEQA;
            if(mulstep && mul_count!=5'd1) uaddr <= MULLOOP_SEQA;
            if(divcheck && div_early_cond) uaddr <= DIVFAIL_SEQA;
            if(divstep && mul_count!=5'd1) uaddr <= DIVLOOP_SEQA;
            if(ni) begin
                uaddr <= reti_pbx ? ARRAYRESTORE_SEQA : FETCH_SEQA;
                jsr_depth <= 0;
            end
            if(dispatch) begin
                uaddr <= entry;
                jsr_depth <= 0;
            end
        end
    end
endmodule
