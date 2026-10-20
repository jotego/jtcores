/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

`timescale 1ns/1ps
module decode_tb;
reg [19:0] addr;
reg rd, wr;
wire [12:0] cs;
reg [12:0] expected;
integer low_addr [0:12];
integer high_addr [0:12];
reg [12:0] readable = 13'b1111100011011;
reg [12:0] writable = 13'b0111111110111;

jtroundu_decode u_decode (
    .addr ( addr ),
    .rd   ( rd   ),
    .wr   ( wr   ),
    .cs   ( cs   )
);

initial begin
    low_addr[0]='h00000; high_addr[0]='h07fff;
    low_addr[1]='h08000; high_addr[1]='h0bfff;
    low_addr[2]='h0c000; high_addr[2]='h0c003;
    low_addr[3]='h0d000; high_addr[3]='h0d001;
    low_addr[4]='h0d400; high_addr[4]='h0d40f;
    low_addr[5]='h0d800; high_addr[5]='h0d801;
    low_addr[6]='h0dc00; high_addr[6]='h0dc01;
    low_addr[7]='h0e000; high_addr[7]='h0e001;
    low_addr[8]='h0f000; high_addr[8]='h0ffff;
    low_addr[9]='h10000; high_addr[9]='h1ffff;
    low_addr[10]='h20000; high_addr[10]='h2ffff;
    low_addr[11]='h30000; high_addr[11]='h3ffff;
    low_addr[12]='h80000; high_addr[12]='hfffff;
    for (integer mode=0;mode<3;mode=mode+1) begin
        rd = mode == 1;
        wr = mode == 2;
        for (integer a=0;a<1048576;a=a+1) begin
            addr = a;
            for (integer n=0;n<13;n=n+1)
                expected[n] = a >= low_addr[n] && a <= high_addr[n]
                            && ((rd && readable[n]) || (wr && writable[n]));
            #1;
            if (cs !== expected) $fatal(1,"decode mode=%0d addr=%h got=%h expected=%h",mode,addr,cs,expected);
        end
    end
    $display("PASS: all 1048576 V30 addresses, idle/read/write permissions");
    $finish;
end
endmodule
