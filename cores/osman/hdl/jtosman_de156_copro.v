/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-11-2026 */

module jtosman_de156_copro(
    input             clk,
    input             rst,
    input             wr,
    input             divide,
    input      [ 3:0] addr,
    input      [31:0] din,
    output     [31:0] dout,
    output            busy
);

localparam [2:0] IDLE=0, UNPACK=1, ARITH=2, PRODUCT=3, QUOTIENT=4, PACK=5;

reg [2:0] state;
reg [4:0] step;
reg [1:0] command;
reg [31:0] regs[0:15];
reg [31:0] operand_a, operand_b, binary_a, binary_b, result, packed_bcd;
wire [33:0] difference = {1'b0,result,operand_a[31]} - {2'b0,regs[1]};
wire quotient_bit = !difference[33];
wire [31:0] quotient_next = {operand_a[30:0],quotient_bit};
wire [31:0] remainder_next = quotient_bit ? difference[31:0] : {result[30:0],operand_a[31]};
wire [31:0] product_next = result + (operand_b[0] ? binary_a : 32'd0);
wire [31:0] corrected;
wire [31:0] bcd_next = {corrected[30:0],result[31]};
genvar digit;
integer r;

assign dout = regs[addr];
assign busy = state != IDLE;

generate
    for(digit=0; digit<8; digit=digit+1) begin : gen_bcd
        wire [3:0] nibble = packed_bcd[digit*4+:4];
        assign corrected[digit*4+:4] = nibble >= 5 ? nibble + 4'd3 : nibble;
    end
endgenerate

always @(posedge clk) begin
    if(rst) begin
        state <= IDLE;
        step <= 0;
        for(r=0; r<16; r=r+1) regs[r] <= 0;
    end else case(state)
        IDLE: begin
            if(wr) begin
                regs[addr] <= din;
                if(addr==4'd2 && (din==0 || din==1 || din==3)) begin
                    command   <= din[1:0];
                    operand_a <= regs[0];
                    operand_b <= regs[1];
                    binary_a  <= 0;
                    binary_b  <= 0;
                    step      <= 0;
                    state     <= UNPACK;
                end
            end else if(divide) begin
                if(regs[1]==0) begin
                    regs[3] <= 32'hffffffff;
                    regs[4] <= 32'hffffffff;
                end else begin
                    operand_a <= regs[0];
                    result    <= 0;
                    step      <= 0;
                    state     <= QUOTIENT;
                end
            end
        end
        UNPACK: begin
            binary_a  <= (binary_a<<3) + (binary_a<<1) + {28'd0,operand_a[31:28]};
            binary_b  <= (binary_b<<3) + (binary_b<<1) + {28'd0,operand_b[31:28]};
            operand_a <= operand_a<<4;
            operand_b <= operand_b<<4;
            step      <= step+1'd1;
            if(step==7) state <= ARITH;
        end
        ARITH: begin
            packed_bcd <= 0;
            step <= 0;
            case(command)
                2'd0: begin result <= binary_a+binary_b; state <= PACK; end
                2'd3: begin result <= binary_a-binary_b; state <= PACK; end
                default: begin
                    result <= 0;
                    operand_b <= binary_b;
                    state <= PRODUCT;
                end
            endcase
        end
        PRODUCT: begin
            result    <= product_next;
            binary_a  <= binary_a<<1;
            operand_b <= operand_b>>1;
            step      <= step+1'd1;
            if(step==31) state <= PACK;
        end
        QUOTIENT: begin
            operand_a <= quotient_next;
            result    <= remainder_next;
            step      <= step+1'd1;
            if(step==31) begin
                regs[3] <= quotient_next;
                regs[4] <= remainder_next;
                state   <= IDLE;
            end
        end
        PACK: begin
            packed_bcd <= bcd_next;
            result <= result<<1;
            step <= step+1'd1;
            if(step==31) begin
                regs[5] <= bcd_next;
                state   <= IDLE;
            end
        end
        default: state <= IDLE;
    endcase
end

endmodule
