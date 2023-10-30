module jt680x_alu(
    input   [ 6:0] sel,
    input   [15:0] op0, op1,
    output  [15:0] rslt,

    input   [ 5:0] cc,
    output  [ 5:0] cc_out
);

reg       valid_lo, valid_hi, cin;
reg [7:0] daa;

always @* begin
    case (alu_ctrl)
        ALU_ADC, ALU_SBC, ALU_ROL8, ALU_ROR8: cin = cc[CBIT];
        default: cin = 0;
    endcase
end

always @* begin
    valid_lo = (op0[3:0] <= 9);
    valid_hi = (op0[7:4] <= 9);

    if( !cc[CBIT] ) begin
        if( cc[HBIT] ) begin
            if (valid_hi)
                daa = 8'b00000110;
            else
                daa = 8'b01100110;
        end else begin
            if (valid_lo) begin
                if (valid_hi)
                    daa = 8'b00000000;
                else
                    daa = 8'b01100000;
            end else begin
                if( op0[7:4] <= 8 )
                    daa = 8'b00000110;
                else
                    daa = 8'b01100110;
            end
        end
    end else begin
        if ( cc[HBIT] == 1'b1 )
            daa = 8'b01100110;
        else if (valid_lo)
            daa = 8'b01100000;
        else
            daa = 8'b01100110;
    end
end

always @* begin
    cc_out = cc;
    case (sel)
        ALU_ADD8, ALU_INC, ALU_ADD16, ALU_INX, ALU_ADC:
            rslt = op0 + op1 + {15'b0, cin};
        ALU_SUB8, ALU_DEC, ALU_SUB16, ALU_DEX, ALU_SBC:
            rslt = op0 - op1 - {15'b0, cin};
        ALU_AND: rslt = op0 & op1;
        ALU_ORA: rslt = op0 | op1;
        ALU_EOR: rslt = op0 ^ op1;
        ALU_LSL16, ALU_ASL8, ALU_ROL8:
            rslt = {op0[14:0], cin};
        ALU_LSR16, ALU_LSR8:
            rslt = {cin, op0[15:1]};
        ALU_ROR8: rslt = {8'b0, cin, op0[7:1]};
        ALU_ASR8: rslt = {8'b0, op0[7], op0[7:1]};
        ALU_NEG:  rslt = -op0;
        ALU_COM:  rslt = ~op0;
        ALU_CLR, ALU_LD8, ALU_LD16:
            rslt = op1;
        ALU_ST8, ALU_TST, ALU_ST16:
            rslt = op0;
        ALU_DAA:
            rslt = op0 + {8'b0, daa};
        ALU_TPA:
            rslt = {8'b0, cc};
        ALU_MUL:
            rslt = { 8'd0, op0 } * { 8'd0, op1};
        default:
            rslt = op0; // nop
    endcase

    case (sel)
        ALU_ADD8,  ALU_SUB8,  ALU_ADC,   ALU_SBC, ALU_AND,  ALU_ORA,  ALU_EOR,  ALU_INC,
        ALU_DEC,   ALU_NEG,   ALU_COM,   ALU_CLR, ALU_ROL8, ALU_ROR8, ALU_ASR8, ALU_ASL8,
        ALU_LSR8,  ALU_LD8 ,  ALU_ST8,   ALU_TST: cc_out[ZBIT] = rslt[7:0]==0;
        ALU_ADD16, ALU_SUB16, ALU_LSL16, ALU_LSR16,
        ALU_INX,   ALU_DEX,   ALU_LD16,  ALU_ST16: cc_out[ZBIT] = rslt==0;
        default:;
    endcase

    case (sel)
        ALU_ADD8, ALU_ADC: cc_out[CBIT] = (op0[7] & op1[7]) | (op0[7] & ~rslt[7]) | (op1[7] & ~rslt[7]);
        ALU_SUB8, ALU_SBC: cc_out[CBIT] = ((~op0[7]) & op1[7]) | ((~op0[7]) & rslt[7]) | (op1[7] & rslt[7]);
        ALU_ADD16: cc_out[CBIT] = (op0[15] & op1[15]) | (op0[15] & ~rslt[15]) | (op1[15] & ~rslt[15]);
        ALU_SUB16: cc_out[CBIT] = ((~op0[15]) & op1[15]) | ((~op0[15]) & rslt[15]) | (op1[15] & rslt[15]);
        ALU_ROR8, ALU_LSR16, ALU_LSR8, ALU_ASR8: cc_out[CBIT] = op0[0];
        ALU_ROL8, ALU_ASL8: cc_out[CBIT] = op0[7];
        ALU_LSL16: cc_out[CBIT] = op0[15];
        ALU_COM,  ALU_SEC: cc_out[CBIT] = 1;
        ALU_NEG,  ALU_CLR: cc_out[CBIT] = |rslt[7:0];
        ALU_DAA: cc_out[CBIT] = daa[7:4] == 4'b0110;
        ALU_CLC, ALU_TST: cc_out[CBIT] = 1'b0;
        default:;
    endcase

    case (sel)
        ALU_ADD8, ALU_SUB8, ALU_ADC,  ALU_SBC,
        ALU_AND,  ALU_ORA,  ALU_EOR,  ALU_ROL8,
        ALU_ROR8, ALU_ASR8, ALU_ASL8, ALU_LSR8,
        ALU_INC,  ALU_DEC,  ALU_NEG,  ALU_COM,
        ALU_CLR,  ALU_LD8,  ALU_ST8,  ALU_TST:
            cc_out[NBIT] = rslt[7];
        ALU_ADD16, ALU_SUB16, ALU_LSL16, ALU_LSR16,
        ALU_LD16, ALU_ST16:
            cc_out[NBIT] = rslt[15];
        default:;
    endcase

    case (sel)
        ALU_SEI: cc_out[IBIT] = 1;
        ALU_CLI: cc_out[IBIT] = 0;
        default:;
    endcase

    case (sel)
        ALU_ADD8, ALU_ADC:
            cc_out[HBIT] = (op0[3] & op1[3]) |
                (op1[3] & ~rslt[3]) |
                (op0[3] & ~rslt[3]);
        default:;
    endcase

    case (sel)
        ALU_ADD8, ALU_ADC:
            cc_out[VBIT] = (op0[7] & op1[7] & (~rslt[7])) |
                ((~op0[7]) & (~op1[7]) & rslt[7]);
        ALU_SUB8, ALU_SBC:
            cc_out[VBIT] = (op0[7] & (~op1[7]) & (~rslt[7])) |
                ((~op0[7]) & op1[7] & rslt[7]);
        ALU_ADD16:
            cc_out[VBIT] = (op0[15] & op1[15] & (~rslt[15])) |
                ((~op0[15]) & (~op1[15]) & rslt[15]);
        ALU_SUB16:
            cc_out[VBIT] = (op0[15] & (~op1[15]) & (~rslt[15])) |
                ((~op0[15]) & op1[15] & rslt[15]);
        ALU_INC:
            cc_out[VBIT] = op0==8'h7f;
        ALU_DEC, ALU_NEG:
            cc_out[VBIT] = (op0[7] & (~op0[6]) & (~op0[5]) & (~op0[4]) &
                (~op0[3]) & (~op0[2]) & (~op0[1]) & (~op0[0]));
        ALU_ASR8:           cc_out[VBIT] = op0[0] ^ op0[7];
        ALU_LSR8, ALU_LSR16:cc_out[VBIT] = op0[0];
        ALU_ROR8:           cc_out[VBIT] = op0[0] ^ cc[CBIT];
        ALU_LSL16:          cc_out[VBIT] = op0[15] ^ op0[14];
        ALU_ROL8, ALU_ASL8: cc_out[VBIT] = op0[7] ^ op0[6];
        ALU_AND, ALU_ORA, ALU_EOR,  ALU_COM,
        ALU_ST8, ALU_TST, ALU_ST16, ALU_LD8,
        ALU_LD16,ALU_CLV:
                            cc_out[VBIT] = 1'b0;
        ALU_SEV:            cc_out[VBIT] = 1;
        default:;
    endcase

    if( sel==ALU_TAP ) cc_out = op0[5:0];
end

endmodule