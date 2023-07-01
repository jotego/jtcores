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

module j68_test
(
    // Micro-instruction word
    input  [19:0]     inst_in,
    // Operand input
    input  [3:0]      flg_in, // Partial flags
    input  [15:0]     sr_in,  // Status register
    input  [15:0]     a_src,  // A operand
    input  [15:0]     ea1b,   // EA #1 bitfield
    input  [15:0]     extw,   // Extension word
    // Test output
    output reg        branch  // Branch taken
);

    always@(*) begin : BRANCH_FLAG
    
        case (inst_in[15:12])
            4'b0000 : branch = inst_in[11] ^ sr_in[12]; // Address error
            4'b0001 : branch = inst_in[11] ^ flg_in[1]; // Z_FLG : Partial zero (for CHK, Bcc and DBcc)
            4'b0010 : branch = inst_in[11] ^ flg_in[2]; // N_FLG : Partial negative (for MULS, DIVS, ABCD and SBCD)
            4'b0011 : branch = inst_in[11] ^ flg_in[3]; // G_FLG : Greater than (for CHK)
            4'b0100 : branch = inst_in[11] ^ a_src[0];  // T[0] (for MOVEM)
            4'b0101 : branch = inst_in[11] ^ ea1b[4];   // (An)+ addressing
            4'b0110 : branch = inst_in[11] ^ ea1b[7];   // Dn/An addressing
            4'b0111 : branch = inst_in[11] ^ extw[11];  // Long/Word for d8(An,Rn)
            4'b1000 : branch = inst_in[11] ^ sr_in[1];  // V flag
            4'b1001 : branch = inst_in[11] ^ sr_in[3];  // N flag
            4'b1010 : branch = inst_in[11] ^ sr_in[5];  // Branch flag (for DBcc and Bcc)
            4'b1011 : branch = inst_in[11] ^ sr_in[11]; // Interrupt flag
            4'b1100 : branch = inst_in[11] ^ sr_in[13]; // Supervisor flag
            4'b1101 : branch = inst_in[11] ^ sr_in[15]; // Trace flag
            default : branch = 1'b1;                    // Always
        endcase
    end

endmodule
