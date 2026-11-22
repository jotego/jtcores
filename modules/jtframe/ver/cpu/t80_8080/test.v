/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-11-2026 */

`timescale 1ns/1ps

module test;

reg clk = 0;
always #5 clk = ~clk;

reg reset_n = 0;
reg [7:0] mem [0:65535];
wire [15:0] addr;
wire [7:0] dout;
wire mreq_n, iorq_n, rd_n, wr_n, halt_n;
wire [7:0] din = iorq_n ? mem[addr] : 8'ha5;
reg seen_in = 0;
reg seen_out = 0;

T8080s uut(
    .RESET_n( reset_n ),
    .CLK    ( clk     ),
    .CEN    ( 1'b1    ),
    .WAIT_n ( 1'b1    ),
    .INT_n  ( 1'b1    ),
    .NMI_n  ( 1'b1    ),
    .BUSRQ_n( 1'b1    ),
    .OUT0   ( 1'b0    ),
    .DI     ( din     ),
    .M1_n   (         ),
    .MREQ_n ( mreq_n  ),
    .IORQ_n ( iorq_n  ),
    .RD_n   ( rd_n    ),
    .WR_n   ( wr_n    ),
    .RFSH_n (         ),
    .HALT_n ( halt_n  ),
    .BUSAK_n(         ),
    .A      ( addr    ),
    .DOUT   ( dout    )
);

initial begin
    mem[0] = 8'h3e; mem[1] = 8'h5a;                  // MVI A,5Ah
    mem[2] = 8'h32; mem[3] = 8'h00; mem[4] = 8'h20; // STA 2000h
    mem[5] = 8'hdb; mem[6] = 8'h10;                  // IN  10h
    mem[7] = 8'hd3; mem[8] = 8'h11;                  // OUT 11h
    mem[9] = 8'h76;                                  // HLT
    repeat (8) @(negedge clk);
    reset_n = 1;
    repeat (1000) @(negedge clk);
    $fatal(1, "8080 program timed out");
end

always @(posedge clk) begin
    if (reset_n) begin
        if (!mreq_n && !wr_n) mem[addr] <= dout;
        if (!iorq_n && !rd_n) begin
            if (addr !== 16'h1010) $fatal(1, "8080 IN address %h", addr);
            seen_in <= 1;
        end
        if (!iorq_n && !wr_n) begin
            if (addr !== 16'h1111 || dout !== 8'ha5)
                $fatal(1, "8080 OUT address %h data %h", addr, dout);
            seen_out <= 1;
        end
        if (!halt_n) begin
            if (mem[16'h2000] !== 8'h5a || !seen_in || !seen_out)
                $fatal(1, "8080 RAM write or I/O cycle missing");
            $display("PASS");
            $finish;
        end
    end
end

endmodule
