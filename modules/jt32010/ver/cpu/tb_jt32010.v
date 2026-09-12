/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Conformance bench for jt32010. Runs a program image and prints one line of
 * machine state per instruction, in the same format as ref32010.c, so the two
 * traces can be diffed directly.
 *
 * The two inputs the DSP cannot derive on its own are driven from the
 * instruction count so that both models see identical stimulus:
 *   BIO      = (instruction index) & 1
 *   IN ports = 0x1234 + n*0x5678, n counting the IN instructions executed
 */
`timescale 1ns/1ps

module tb_jt32010;

reg         clk = 0, rst = 1;
wire        cen = 1'b1;
reg         hold = 0;
reg  [31:0] holdp;
reg  [31:0] rseed;
reg  [31:0] clkcnt = 0;
wire        irq;
reg  [31:0] irqp;

wire [11:0] rom_addr;
reg  [15:0] rom_data;
wire [ 2:0] pa;
wire [15:0] pdout;
reg  [15:0] pdin;
wire        pwr, prd;

wire        dbg_fetch;
wire [11:0] dbg_pc;
wire [15:0] dbg_ir, dbg_str, dbg_treg, dbg_ar0, dbg_ar1;
wire [31:0] dbg_acc, dbg_preg;
wire [11:0] dbg_stk0, dbg_stk1, dbg_stk2, dbg_stk3;

reg  [15:0] rom[0:4095];
reg  [31:0] icnt = 0, in_seq = 0, maxi;
reg         bio_r = 0;
reg         prd_d = 0;
integer     fh;

reg [255:0] progfile;

initial begin
    if( !$value$plusargs("prog=%s", progfile) ) progfile = "prog.hex";
    if( !$value$plusargs("steps=%d", maxi)    ) maxi = 20000;
    if( !$value$plusargs("irq=%d",   irqp)    ) irqp = 0;
    if( !$value$plusargs("hold=%d",  holdp)   ) holdp = 0;
    if( !$value$plusargs("seed=%d",  rseed)   ) rseed = 1;
    $readmemh( progfile, rom );
    fh = $fopen("rtl.trace", "w");
    #20 rst = 0;
end

always #5 clk = ~clk;

// The HALT input must be invisible in the result: whatever pattern it takes,
// the instruction trace has to come out identical. `holdp` is the percentage
// of clocks the core is held.
always @(posedge clk) begin
    if( holdp != 0 ) hold <= (($random(rseed) % 100) < 0) ? 1'b0 :
                             (($random(rseed) % 100) < holdp);
end

// program memory: one clock of latency, frozen while the core is held
always @(posedge clk) if( cen && !hold ) begin
    rom_data <= rom[rom_addr];
    clkcnt   <= clkcnt + 1;
end

// Interrupt schedule. Asserting during the fetch phase of instruction N sets
// the pending latch in time for the vector to be taken before instruction N+1,
// which is where the reference model raises it too.
assign irq = (irqp != 0) && dbg_fetch && ((icnt % irqp) == 32'd13);

// BIO follows the instruction index
always @(posedge clk) begin
    if( dbg_fetch ) begin
        bio_r <= icnt[0];
        icnt  <= icnt + 1;
    end
end

// IN port sequence. The core samples pdin one phase after prd, so the value is
// advanced one phase later still.
always @(posedge clk) if( cen && !hold ) begin
    prd_d <= prd;
    if( prd_d ) in_seq <= in_seq + 1;
end
always @* pdin = 16'h1234 + in_seq[15:0]*16'h5678;

// trace, printed before each instruction executes
always @(posedge clk) begin
    if( dbg_fetch ) begin
        $fdisplay(fh, "%03X %04X %08X %08X %04X %04X %04X %04X %03X %03X %03X %03X",
            dbg_pc, rom_data, dbg_acc, dbg_preg, dbg_treg, dbg_ar0, dbg_ar1,
            dbg_str, dbg_stk0, dbg_stk1, dbg_stk2, dbg_stk3);
        if( icnt+1 >= maxi ) begin
            $fclose(fh);
            $display("tb_jt32010: %0d instructions traced, %0d clocks", icnt, clkcnt);
            $finish;
        end
    end
end

jt32010 u_dut(
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
    $display("tb_jt32010: TIMEOUT");
    $finish;
end

endmodule
