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

module j68_loop
(
    // Clock and reset
    input             rst,     // CPU reset
    input             clk,     // CPU clock
    /* direct_enable = 1 */ input clk_ena, // CPU clock enable
    // Loop control
    input      [19:0] inst_in,
    input             i_fetch, // Instruction fetch
    input      [5:0]  a_src,   // A source
    input      [10:0] pc_in,   // PC input
    output     [10:0] pc_out,  // PC output
    output            branch,  // Loop taken
    output            skip,    // Loop skipped
    output      [3:0] lcount   // Loop count for MOVEM
);

    reg [10:0] r_loop_st;  // Loop start PC
    reg [10:0] r_loop_end; // Loop end PC
    reg  [5:0] r_loop_cnt; // Loop count
    reg        r_loop_ena; // Loop enable
    reg        r_branch;   // Loop taken
    reg  [3:0] r_lcount;   // Loop count for MOVEM

    always @(posedge rst or posedge clk) begin : HW_LOOP
    
        if (rst) begin
            r_loop_st   = 11'd0;
            r_loop_end  = 11'd0;
            r_loop_cnt  = 6'd0;
            r_loop_ena  = 1'b0;
            r_branch   <= 1'b0;
            r_lcount   <= 4'd0;
        end
        else if (clk_ena) begin
            // "LOOP" instruction is executed
            if (inst_in[19:17] == 3'b000) begin
                // Store current PC (start of loop)
                r_loop_st  = pc_in;
                // Store address field (end of loop)
                r_loop_end = inst_in[10:0];
                if (inst_in[11]) begin
                    // "LOOPT"
                    r_loop_cnt = a_src[5:0] - 6'd1;
                    // Skipped if T = 0
                    r_loop_ena = ~skip;
                end
                else begin
                    // "LOOP16"
                    r_loop_cnt = 6'd15;
                    // Always executed
                    r_loop_ena = 1'b1;
                end
            end
            // Loop count for MOVEM
            r_lcount <= r_loop_cnt[3:0];
            
            if (r_loop_ena) begin
                if (i_fetch) begin
                    // End of loop reached
                    if (r_loop_end == pc_in) begin
                        if (r_loop_cnt == 6'd0) begin
                            // Loop count = 0 : exit loop
                            r_branch   <= 1'b0;
                            r_loop_ena  = 1'b0;
                        end
                        else begin
                            // Loop count > 0 : go on
                            r_branch   <= 1'b1;
                            r_loop_cnt  = r_loop_cnt - 6'd1;
                        end
                    end
                    else begin
                        r_branch <= 1'b0;
                    end
                end
            end
            else begin
                r_branch <= 1'b0;
            end
        end
    end
  
    assign branch = r_branch;
    assign lcount = r_lcount;
    // Loop start PC value
    assign pc_out = r_loop_st;
    // Loop skipped when T is null and "LOOPT" instruction
    assign skip   = (a_src[5:0] == 6'd0) ? inst_in[11] : 1'b0;

endmodule
