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

module j68_flags
(
    // Clock and reset
    input             rst,    // CPU reset
    input             clk,    // CPU clock
    /* direct_enable = 1 */ input clk_ena, // CPU clock enable
    // Flags input
    input      [4:0]  c_flg,  // Partial C/X flags
    input      [5:0]  v_flg,  // Partial V flags
    input      [31:0] l_res,  // Latched result for N & Z flags
    input      [3:0]  l_alu,  // Latched ALU control
    input      [1:0]  l_size, // Latched operand size
    // Operand input
    input      [15:0] a_src,  // A operand
    input      [15:0] b_src,  // B operand
    // Flags control
    input      [10:0] flg_c,  // Flags output control
    input      [3:0]  cin_c,  // Carry in control
    // Flags output
    output      [4:0] cc_out,  // XNZVC 68000 flags
    output            c_in,    // Carry in for ALU
    output            z_flg,  // Zero flag for test block
    output            g_flg   // Greater than flag for test block
);
    reg        w_c_flg;
    reg        w_v_flg;
    reg        w_z_flg;
    reg        w_n_flg;
    wire [2:0] w_zero;
    
    reg        r_z_flg;
    reg  [4:0] r_cc_out;
    reg        r_c_in;

    // C/X flag computation
    always@(*) begin : C_X_FLAG
    
        case (l_alu[3:2])
            // Adder
            2'b00 : begin
                if (l_size == 2'b00) begin
                    w_c_flg = c_flg[0]; // Byte
                end
                else begin
                    w_c_flg = c_flg[1]; // Word & Long
                end
            end
            // Logic
            2'b01 : begin
                w_c_flg = 1'b0;
            end
            // Shifter
            default : begin
                case (l_size)
                    2'b00   : w_c_flg = c_flg[2]; // Byte
                    2'b01   : w_c_flg = c_flg[3]; // Word
                    default : w_c_flg = c_flg[4]; // Long
                endcase
            end
        endcase
    end

    // V flag computation
    always@(l_alu or l_size or v_flg) begin : V_FLAG
    
        case (l_alu[3:2])
            // Adder
            2'b00 : begin
                if (l_size == 2'b00) begin
                    w_v_flg = v_flg[0]; // Byte
                end
                else begin
                    w_v_flg = v_flg[1]; // Word & Long
                end
            end
            // Left shifter (ASL case)
            2'b10 : begin
                case (l_size)
                    2'b00   : w_v_flg = v_flg[2]; // Byte
                    2'b01   : w_v_flg = v_flg[3]; // Word
                    default : w_v_flg = v_flg[4]; // Long
                endcase
            end
            // Right shifter (DIVU/DIVS case)
            2'b11 : begin
                w_v_flg = v_flg[5] & l_alu[1];
            end
            // Logic : no overflow
            default : begin
                w_v_flg = 1'b0;
            end
        endcase
    end

    // Z flag computation
    assign w_zero[0] = (l_res[7:0] == 8'h00)      ? 1'b1 : 1'b0;
    assign w_zero[1] = (l_res[15:8] == 8'h00)     ? 1'b1 : 1'b0;
    assign w_zero[2] = (l_res[31:16] == 16'h0000) ? 1'b1 : 1'b0;
    always@(*) begin : Z_FLAG
    
        if (l_alu[3]) begin
            // Shifter
            case (l_size)
                2'b00   : w_z_flg = w_zero[0];                         // Byte
                2'b01   : w_z_flg = w_zero[0] & w_zero[1];             // Word
                default : w_z_flg = w_zero[0] & w_zero[1] & w_zero[2]; // Long
            endcase
        end
        else begin
            // Adder & Logic
            case (l_size)
                2'b00   : w_z_flg = w_zero[0];                         // Byte
                2'b01   : w_z_flg = w_zero[0] & w_zero[1];             // Word
                default : w_z_flg = w_zero[0] & w_zero[1] & r_z_flg;   // Long
            endcase
        end
    end

    // N flag computation
    always@(*) begin : N_FLAG
    
        if (l_alu[3]) begin
            // Shifter
            case (l_size)
                2'b00   : w_n_flg = l_res[7];  // Byte
                2'b01   : w_n_flg = l_res[15]; // Word
                default : w_n_flg = l_res[31]; // Long
            endcase
        end
        else begin
            // Adder & Logic
            case (l_size)
                2'b00   : w_n_flg = l_res[7];  // Byte
                2'b01   : w_n_flg = l_res[15]; // Word
                default : w_n_flg = l_res[15]; // Long
            endcase
        end
    end

    // Flag output control
    //  00 : keep (-)
    //  01 : update (*)
    //  10 : clear (0)
    //  11 : set (1)
    // 100 : update, clear only (.)
    always@(posedge rst or posedge clk) begin : CCR_OUTPUT
    
        if (rst) begin
            r_cc_out  <= 5'b00100;
            r_z_flg <= 1'b0;
        end
        else if (clk_ena) begin
            // C flag update
            case (flg_c[1:0])
                2'b00 : r_cc_out[0] <= r_cc_out[0];
                2'b01 : r_cc_out[0] <= w_c_flg;
                2'b10 : r_cc_out[0] <= 1'b0;
                2'b11 : r_cc_out[0] <= 1'b1;
            endcase
            // V flag update
            case (flg_c[3:2])
                2'b00 : r_cc_out[1] <= r_cc_out[1];
                2'b01 : r_cc_out[1] <= w_v_flg;
                2'b10 : r_cc_out[1] <= 1'b0;
                2'b11 : r_cc_out[1] <= 1'b1;
            endcase
            // Z flag update
            case (flg_c[6:4])
                3'b000 : r_cc_out[2] <= r_cc_out[2];
                3'b001 : r_cc_out[2] <= w_z_flg;
                3'b010 : r_cc_out[2] <= 1'b0;
                3'b011 : r_cc_out[2] <= 1'b1;
                3'b100 : r_cc_out[2] <= r_cc_out[2];
                3'b101 : r_cc_out[2] <= w_z_flg & r_cc_out[2];
                3'b110 : r_cc_out[2] <= 1'b0;
                3'b111 : r_cc_out[2] <= 1'b1;
            endcase
            // N flag update
            case (flg_c[8:7])
                2'b00 : r_cc_out[3] <= r_cc_out[3];
                2'b01 : r_cc_out[3] <= w_n_flg;
                2'b10 : r_cc_out[3] <= 1'b0;
                2'b11 : r_cc_out[3] <= 1'b1;
            endcase
            // X flag update
            case (flg_c[10:9])
                2'b00 : r_cc_out[4] <= r_cc_out[4];
                2'b01 : r_cc_out[4] <= w_c_flg;
                2'b10 : r_cc_out[4] <= 1'b0;
                2'b11 : r_cc_out[4] <= 1'b1;
            endcase
            if ((!l_alu[3]) && (l_size == 2'b01)) begin
              r_z_flg <= w_zero[0] & w_zero[1];
            end
        end
    end
    assign cc_out = r_cc_out;
    // Zero flag from word result
    assign z_flg = w_zero[0] & w_zero[1];
    // Greater than from adder : not((V xor N) or Z)
    assign g_flg = ~((v_flg[1] ^ l_res[15]) | (w_zero[0] & w_zero[1]));

    // Carry input control
    // 0000 : keep       : KEEP
    // 0001 : 0          : CLR
    // 0010 : c_flg[1]   : C_ADD
    // 0011 : w_c_flg    : C_FLG
    // 0100 : X flag     : X_SR
    // 0101 : result[7]  : N_B
    // 0110 : result[15] : N_W
    // 0111 : N flag     : N_SR
    // 1000 : a_src[0]   : T0
    // 1001 : a_src[7]   : T7
    // 1010 : a_src[15]  : T15
    // 1100 : b_src[0]   : N0
    // 1101 : b_src[7]   : N7
    // 1110 : b_src[15]  : N15
    always@(posedge rst or posedge clk) begin : CARRY_INPUT
    
        if (rst) begin
            r_c_in <= 1'b0;
        end
        else if (clk_ena) begin
            case (cin_c)
                4'b0000 : r_c_in <= r_c_in;      // Keep flag
                4'b0001 : r_c_in <= 1'b0;        // For ASL, LSL, LSR
                4'b0010 : r_c_in <= c_flg[1];    // For ADD.L, SUB.L
                4'b0011 : r_c_in <= w_c_flg;     // For ADDX, SUBX, ROXL, ROXR
                4'b0100 : r_c_in <= r_cc_out[4]; // X flag
                4'b0101 : r_c_in <= l_res[7];    // For EXT.W
                4'b0110 : r_c_in <= l_res[15];   // For EXT.L
                4'b0111 : r_c_in <= r_cc_out[3]; // N flag
                4'b1000 : r_c_in <= a_src[0];    // For ROR
                4'b1001 : r_c_in <= a_src[7];    // For ASR.B, ROL.B
                4'b1010 : r_c_in <= a_src[15];   // For ASR.W, ROL.W
                4'b1100 : r_c_in <= b_src[0];    // For ROR.B, ROR.W
                4'b1101 : r_c_in <= b_src[7];    // For ASR.B, ROL.B
                4'b1110 : r_c_in <= b_src[15];   // For ASR.W, ASR.L, ROL.W, ROL.L
                default : r_c_in <= 1'b0;
            endcase
        end
    end
    assign c_in = r_c_in;

endmodule
