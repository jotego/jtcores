// Copyright 2011-2018 Frederic Requin
//
// This file is part of the MCC216 project
//
// The J68 core:
// -------------
// Simple re-implementation of the MC68000 CPU
// The core has the following characteristics:
//  - Tested on a Cyclone III (90 MHz) and a Stratix II (180 MHz)
//  - from 1500 (~70 MHz) to 1900 LEs (~90 MHz) on Cyclone III
//  - 2048 x 20-bit microcode ROM
//  - 256 x 28-bit decode ROM
//  - 2 x block RAM for the data and instruction stacks
//  - stack based CPU with forth-like microcode
//  - not cycle-exact : needs a frequency ~3 x higher
//  - all 68000 instructions are implemented
//  - almost all 68000 exceptions are implemented (only bus error missing)
//  - only auto-vector interrupts supported

module j68_alu
(
    // Clock and reset
    input             rst,    // CPU reset
    input             clk,    // CPU clock
    /* direct_enable = 1 */ input clk_ena, // CPU clock enable
    // Control signals
    input             cc_upd, // Condition codes update
    input       [1:0] size,   // Operand size (00 = byte, 01 = word, 1x = long)
    input       [4:0] alu_c,  // ALU control
    input       [1:0] a_ctl,  // A source control
    input       [1:0] b_ctl,  // B source control
    // Operands
    input             c_in,   // Carry in
    input             v_in,   // Overflow in
    input      [15:0] a_src,  // A source
    input      [15:0] b_src,  // B source
    input      [15:0] ram_in, // RAM read
    input      [15:0] io_in,  // I/O read
    input      [15:0] imm_in, // Immediate
    // Result
    output     [31:0] result, // ALU result
    // Flags
    output      [4:0] c_flg,  // Partial C/X flags
    output      [4:0] v_flg,  // Partial V flag
    output     [31:0] l_res,  // Latched result for N & Z flags
    output      [3:0] l_alu,  // Latched ALU control
    output      [1:0] l_size  // Latched operand size
);

    reg  [15:0] w_a_log; // Operand A for logic
    reg  [15:0] w_a_add; // Operand A for adder
    reg         w_a_lsb; // Operand A lsb
    
    reg  [15:0] w_b_log; // Operand B for logic
    reg  [15:0] w_b_add; // Operand B for adder
    reg         w_b_lsb; // Operand B lsb
    
    wire [17:0] w_add_r; // Adder result
    reg  [15:0] w_log_r; // Logical result
    reg  [31:0] w_lsh_r; // Left shifter result
    reg  [31:0] w_rsh_r; // Right shifter result
    
    wire [4:0]  w_c_flg; // Carry flags
    wire [4:0]  w_v_flg; // Overflow flags
    
    reg  [31:0] w_result; // ALU result
    
    reg   [4:0] r_c_flg;  // Partial C/X flags
    reg   [4:0] r_v_flg;  // Partial V flag
    reg  [31:0] r_l_res;  // Latched result for N & Z flags
    reg   [3:0] r_l_alu;  // Latched ALU control
    reg   [1:0] r_l_size; // Latched operand size
    
    // A source for Adder (1 LUT level)
    always @(*) begin : ADDER_A_SRC
    
        case (a_ctl)
            2'b00 : w_a_add = 16'h0000;
            2'b01 : w_a_add = 16'hFFFF;
            2'b10 : w_a_add = a_src;
            2'b11 : w_a_add = ~a_src;
        endcase
    end
    
    // B source for Adder (1 LUT level)
    always @(*) begin : ADDER_B_SRC
    
        case (b_ctl)
            2'b00 : w_b_add = 16'h0000;
            2'b01 : w_b_add = 16'hFFFF;
            2'b10 : w_b_add = b_src;
            2'b11 : w_b_add = ~b_src;
        endcase
    end
    
    // A source for Logic (1 LUT level)
    always @(*) begin : LOGIC_A_SRC
    
        case (a_ctl)
            2'b00 : w_a_log = 16'h0000;
            2'b01 : w_a_log = imm_in; // Immediate value through OR
            2'b10 : w_a_log = a_src;
            2'b11 : w_a_log = ram_in; // RAM read through OR
        endcase
    end
    
    // B source for Logic (2 LUT levels)
    always @(*) begin : LOGIC_B_SRC
    
        if (alu_c[4]) begin
            // Mask generation for BTST, BCHG, BCLR, BSET
            case ({b_src[4]&(size[1]|size[0]), b_src[3]&(size[1]|size[0]), b_src[2:0]})
                5'b00000 : w_b_log = 16'b0000000000000001 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b00001 : w_b_log = 16'b0000000000000010 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b00010 : w_b_log = 16'b0000000000000100 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b00011 : w_b_log = 16'b0000000000001000 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b00100 : w_b_log = 16'b0000000000010000 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b00101 : w_b_log = 16'b0000000000100000 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b00110 : w_b_log = 16'b0000000001000000 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b00111 : w_b_log = 16'b0000000010000000 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b01000 : w_b_log = 16'b0000000100000000 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b01001 : w_b_log = 16'b0000001000000000 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b01010 : w_b_log = 16'b0000010000000000 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b01011 : w_b_log = 16'b0000100000000000 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b01100 : w_b_log = 16'b0001000000000000 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b01101 : w_b_log = 16'b0010000000000000 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b01110 : w_b_log = 16'b0100000000000000 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b01111 : w_b_log = 16'b1000000000000000 & {16{~size[1]}} ^ {16{b_ctl[0]}};
                5'b10000 : w_b_log = 16'b0000000000000001 & {16{~size[0]}} ^ {16{b_ctl[0]}};
                5'b10001 : w_b_log = 16'b0000000000000010 & {16{~size[0]}} ^ {16{b_ctl[0]}};
                5'b10010 : w_b_log = 16'b0000000000000100 & {16{~size[0]}} ^ {16{b_ctl[0]}};
                5'b10011 : w_b_log = 16'b0000000000001000 & {16{~size[0]}} ^ {16{b_ctl[0]}};
                5'b10100 : w_b_log = 16'b0000000000010000 & {16{~size[0]}} ^ {16{b_ctl[0]}};
                5'b10101 : w_b_log = 16'b0000000000100000 & {16{~size[0]}} ^ {16{b_ctl[0]}};
                5'b10110 : w_b_log = 16'b0000000001000000 & {16{~size[0]}} ^ {16{b_ctl[0]}};
                5'b10111 : w_b_log = 16'b0000000010000000 & {16{~size[0]}} ^ {16{b_ctl[0]}};
                5'b11000 : w_b_log = 16'b0000000100000000 & {16{~size[0]}} ^ {16{b_ctl[0]}};
                5'b11001 : w_b_log = 16'b0000001000000000 & {16{~size[0]}} ^ {16{b_ctl[0]}};
                5'b11010 : w_b_log = 16'b0000010000000000 & {16{~size[0]}} ^ {16{b_ctl[0]}};
                5'b11011 : w_b_log = 16'b0000100000000000 & {16{~size[0]}} ^ {16{b_ctl[0]}};
                5'b11100 : w_b_log = 16'b0001000000000000 & {16{~size[0]}} ^ {16{b_ctl[0]}};
                5'b11101 : w_b_log = 16'b0010000000000000 & {16{~size[0]}} ^ {16{b_ctl[0]}};
                5'b11110 : w_b_log = 16'b0100000000000000 & {16{~size[0]}} ^ {16{b_ctl[0]}};
                5'b11111 : w_b_log = 16'b1000000000000000 & {16{~size[0]}} ^ {16{b_ctl[0]}};
            endcase
        end
        else begin
            case (b_ctl)
                2'b00 : w_b_log = 16'h0000;
                2'b01 : w_b_log = io_in;  // I/O read through OR
                2'b10 : w_b_log = b_src;
                2'b11 : w_b_log = ~b_src;
            endcase
        end
    end
    
    // Carry input (1 LUT level)
    always @(*) begin : CARRY_IN
        case (alu_c[1:0])
            2'b00 : begin // For: R = A + B
                w_a_lsb = 1'b0;
                w_b_lsb = 1'b0;
            end
            2'b01 : begin // For: R = A + B + Carry
                w_a_lsb = c_in;
                w_b_lsb = c_in;
            end
            2'b10 : begin // For: R = A - B
                w_a_lsb = 1'b1;
                w_b_lsb = 1'b1;
            end
            2'b11 : begin // For: R = B - A - Borrow
                w_a_lsb = ~c_in;
                w_b_lsb = ~c_in;
            end
        endcase
    end
    
    // Adder (1 LUT level + carry chain)
    assign w_add_r = {1'b0, w_a_add, w_a_lsb} + {1'b0, w_b_add, w_b_lsb};
    
    // Logical operations (2 LUT levels)
    always @(*) begin : LOGIC_OP
    
        case (alu_c[1:0])
            2'b00 : w_log_r[7:0] =  w_a_log[7:0] & w_b_log[7:0]; // AND.B
            2'b01 : w_log_r[7:0] =  w_a_log[7:0] | w_b_log[7:0]; // OR.B
            2'b10 : w_log_r[7:0] =  w_a_log[7:0] ^ w_b_log[7:0]; // XOR.B
            2'b11 : w_log_r[7:0] = ~w_a_log[7:0];                // NOT.B
        endcase
        if (size == 2'b00) begin
            w_log_r[15:8] = w_a_log[15:8];
        end
        else begin
            case (alu_c[1:0])
                2'b00 : w_log_r[15:8] =  w_a_log[15:8] & w_b_log[15:8]; // AND.W
                2'b01 : w_log_r[15:8] =  w_a_log[15:8] | w_b_log[15:8]; // OR.W
                2'b10 : w_log_r[15:8] =  w_a_log[15:8] ^ w_b_log[15:8]; // XOR.W
                2'b11 : w_log_r[15:8] = ~w_a_log[15:8];                 // NOT.W
            endcase
        end
    end
    
    // Left shifter (1 LUT level)
    always @(*) begin : LEFT_SHIFT
        case (size)
            2'b00   : w_lsh_r = { b_src[15:0], a_src[15:8], a_src[6:0], c_in }; // Byte
            2'b01   : w_lsh_r = { b_src[15:0], a_src[14:0], c_in };             // Word
            default : w_lsh_r = { b_src[14:0], a_src[15:0], c_in };             // Long
        endcase
    end
    
    // Right shifter (1 LUT level)
    always @(*) begin : RIGHT_SHIFT
        case (size)
            2'b00   : w_rsh_r = { b_src[15:0], a_src[15:8], c_in, a_src[7:1] }; // Byte
            2'b01   : w_rsh_r = { b_src[15:0], c_in, a_src[15:1] };             // Word
            default : w_rsh_r = { c_in, b_src[15:0], a_src[15:1] };             // Long
        endcase
    end
    
    // Final MUX (2 LUTs level)
    always @(*) begin : ALU_MUX
        case (alu_c[3:2])
            2'b00 : w_result = { a_src, w_add_r[16:1] }; // Adder
            2'b01 : w_result = { a_src, w_log_r };       // Logic
            2'b10 : w_result = w_lsh_r;                  // Left shift
            2'b11 : w_result = w_rsh_r;                  // Right shift
        endcase
    end
    assign result = w_result;
    
    // Partial carry flags from adder
    assign w_c_flg[0] = w_add_r[9] ^ w_a_add[8]
                      ^ w_b_add[8] ^ alu_c[1];     // Byte
    assign w_c_flg[1] = w_add_r[17] ^ alu_c[1];    // Word
    // Partial carry flags from shifter
    assign w_c_flg[2] = (a_src[0] & alu_c[2])
                      | (a_src[7] & ~alu_c[2]);    // Byte
    assign w_c_flg[3] = (a_src[0] & alu_c[2])
                      | (a_src[15] & ~alu_c[2]);   // Word
    assign w_c_flg[4] = (a_src[0]  & alu_c[2])
                      | (b_src[15] & ~alu_c[2]);   // Long
    // Partial overflow flags from adder
    assign w_v_flg[0] = w_add_r[9] ^ w_add_r[8]
                      ^ w_a_add[8] ^ w_a_add[7]
                      ^ w_b_add[8] ^ w_b_add[7];   // Byte
    assign w_v_flg[1] = w_add_r[17] ^ w_add_r[16]
                      ^ w_a_add[15] ^ w_b_add[15]; // Word
    // Partial overflow flags from shifter
    assign w_v_flg[2] = v_in | (a_src[7] ^ a_src[6]);                               // Byte
    assign w_v_flg[3] = v_in | (a_src[15] ^ a_src[14]);                             // Word
    assign w_v_flg[4] = v_in | (b_src[15] ^ b_src[14]);                             // Long
    
    // Latch partial flags and result
    always@(posedge rst or posedge clk) begin : ALU_REGS
    
        if (rst) begin
            r_c_flg  <= 5'b00000;
            r_v_flg  <= 5'b00000;
            r_l_res  <= 32'h00000000;
            r_l_alu  <= 4'b0000;
            r_l_size <= 2'b00;
        end
        else if (clk_ena) begin
            if (cc_upd) begin
                r_c_flg  <= w_c_flg;
                r_v_flg  <= w_v_flg;
                r_l_res  <= result;
                r_l_alu  <= alu_c[3:0];
                r_l_size <= size;
            end
        end
    end
    
    assign c_flg  = r_c_flg;
    assign v_flg  = r_v_flg;
    assign l_res  = r_l_res;
    assign l_alu  = r_l_alu;
    assign l_size = r_l_size;

endmodule
