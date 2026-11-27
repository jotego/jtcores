/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-10-2026 */

module test;
reg [15:0] addr;
reg mreq_n, iorq_n, m1_n, rfsh_n, rd_n, wr_n;
wire rom_cs, shared_cs, vram_cs, color_cs, obj0_cs, obj1_cs, scroll_cs;
wire in0_cs, in1_cs, test_cs, watchdog_clr, ay_bdir, ay_bc1;
reg mem, io, ayw, ayr;
reg [12:0] expected;
integer a, mode;

jtseicro_decode dut(
    .*
);

initial begin
    for(mode=0;mode<64;mode=mode+1) begin
        {mreq_n,iorq_n,m1_n,rfsh_n,rd_n,wr_n}=mode[5:0];
        for(a=0;a<65536;a=a+1) begin
            addr=a[15:0];
            mem=!mreq_n && rfsh_n;
            io=!iorq_n && m1_n;
            ayw=io && !wr_n && (a%256==0 || a%256==1 || a%256==8 || a%256==9);
            ayr=io && !rd_n && (a%256==4 || a%256==12);
            expected={
                mem && !rd_n && a<=16'h77ff,
                mem && a>=16'h7800 && a<=16'h7fff,
                mem && a>=16'h9000 && a<=16'h93ff,
                mem && a>=16'h9c00 && a<=16'h9fff,
                mem && a>=16'h8820 && a<=16'h887f,
                mem && !wr_n && a>=16'h9880 && a<=16'h989f,
                mem && a>=16'h9800 && a<=16'h981f,
                mem && !rd_n && a==16'ha000,
                mem && !rd_n && a==16'ha800,
                mem && !rd_n && a==16'hb000,
                mem && !rd_n && a==16'hb800,
                ayw, (ayw && a%2==0) || ayr
            };
            #1;
            if({rom_cs,shared_cs,vram_cs,color_cs,obj0_cs,obj1_cs,scroll_cs,
                in0_cs,in1_cs,test_cs,watchdog_clr,ay_bdir,ay_bc1} !== expected)
                $fatal(1,"decode addr=%h mode=%d",addr,mode);
        end
    end
    $display("PASS decode: 65536 addresses x 64 bus modes");
    $finish;
end
endmodule
