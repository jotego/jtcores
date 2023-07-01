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

module j68_addsub_32
(
    input         add_sub,
    input  [31:0] dataa,
    input  [31:0] datab,
    output        cout,
    output [31:0] result
);

//`ifdef verilator3

    // Testbench
    wire [32:0] w_result;

    assign w_result = (add_sub) ? { 1'b0, dataa } + { 1'b0, datab }
                                : { 1'b0, dataa } - { 1'b0, datab };

    assign cout   = ~w_result[32];
    assign result = w_result[31:0];
/*
`else

    // Synthesis
    lpm_add_sub
    #(
        .lpm_direction      ("UNUSED"),
        .lpm_hint           ("ONE_INPUT_IS_CONSTANT=NO,CIN_USED=NO"),
        .lpm_representation ("UNSIGNED"),
        .lpm_type           ("LPM_ADD_SUB"),
        .lpm_width          (32)
    )
    lpm_add_sub_32
    (
        .add_sub            (add_sub),
        .dataa              (dataa),
        .datab              (datab),
        .cout               (cout),
        .result             (result)
        // synopsys translate_off
        ,
        .aclr               (),
        .cin                (),
        .clken              (),
        .clock              (),
        .overflow           ()
        // synopsys translate_on
    );

`endif
*/
endmodule
