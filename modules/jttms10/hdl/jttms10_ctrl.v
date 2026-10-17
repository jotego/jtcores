/* SPDX-License-Identifier: GPL-3.0-or-later */
module jttms10_ctrl(
    input             rst, clk, enable, ready,
    input      [15:0]  md,
    output            execute, active,
    output            vector, fetch, imm, pcinc, ld_ir, ni, halt,
    output            reg_b, wr_reg, bsrc, a_md, wrsrc, stld, ea_tmp,
    output     [3:0]  a_sel,
    output     [3:0]  alu_sel,
    output     [2:0]  cc_sel,
    output     [2:0]  pc_sel,
    output     [1:0]  mem_sel,
    output     [2:0]  ea_sel
);
    /* verilator lint_off UNUSEDPARAM */
    `include "tms10_param.vh"
    /* verilator lint_on UNUSEDPARAM */
    wire dispatch;
    wire [1:0] jsr_sel;
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
                uaddr <= jsr_ua;
                if(jsr_sel!=RET_JSR) jsr_ret <= uaddr+11'd1;
            end
            if(ni) uaddr <= FETCH_SEQA;
            if(dispatch) uaddr <= entry;
        end
    end
endmodule
