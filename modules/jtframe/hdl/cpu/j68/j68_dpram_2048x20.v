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

// Testbench
module j68_dpram_2048x20
(
    // Clock
    input         clock,
    input         clocken,
    // Port A : micro-instruction fetch
    input         rden_a,
    input  [10:0] address_a,
    output reg [19:0] q_a,
    // Port B : m68k registers read/write
    input   [1:0] wren_b,
    input  [10:0] address_b,
    input  [15:0] data_b,
    output reg [15:0] q_b
);
    parameter RAM_INIT_FILE = "j68_ram.mem";

    // Inferred block RAM
    reg  [19:0] r_mem_blk [0:2047];

    initial begin
        $readmemb(RAM_INIT_FILE, r_mem_blk);
    end

    // Port A (read only)
    always@(posedge clock) begin : PORT_A
        if (rden_a & clocken) begin
            q_a <= r_mem_blk[address_a];
        end
    end

    // Port B (read/write)
    always@(posedge clock) begin : PORT_B

        if (clocken) begin
            q_b <= r_mem_blk[address_b][15:0];
            if (wren_b[0]) begin
                r_mem_blk[address_b][7:0]  <= data_b[7:0];
            end
            if (wren_b[1]) begin
                r_mem_blk[address_b][15:8] <= data_b[15:8];
            end
        end
    end

endmodule
