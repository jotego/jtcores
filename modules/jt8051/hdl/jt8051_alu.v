/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

module jt8051_alu(
    input      [ 4:0] alu_sel,
    input      [ 7:0] lhs,
    input      [ 7:0] rhs,
    input             carry,
    input             aux_carry,
    input      [ 2:0] bitno,
    output reg [ 7:0] result,
    output reg [ 7:0] aux,
    output reg        cy,
    output reg        ac,
    output reg        ov,
    output reg        neq
);

`include "jt8051_param.vh"

reg [ 8:0] sum;
reg [15:0] product;
reg [ 8:0] rem;
reg [ 7:0] quo;
integer k;

always @* begin
    result  = lhs;
    aux     = 8'd0;
    sum     = 9'd0;
    product = 16'd0;
    rem     = 9'd0;
    quo     = 8'd0;
    cy      = 1'b0;
    ac      = 1'b0;
    ov      = 1'b0;
    neq     = lhs != rhs;
    case (alu_sel)
        ADD_ALU: begin
            sum    = {1'b0,lhs}+{1'b0,rhs};
            result = sum[7:0];
            cy     = sum[8];
            ac     = {1'b0,lhs[3:0]}+{1'b0,rhs[3:0]} > 5'h0f;
            ov     = ~(lhs[7]^rhs[7]) & (lhs[7]^result[7]);
        end
        ADDC_ALU: begin
            sum    = {1'b0,lhs}+{1'b0,rhs}+carry;
            result = sum[7:0];
            cy     = sum[8];
            ac     = {1'b0,lhs[3:0]}+{1'b0,rhs[3:0]}+carry > 5'h0f;
            ov     = ~(lhs[7]^rhs[7]) & (lhs[7]^result[7]);
        end
        SUBB_ALU: begin
            sum    = {1'b0,lhs}-{1'b0,rhs}-carry;
            result = sum[7:0];
            cy     = sum[8];
            ac     = {1'b0,lhs[3:0]} < ({1'b0,rhs[3:0]}+carry);
            ov     = (lhs[7]^rhs[7]) & (lhs[7]^result[7]);
        end
        OR_ALU:    result = lhs | rhs;
        AND_ALU:   result = lhs & rhs;
        XOR_ALU:   result = lhs ^ rhs;
        INC_ALU:   result = lhs + 8'd1;
        DEC_ALU:   result = lhs - 8'd1;
        RR_ALU:    result = {lhs[0],lhs[7:1]};
        RL_ALU:    result = {lhs[6:0],lhs[7]};
        RRC_ALU: begin result = {carry,lhs[7:1]}; cy = lhs[0]; end
        RLC_ALU: begin result = {lhs[6:0],carry}; cy = lhs[7]; end
        SWAP_ALU:  result = {lhs[3:0],lhs[7:4]};
        XCHD_ALU: begin
            result = {rhs[7:4],lhs[3:0]};
            aux    = {lhs[7:4],rhs[3:0]};
        end
        CPL_ALU:   result = ~lhs;
        CMP_ALU: begin
            sum = {1'b0,lhs}-{1'b0,rhs};
            result = sum[7:0];
            cy = sum[8];
        end
        DA_ALU: begin
            sum = {1'b0,lhs};
            if (aux_carry || lhs[3:0]>4'd9) sum = sum+9'h006;
            if (carry || sum>9'h099) sum = sum+9'h060;
            result = sum[7:0];
            cy = carry | sum[8];
        end
        MUL_ALU: begin
            product = lhs*rhs;
            result  = product[7:0];
            aux     = product[15:8];
            ov      = |product[15:8];
        end
        DIV_ALU: begin
            if (rhs==0) begin
                result = lhs;
                aux    = rhs;
                ov     = 1'b1;
            end else begin
                for (k=7;k>=0;k=k-1) begin
                    rem = {rem[7:0],lhs[k]};
                    if (rem>={1'b0,rhs}) begin
                        rem = rem-{1'b0,rhs};
                        quo[k] = 1'b1;
                    end
                end
                result = quo;
                aux    = rem[7:0];
            end
        end
        default: ;
    endcase
end

endmodule
