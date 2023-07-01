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

module j68_decode_rom
(
    input         clock,
    input   [7:0] address,
    output [35:0] q
);
    parameter USE_CLK_ENA = 0;

    // Testbench
    reg  [35:0] r_mem_blk [0:255];
    reg  [35:0] r_q;

    initial begin
        if (USE_CLK_ENA)
            $readmemb("j68_dec_c.mem", r_mem_blk);
        else
            $readmemb("j68_dec.mem", r_mem_blk);
    end

    always@(posedge clock) begin : READ_PORT
        r_q <= r_mem_blk[address];
    end

    assign q = r_q;

endmodule
