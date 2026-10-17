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
    output            array_pitch_src, array_pitch_dst,
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
    // B1/B3 are immutable through a row; preselect them for the RF's
    // synchronous read before the source/destination row-step executes.
    assign array_pitch_src = uaddr==ARRAYDST_SEQA+12'd5;
    assign array_pitch_dst = uaddr==ARRAYDST_SEQA+12'd6;
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
    // This classification is also used when elaborating the dispatch ROM.
    function automatic is_reserved(input [7:0] opcode_hi);
        begin
            is_reserved =
        (opcode_hi[7:0]==8'h02 || opcode_hi[7:0]==8'h04 ||
         opcode_hi[7:0]==8'h08 || opcode_hi[7:0]==8'h0a ||
         opcode_hi[7:0]==8'h0c || opcode_hi[7:0]==8'h0e) ||
        (opcode_hi[7:2]==6'b001101) ||
        (opcode_hi[7:4]==4'h7) ||
        (opcode_hi[7:1]==7'b1001111) ||
        (opcode_hi[7:1]==7'b1011111) ||
        (opcode_hi[7:3]==5'b11011 && opcode_hi[2:0]!=3'b111) ||
        (opcode_hi[7:1]==7'b1111111);
        end
    endfunction
    assign reserved_opcode = is_reserved(md[15:8]);
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
    // All dispatch targets are 16-microstep aligned. Every group of 32
    // opcodes has one common family; the sparse low-five-bit exceptions are
    // below. The coarse ROM is sampled in the fetch prime cycle.
    function automatic [7:0] decode_family(input [15:0] opcode);
        reg [7:0] decoded;
        begin
        decoded = ILLEGAL_SEQA[11:4];
        casez(opcode)
            16'h0300: decoded = NOP_SEQA[11:4];
            16'h0320: decoded = CLRC_SEQA[11:4];
            16'h0de0: decoded = SETC_SEQA[11:4];
            16'h0360: decoded = DINT_SEQA[11:4];
            16'h0d60: decoded = EINT_SEQA[11:4];
            16'h0100: decoded = EMU_SEQA[11:4];
            16'h0f00,16'h0f20,16'h0f40,16'h0f60,
            16'h0f80,16'h0fa0,16'h0fc0,16'h0fe0:
                decoded = ARRAY_SEQA[11:4];
            16'hdf1a,16'hdf9a: decoded = LINE_SEQA[11:4];
            16'b1110011?????????: decoded = CPW_SEQA[11:4];
            16'b1110100?????????: decoded = CVXYL_SEQA[11:4];
            16'b1111000?????????: decoded = PIXT_RXY_SEQA[11:4];
            16'b1111001?????????: decoded = PIXT_XYREG_SEQA[11:4];
            16'b1111010?????????: decoded = PIXT_XYXY_SEQA[11:4];
            16'b1111011?????????: decoded = DRAV_SEQA[11:4];
            16'b1111100?????????: decoded = PIXT_RLIN_SEQA[11:4];
            16'b1111101?????????: decoded = PIXT_LINREG_SEQA[11:4];
            16'b1111110?????????: decoded = PIXT_LINLIN_SEQA[11:4];
            16'b00000011100?????: decoded = ABS_SEQA[11:4];
            16'b00000011101?????: decoded = NEG_SEQA[11:4];
            16'b00000011110?????: decoded = NEGB_SEQA[11:4];
            16'b00000011111?????: decoded = NOT_SEQA[11:4];
            16'b00001011100?????: decoded = ANDI_SEQA[11:4];
            16'b00001011101?????: decoded = ORI_SEQA[11:4];
            16'b00001011110?????: decoded = XORI_SEQA[11:4];
            16'b001000??????????,
            16'b001001??????????,
            16'b001010??????????,
            16'b001011??????????,
            16'b001100??????????: decoded = SHIFTK_SEQA[11:4];
            16'b0110000?????????,
            16'b0110001?????????,
            16'b0110010?????????,
            16'b0110011?????????,
            16'b0110100?????????: decoded = SHIFTR_SEQA[11:4];
            16'b000001?101??????: decoded = SETF_SEQA[11:4];
            16'b000001?1000?????: decoded = SEXT_SEQA[11:4];
            16'b000001?1001?????: decoded = ZEXT_SEQA[11:4];
            16'b110101?1000?????: decoded = EXGF_SEQA[11:4];
            16'b000111??????????,
            16'b0100101?????????: decoded = BTST_SEQA[11:4];
            16'b0110101?????????: decoded = LMO_SEQA[11:4];
            16'b00001001100?????: decoded = MMTM_SEQA[11:4];
            16'b00001001101?????: decoded = MMFM_SEQA[11:4];
            16'b010111??????????: decoded = MPY_SEQA[11:4];
            16'b010110??????????,
            16'b011011??????????: decoded = DIV_SEQA[11:4];
            16'b00001101100?????: decoded = DSJ_SEQA[11:4];
            16'b00001101101?????: decoded = DSJ_SEQA[11:4];
            16'b00001101110?????: decoded = DSJ_SEQA[11:4];
            16'b00111???????????: decoded = DSJS_SEQA[11:4];
            16'b1110110?????????: decoded = MOVX_SEQA[11:4];
            16'b1110111?????????: decoded = MOVY_SEQA[11:4];
            16'b1110000?????????: decoded = ADDXY_SEQA[11:4];
            16'b1110001?????????: decoded = SUBXY_SEQA[11:4];
            16'b1110010?????????: decoded = CMPXY_SEQA[11:4];
            16'h01e0: decoded = PUSHST_SEQA[11:4];
            16'h01c0: decoded = POPST_SEQA[11:4];
            16'h0d5f: decoded = CALLA_SEQA[11:4];
            16'h0d3f: decoded = CALLR_SEQA[11:4];
            16'h0940: decoded = RETI_SEQA[11:4];
            16'b00001001001?????: decoded = CALLRS_SEQA[11:4];
            16'b00001001011?????: decoded = RETS_SEQA[11:4];
            16'b00001001000?????: decoded = opcode[4:0]==0 ? TRAP0_SEQA[11:4] : TRAP_SEQA[11:4];
            16'b000110??????????: decoded = MOVK_SEQA[11:4];
            16'b000100??????????: decoded = ADDK_SEQA[11:4];
            16'b000101??????????: decoded = SUBK_SEQA[11:4];
            16'b00001001110?????: decoded = MOVIW_SEQA[11:4];
            16'b00001001111?????: decoded = MOVIL_SEQA[11:4];
            16'b00001011000?????: decoded = ADDIW_ENTRY[11:4];
            16'b00001011111?????: decoded = SUBIW_ENTRY[11:4];
            16'b00001011010?????: decoded = CMPIW_ENTRY[11:4];
            16'b00001011001?????: decoded = ADDIL_ENTRY[11:4];
            16'b00001101000?????: decoded = SUBIL_ENTRY[11:4];
            16'b00001011011?????: decoded = CMPIL_ENTRY[11:4];
            16'b010011??????????: decoded = MOVE_SEQA[11:4];
            16'b0100000?????????: decoded = ADD_SEQA[11:4];
            16'b0100001?????????: decoded = ADDC_SEQA[11:4];
            16'b0100010?????????: decoded = SUB_SEQA[11:4];
            16'b0100011?????????: decoded = SUBB_SEQA[11:4];
            16'b0100100?????????: decoded = CMP_SEQA[11:4];
            16'b0101000?????????: decoded = AND_SEQA[11:4];
            16'b0101001?????????: decoded = ANDN_SEQA[11:4];
            16'b0101010?????????: decoded = OR_SEQA[11:4];
            16'b0101011?????????: decoded = XOR_SEQA[11:4];
            16'b00000001011?????: decoded = JUMP_SEQA[11:4];
            16'b00000001010?????: decoded = GETPC_SEQA[11:4];
            16'b00000001001?????: decoded = EXGPC_SEQA[11:4];
            16'b00000000001?????: decoded = REV_SEQA[11:4];
            16'b00000001100?????: decoded = GETST_SEQA[11:4];
            16'b00000001101?????: decoded = PUTST_SEQA[11:4];
            16'b100000??????????: decoded = STORE_SEQA[11:4];
            16'b100001??????????: decoded = LOAD_SEQA[11:4];
            16'b100100??????????: decoded = STOREPI_SEQA[11:4];
            16'b100101??????????: decoded = LOADPI_SEQA[11:4];
            16'b101000??????????: decoded = STOREPD_SEQA[11:4];
            16'b101001??????????: decoded = LOADPD_SEQA[11:4];
            16'b101100??????????: decoded = STOREOFF_SEQA[11:4];
            16'b101101??????????: decoded = LOADOFF_SEQA[11:4];
            16'b000001?1100?????: decoded = STOREABS_SEQA[11:4];
            16'b000001?1101?????: decoded = LOADABS_SEQA[11:4];
            16'b1000110?????????: decoded = STORE_SEQA[11:4];    // MOVB
            16'b1000111?????????: decoded = LOAD_SEQA[11:4];
            16'b1010110?????????: decoded = STOREOFF_SEQA[11:4];
            16'b1010111?????????: decoded = LOADOFF_SEQA[11:4];
            16'b00000101111?????: decoded = STOREABS_SEQA[11:4];
            16'b00000111111?????: decoded = LOADABS_SEQA[11:4];
            16'b100010??????????: decoded = MOVEIND_SEQA[11:4];
            16'b100110??????????: decoded = MOVEPI_SEQA[11:4];
            16'b101010??????????: decoded = MOVEPD_SEQA[11:4];
            16'b101110??????????: decoded = MOVEOFF_SEQA[11:4];
            16'b110100??????????: decoded = MOVEOFFPI_SEQA[11:4];
            16'b110101?0000?????: decoded = MOVEABSPI_SEQA[11:4];
            16'b000001?111000000: decoded = MOVEABS_SEQA[11:4];
            16'b1001110?????????: decoded = MOVEIND_SEQA[11:4]; // MOVB
            16'b1011110?????????: decoded = MOVEOFF_SEQA[11:4];
            16'h0340: decoded = MOVEABS_SEQA[11:4];
            16'b1100????????????: begin
                if(opcode[7:0]==8'h00) decoded = JRL_SEQA[11:4];
                else if(opcode[7:0]==8'h80) decoded = JACC_SEQA[11:4];
                else decoded = JR_SEQA[11:4];
            end
            default:;
        endcase
        if(is_reserved(opcode[15:8])) decoded = HWSAVE_SEQA[11:4];
            decode_family = decoded;
        end
    endfunction
    (* ramstyle = "M10K" *) reg [7:0] dispatch_rom [0:2047];
`ifndef TMS10_DISPATCH_GENERATE
`ifdef __ICARUS__
    integer dispatch_init_i;
    initial begin
        for(dispatch_init_i=0;dispatch_init_i<2048;
            dispatch_init_i=dispatch_init_i+1)
            dispatch_rom[dispatch_init_i]=
                decode_family({dispatch_init_i[10:0],5'b00001});
    end
`elsif VERILATOR
    integer dispatch_init_i;
    initial begin
        for(dispatch_init_i=0;dispatch_init_i<2048;
            dispatch_init_i=dispatch_init_i+1)
            dispatch_rom[dispatch_init_i]=
                decode_family({dispatch_init_i[10:0],5'b00001});
    end
`else
    initial $readmemh("tms10_dispatch.hex", dispatch_rom);
`endif
`endif
    reg [7:0] entry_family_q;
    always @(posedge clk) entry_family_q <= dispatch_rom[md[15:5]];
    reg [7:0] entry_family;
    always @* begin
        entry_family = entry_family_q;
        casez(md)
            16'h0100: entry_family = EMU_SEQA[11:4];
            16'h01c0: entry_family = POPST_SEQA[11:4];
            16'h01e0: entry_family = PUSHST_SEQA[11:4];
            16'h0300: entry_family = NOP_SEQA[11:4];
            16'h0320: entry_family = CLRC_SEQA[11:4];
            16'h0340,16'h05c0,16'h07c0:
                entry_family = MOVEABS_SEQA[11:4];
            16'h0360: entry_family = DINT_SEQA[11:4];
            16'h0900: entry_family = TRAP0_SEQA[11:4];
            16'h0940: entry_family = RETI_SEQA[11:4];
            16'h0d3f: entry_family = CALLR_SEQA[11:4];
            16'h0d5f: entry_family = CALLA_SEQA[11:4];
            16'h0d60: entry_family = EINT_SEQA[11:4];
            16'h0de0: entry_family = SETC_SEQA[11:4];
            16'b00001111???00000: entry_family = ARRAY_SEQA[11:4];
            16'b1100????00000000: entry_family = JRL_SEQA[11:4];
            16'b1100????10000000: entry_family = JACC_SEQA[11:4];
            16'b11011111?0011010: entry_family = LINE_SEQA[11:4];
            default:;
        endcase
    end
    wire [11:0] entry = {entry_family,4'b0};

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
            // Repeat the single ARRAYWINDOW microstep without traversing its
            // otherwise empty 16-word class between window phases.
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
