/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

`timescale 1ns/1ps

module test;

localparam TI=0, T1=1, T2=2, T3=3, TW=4, T4=5;
reg         clk = 0, rst = 1;
integer     divider = 6, phase = 0, waits = 0, pending_waits = 0;
wire        cen = phase == 0;
wire        cenb = phase == divider/2;
wire        ready = pending_waits == 0;
reg         int_n = 1, nmi_n = 1;
reg         irq_sent = 0, nmi_sent = 0, reset_fetch = 0, passed = 0;
integer     nmi_count = 0, ack_cycles = 0, io_writes = 0;
reg  [ 2:0] state = TI, cycle_type = 7;
reg  [19:0] address = 0;
reg         upper_n = 1;
wire [19:0] A;
wire [15:0] din, dout;
wire [ 2:0] bs;
wire        ube_n;
reg  [ 7:0] memory [0:1048575];
integer     fd, count;

assign din = !ready ? 16'h0000 : cycle_type == 0 ? 16'h0032 : cycle_type == 1 ? 16'h5ac3
           : {memory[{address[19:1],1'b1}], memory[{address[19:1],1'b0}]};

jtframe_v30 #(
    .HEXDIR ( "../../../hdl/cpu/nuv30/" )
) u_cpu (
    .rst       ( rst           ),
    .clk       ( clk           ),
    .cen       ( cen           ),
    .cenb      ( cenb          ),
    .ready     ( ready         ),
    .int_n     ( int_n         ),
    .nmi_n     ( nmi_n         ),
    .poll_n    ( 1'b1          ),
    .A         ( A             ),
    .din       ( din           ),
    .dout      ( dout          ),
    .bs        ( bs            ),
    .qs        (               ),
    .rd_n      (               ),
    .ube_n     ( ube_n         ),
    .buslock_n (               )
);

always #5 clk = ~clk;

always @(posedge clk) begin
    phase <= phase == divider-1 ? 0 : phase+1;
    if (rst) begin
        state <= TI;
        pending_waits <= 0;
    end else begin
        if (cenb && state == T1) begin
            address <= A;
            upper_n <= ube_n;
            if (A == 20'hffff0 && cycle_type == 4) reset_fetch <= 1;
        end
        if (cen) begin
            if (state == T3 || state == TW)
                if (pending_waits > 0) pending_waits <= pending_waits-1;
            case (state)
                TI, T4: begin
                    if (bs != 7) begin
                        state <= T1;
                        cycle_type <= bs;
                        pending_waits <= waits;
                    end else state <= TI;
                end
                T1: state <= T2;
                T2: state <= T3;
                T3, TW: begin
                    state <= ready ? T4 : TW;
                    if (ready) begin
                        if (cycle_type == 6) begin
                            if (!address[0]) memory[{address[19:1],1'b0}] <= dout[7:0];
                            if (!upper_n) memory[{address[19:1],1'b1}] <= dout[15:8];
                        end
                        if (cycle_type == 2) begin
                            if (address != 20'h00080 || dout != 16'h1234)
                                $fatal(1, "wrong I/O write %h=%h", address, dout);
                            io_writes <= io_writes+1;
                        end
                        if (cycle_type == 0) begin
                            ack_cycles <= ack_cycles+1;
                            if (ack_cycles == 1) int_n <= 1;
                        end
                    end
                end
                default: $fatal(1, "invalid bus observer state");
            endcase
            if (bs == 3 && memory[20'h6002] == 1 && !irq_sent) begin
                int_n <= 0;
                irq_sent <= 1;
            end
            if (bs == 3 && memory[20'h6002] == 2 && !nmi_sent) begin
                nmi_n <= 0;
                nmi_sent <= 1;
                nmi_count <= 4;
            end else if (nmi_count > 0) begin
                nmi_count <= nmi_count-1;
                if (nmi_count == 1) nmi_n <= 1;
            end
        end
    end
end

initial begin: run_test
    count = $value$plusargs("waits=%d", waits);
    count = $value$plusargs("divider=%d", divider);
    fd = $fopen("program.bin", "rb");
    if (!fd) $fatal(1, "missing test program");
    count = $fread(memory, fd);
    $fclose(fd);
    if (count != 1048576) $fatal(1, "short test program");
    repeat (divider*8) @(negedge clk);
    rst = 0;
    for (integer step = 0; step < 200000 && !passed; step = step+1) begin
        @(negedge clk);
        if ({memory[20'h6001],memory[20'h6000]} == 16'hdead)
            $fatal(1, "CPU program failed, waits=%0d divider=%0d", waits, divider);
        if ({memory[20'h6001],memory[20'h6000]} == 16'haa55) begin
            if (!reset_fetch || ack_cycles != 2 || io_writes != 1 ||
                memory[20'h2000] != 8'h34 || memory[20'h2001] != 8'hcd ||
                memory[20'h2002] != 8'hab || memory[20'h2003] != 8'h5a ||
                memory[20'h2010] != 8'h08 || memory[20'h2012] != 8'h88 ||
                memory[20'h6004] != 1 || memory[20'h6006] != 1 || memory[20'h6008] != 1)
                $fatal(1, "CPU coverage incomplete");
            $display("PASS waits=%0d divider=%0d: reset, aligned/odd/byte memory, NEC SET1, I/O, INT/IRET, IRQ/NMI, HALT wake", waits, divider);
            passed = 1;
        end
    end
    if (!passed)
        $fatal(1, "CPU timeout A=%h BS=%b phase=%0d type=%0d marker=%h, irq=%0d nmi=%0d sw=%0d",
               A, bs, state, cycle_type, memory[20'h6002], memory[20'h6004], memory[20'h6006], memory[20'h6008]);
    $finish;
end

endmodule
