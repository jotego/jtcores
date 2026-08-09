module IKA87AD_opdec (
    input   wire    [7:0]       i_OPCODE,
    input   wire    [2:0]       i_OPCODE_PAGE,

    output  wire    [7:0]       o_MCROM_SA
);

import IKA87AD_mnemonics::*;

wire    [2:0]   opcode_page = i_OPCODE_PAGE;
wire    [7:0]   op = i_OPCODE; //alias signal
reg     [7:0]   sa; //microcode rom start address
assign  o_MCROM_SA = sa;

always_comb begin
    sa = NOP;

    if(opcode_page == 3'd0) begin
             if(op == 8'h48 || op == 8'h60 || op == 8'h64 || op == 8'h70 || op == 8'h74) sa = IRD;
        else if( op[7:4] == 4'h6  &&  op[3:0] >  4'h7 ) sa = MVI_R_IM;
        else if( op[7:4] == 4'h3  &&  op[3:0] >  4'h8 ) sa = STAX_RPA_A;
        else if( op[7:4] == 4'h2  &&  op[3:0] >  4'h8 ) sa = LDAX_A_RPA;
        else if( op[7:4] <  4'h5  &&  op[3:0] == 4'h4 ) sa = LXI_RP2_IM;
        else if( op[7:4] <  4'h4  &&  op[3:0] == 4'h2 ) sa = INX_RP2;
        else if( op[7:4] == 4'hA  &&  op[3:0] == 4'h8 ) sa = INX_EA;
        else if( op[7:4] <  4'h4  &&  op[3:0] == 4'h3 ) sa = DCX_RP2;
        else if( op[7:4] == 4'hA  &&  op[3:0] == 4'h9 ) sa = DCX_EA;
        else if( op[7:4] == 4'h5  &&  op[3:0] == 4'h4 ) sa = JMP;
        else if( op[7:4] >  4'hB                      ) sa = JR;
        else if( op[7:4] <  4'h8  &&
                (op[3:0] == 4'h6  ||  op[3:0] == 4'h7)) sa = ALUI_A_IM;
        else if( op[7:4] == 4'h7  &&  op[3:0] == 4'h1 ) sa = MVIW_WA_IM;
        else if( op[7:4] == 4'hB  &&  op[3:0] >  4'hA ) sa = STAX_RPA2_A;
        else if( op[7:4] == 4'hA  &&  op[3:0] >  4'hA ) sa = LDAX_A_RPA2;
        else if( op[7:4] == 4'h3  &&  op[3:0] == 4'h1 ) sa = BLOCK;
        else if( op[7:4] == 4'hB  &&  op[3:0] <  4'h5 ) sa = PUSH;
        else if( op[7:4] == 4'hA  &&  op[3:0] <  4'h5 ) sa = POP;
        else if( op[7:4] == 4'h6  &&  op[3:0] == 4'h2 ) sa = RETI;
        else if( op[7:4] == 4'h4  &&  op[3:0] == 4'hD ) sa = MOV_SR_A;
        else if( op[7:4] == 4'h4  &&  op[3:0] == 4'hC ) sa = MOV_A_SR1;
        else if( op[7:4] == 4'h2  &&  op[3:0] == 4'h0 ) sa = INRW;
        else if( op[7:4] == 4'h3  &&  op[3:0] == 4'h0 ) sa = DCRW;
        else if( op[7:4] == 4'h4  &&
                (op[3:0] >  4'h8  &&  op[3:0] <  4'hC)) sa = MVIX_RPA_IM;
        else if( op[7:4] == 4'h7  &&  op[3:0] >  4'h7 ) sa = CALF;
        else if( op[7:4] == 4'h4  &&  op[3:0] == 4'h0 ) sa = CALL;
        else if( op[7:4] >  4'h7  &&  op[7:4] <  4'hA ) sa = CALT;
        else if( op[7:4] == 4'h7  &&  op[3:0] == 4'h2 ) sa = SOFTI;
        else if( op[7:4] == 4'h7  &&  op[3:0] == 4'h3 ) sa = HARDI;
        else if( op[7:4] == 4'h6  &&  op[3:0] == 4'h3 ) sa = STAW;
        else if( op[7:4] == 4'h1  &&  op[3:0] >  4'h7 ) sa = MOV_R1_A;
        else if( op[7:4] == 4'h0  &&  op[3:0] == 4'h1 ) sa = LDAW;
        else if( op[7:4] == 4'h0  &&  op[3:0] >  4'h7 ) sa = MOV_A_R1;
        else if( op[7:4] == 4'h4  &&
                (op[3:0] >  4'h0  &&  op[3:0] <  4'h4)) sa = INR;
        else if( op[7:4] == 4'h5  &&
                (op[3:0] >  4'h0  &&  op[3:0] <  4'h4)) sa = DCR;
        else if( op[7:4] == 4'hB  &&
                (op[3:0] >  4'h4  &&  op[3:0] <  4'h8)) sa = DMOV_RP_EA;
        else if( op[7:4] == 4'hA  &&
                (op[3:0] >  4'h4  &&  op[3:0] <  4'h8)) sa = DMOV_EA_RP;
        else if( op[7:4] == 4'h6  &&  op[3:0] == 4'h1 ) sa = DAA;
        else if( op[7:4] == 4'h4  &&  op[3:0] >  4'hD ) sa = JRE;
        else if( op[7:4] == 4'hB  &&
                (op[3:0] == 4'h8  ||  op[3:0] == 4'h9)) sa = RET_RETS;
        else if( op[7:4] <  4'h8  &&  op[3:0] == 4'h5 ) sa = ALUIW_WA_IM;
        else if( op[7:4] == 4'h2  &&  op[3:0] == 4'h1 ) sa = JB;
        else if( op[7:4] == 4'h5  &&  op[3:0] >  4'h7 ) sa = BTST_WA;
        else if((op[7:4] == 4'hA  ||  op[7:4] == 4'hB) &&
                (op[3:0] == 4'hA))                      sa = EIDI;
        else if( op[7:4] == 4'h0  &&  op[3:0] == 4'h0 ) sa = NOP;
        else if( op[7:4] == 4'h1  &&  op[3:0] == 4'h1 ) sa = EXX;
        else if( op[7:4] == 4'h1  &&  op[3:0] == 4'h0 ) sa = EXA;
        else if( op[7:4] == 4'h5  &&  op[3:0] == 4'h0 ) sa = EXH;
        //else                                            sa = NOP;
    end
    else if(opcode_page == 3'd1) begin
             if((op[7:4] == 4'h3  ||  op[7:4] == 4'hB) &&
                (op[3:0] == 4'hB))                      sa = SUSP;
        else if( op[7:4] == 4'hA  &&  op[3:0] == 4'h8 ) sa = TABLE;
        else if( op[7:4] == 4'h3  &&  op[3:1] == 3'h4 ) sa = RLD_RRD;
        else if( op[7:4] == 4'h2  &&  op[3:0] == 4'h9 ) sa = CALB;
        else if( op[7:4] == 4'h9  &&
                (op[3:0] >  4'h1  &&  op[3:0] <  4'h6)) sa = STEAX_RPA3_EA;
        else if( op[7:4] == 4'h9  &&  op[3:0] >  4'hA ) sa = STEAX_RPA2_EA;
        else if( op[7:4] == 4'h8  &&
                (op[3:0] >  4'h1  &&  op[3:0] <  4'h6)) sa = LDEAX_EA_RPA3;
        else if( op[7:4] == 4'h8  &&  op[3:0] >  4'hA ) sa = LDEAX_EA_RPA2;
        else if( op[7:4] == 4'h2  &&  op[3:0] >  4'hB ) sa = MUL;
        else if( op[7:4] == 4'h3  &&  op[3:0] >  4'hB ) sa = DIV;
        else if( op[7:4] == 4'hC  &&  op[3:0] <  4'h2 ) sa = DMOV_EA_SR4;
        else if( op[7:4] == 4'hD  &&
                (op[3:0] >  4'h1  &&  op[3:0] <  4'h4)) sa = DMOV_SR3_EA;
        else if( op[7:4] == 4'h3  &&  op[3:0] == 4'hA ) sa = NEGA;
        else if( op[7:4] == 4'h2  &&
                (op[3:0] == 4'hA  ||  op[3:0] == 4'hB)) sa = STC_CLC;
        else if( op[7:4] <  4'h4  &&  op[3:0] <  4'h8 ) sa = ROTSHFT_R2;
        else if((op[7:4] == 4'hA  ||  op[7:4] == 4'hB) &&
                (op[3:0] <  4'h8))                      sa = ROTSHFT_EA;
        else if( op[7:4] == 4'h2  &&  op[3:0] == 4'h8 ) sa = JEA;
        else if( op[7:4] == 4'h0  &&  op[3:0] >  4'h7 ) sa = SK;
        else if( op[7:4] == 4'h1  &&  op[3:0] >  4'h7 ) sa = SKN;
        else if( op[7:4] == 4'h4  ||  op[7:4] == 4'h5 ) sa = SKIT;
        else if( op[7:4] == 4'h6  ||  op[7:4] == 4'h7 ) sa = SKNIT;
    end
    else if(opcode_page == 3'd2) begin
             if( op[7]   == 1'b0                      ) sa = ALU_R_A;
        else                                            sa = ALU_A_R;
    end
    else if(opcode_page == 3'd3) begin
                                                        sa = ALUI_SR2_IM;
    end
    else if(opcode_page == 3'd4) begin
             if( op[7:4] >  4'h7)                       sa = ALUX_A_RPA;
        else if((op[7:4] == 4'h4  &&  op[3:0] <  4'h4) ||
                (op[7:4] == 4'h6  &&  op[3:0] <  4'h4)) sa = EALU_EA_R2;
        else if( op[7:4] == 4'h6  &&  op[3:0] >  4'h7 ) sa = MOV_R_MEM;
        else if( op[7:4] == 4'h7  &&  op[3:0] >  4'h7 ) sa = MOV_MEM_R;
        else if( op[7:4] <  4'h4  &&  op[3:0] == 4'hF ) sa = LD_RP2_MEM;
        else if( op[7:4] <  4'h4  &&  op[3:0] == 4'hE ) sa = ST_MEM_RP2;
    end
    else if(opcode_page == 3'd5) begin
             if( op[7:4] <  4'h8)                       sa = ALUI_R_IM;
        else if( op[7:4] >  4'h7  &&  op[2]   == 1'b1 ) sa = DALU_EA_RP;
        else if( op[7:4] >  4'h7  &&  op[2]   == 1'b0 ) sa = ALUW_A_WA;
    end
end

endmodule