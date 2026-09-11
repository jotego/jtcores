/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Conformance test for jt32010, in the layout simunit.sh expects.
 *
 * init.go builds the C reference model from ref32010.c and produces, for each
 * case, a random program image and the trace the reference produces from it.
 * This bench runs the same program through the RTL and compares machine state
 * instruction by instruction. The number of instructions is whatever the
 * reference trace holds, so only init.go decides how long a case runs.
 *
 * The two inputs the DSP cannot derive on its own are driven from the
 * instruction count, so that both models see identical stimulus:
 *   BIO      = (instruction index) & 1
 *   IN ports = 0x1234 + n*0x5678, n counting the IN instructions executed
 *
 * HOLD is the exception: the reference model has no notion of it, so whatever
 * pattern it takes the trace has to come out unchanged. Cases 4 and 5 hold the
 * core for part of every clock to prove that.
 */
`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

// Each case is one simulation, selected by the macro simunit.sh passes in.
// seed and interrupt period must agree with the table in init.go.
`ifdef CASE0
    localparam IRQP=0,  HOLDP=0;
    localparam string PROG="prog0.hex", REF="ref0.trace";
`elsif CASE1
    localparam IRQP=97, HOLDP=0;
    localparam string PROG="prog1.hex", REF="ref1.trace";
`elsif CASE2
    localparam IRQP=23, HOLDP=0;
    localparam string PROG="prog2.hex", REF="ref2.trace";
`elsif CASE3
    localparam IRQP=7,  HOLDP=0;
    localparam string PROG="prog3.hex", REF="ref3.trace";
`elsif CASE4
    localparam IRQP=97, HOLDP=35;
    localparam string PROG="prog4.hex", REF="ref4.trace";
`elsif CASE5
    localparam IRQP=0,  HOLDP=80;
    localparam string PROG="prog5.hex", REF="ref5.trace";
`else
    localparam IRQP=0,  HOLDP=0;
    localparam string PROG="prog0.hex", REF="ref0.trace";
`endif

reg         clk=0, rst=1;
wire        cen=1'b1;
reg         hold=0;
reg  [31:0] rseed=32'd1;
wire        irq;

wire [11:0] rom_addr;
reg  [15:0] rom_data;
wire [ 2:0] pa;
wire [15:0] pdout;
wire        pwr, prd;

wire        dbg_fetch;
wire [11:0] dbg_pc;
wire [15:0] dbg_ir, dbg_str, dbg_treg, dbg_ar0, dbg_ar1;
wire [31:0] dbg_acc, dbg_preg;
wire [11:0] dbg_stk0, dbg_stk1, dbg_stk2, dbg_stk3;

reg  [15:0] rom[0:4095];
reg  [31:0] icnt=0, in_seq=0, clkcnt=0;
reg         bio_r=0, prd_d=0;
integer     fh, got;

// one reference line
reg [11:0] r_pc, r_stk0, r_stk1, r_stk2, r_stk3;
reg [15:0] r_ir, r_treg, r_ar0, r_ar1, r_str;
reg [31:0] r_acc, r_preg;

always #5 clk = ~clk;

initial begin
    $readmemh( PROG, rom );
    fh = $fopen( REF, "r" );
    if( fh==0 ) begin
        $display("cannot open %s - did init.go run?", REF);
        $finish;
    end
    #20 rst = 0;
end

// HALT pattern. Held for HOLDP percent of clocks; must not change the trace.
always @(posedge clk) begin
    if( HOLDP != 0 ) hold <= ({$random(rseed)} % 100) < HOLDP;
end

// program memory: one clock of latency, frozen while the core is held
always @(posedge clk) if( cen && !hold ) begin
    rom_data <= rom[rom_addr];
    clkcnt   <= clkcnt + 1;
end

// Asserting during the fetch phase of instruction N sets the pending latch in
// time for the vector to be taken before instruction N+1, which is where the
// reference model raises it too.
assign irq = (IRQP != 0) && dbg_fetch && ((icnt % IRQP) == 32'd13);

always @(posedge clk) if( dbg_fetch ) begin
    bio_r <= icnt[0];
    icnt  <= icnt + 1;
end

// IN port sequence. The core samples pdin one phase after prd, so the value
// advances one phase later still. This is a continuous assignment rather than
// an always @* block: under -g2012 Icarus does not evaluate always @* at time
// zero, which would leave pdin at X until the first IN instruction.
always @(posedge clk) if( cen && !hold ) begin
    prd_d <= prd;
    if( prd_d ) in_seq <= in_seq + 1;
end
wire [15:0] pdin = 16'h1234 + in_seq[15:0]*16'h5678;

// Compare against the reference before each instruction executes. Running out
// of reference lines is how a case ends.
always @(posedge clk) if( !rst && dbg_fetch ) begin
    got = $fscanf(fh, "%h %h %h %h %h %h %h %h %h %h %h %h",
        r_pc, r_ir, r_acc, r_preg, r_treg, r_ar0, r_ar1, r_str,
        r_stk0, r_stk1, r_stk2, r_stk3);
    if( got != 12 ) begin
        $fclose(fh);
        $display("jt32010: %0d instructions matched, %0d clocks, hold=%0d%% irq=%0d",
                 icnt, clkcnt, HOLDP, IRQP);
        pass();
    end else if( {r_pc, r_ir, r_acc, r_preg, r_treg, r_ar0, r_ar1, r_str,
                  r_stk0, r_stk1, r_stk2, r_stk3} !==
                 {dbg_pc, rom_data, dbg_acc, dbg_preg, dbg_treg, dbg_ar0,
                  dbg_ar1, dbg_str, dbg_stk0, dbg_stk1, dbg_stk2, dbg_stk3} ) begin
        $display("jt32010 mismatch at instruction %0d (hold=%0d%% irq=%0d)", icnt, HOLDP, IRQP);
        $display("  ref pc=%03X ir=%04X acc=%08X p=%08X t=%04X ar0=%04X ar1=%04X st=%04X stk=%03X %03X %03X %03X",
            r_pc, r_ir, r_acc, r_preg, r_treg, r_ar0, r_ar1, r_str, r_stk0, r_stk1, r_stk2, r_stk3);
        $display("  rtl pc=%03X ir=%04X acc=%08X p=%08X t=%04X ar0=%04X ar1=%04X st=%04X stk=%03X %03X %03X %03X",
            dbg_pc, rom_data, dbg_acc, dbg_preg, dbg_treg, dbg_ar0, dbg_ar1, dbg_str,
            dbg_stk0, dbg_stk1, dbg_stk2, dbg_stk3);
        fail();
    end
end

jt32010 uut(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .cen      ( cen       ),
    .hold     ( hold      ),
    .irq      ( irq       ),
    .bio      ( bio_r     ),
    .rom_addr ( rom_addr  ),
    .rom_data ( rom_data  ),
    .pa       ( pa        ),
    .pdout    ( pdout     ),
    .pdin     ( pdin      ),
    .pwr      ( pwr       ),
    .prd      ( prd       ),
    .dbg_fetch( dbg_fetch ),
    .dbg_pc   ( dbg_pc    ),
    .dbg_ir   ( dbg_ir    ),
    .dbg_str  ( dbg_str   ),
    .dbg_acc  ( dbg_acc   ),
    .dbg_preg ( dbg_preg  ),
    .dbg_treg ( dbg_treg  ),
    .dbg_ar0  ( dbg_ar0   ),
    .dbg_ar1  ( dbg_ar1   ),
    .dbg_stk0 ( dbg_stk0  ),
    .dbg_stk1 ( dbg_stk1  ),
    .dbg_stk2 ( dbg_stk2  ),
    .dbg_stk3 ( dbg_stk3  )
);

initial begin
    #50_000_000;
    $display("jt32010: TIMEOUT");
    $finish;
end

endmodule
