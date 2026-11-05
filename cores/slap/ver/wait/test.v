/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1, pxl_cen=1, flip=0, fix_cs=0, scr_cs=0;
reg [8:0] hdump=0, scrx=0;
wire wait_n;
integer phase, scroll, flipped, layer, cycles, edges;
reg previous, current;
always #5 clk=~clk;
jtslap_wait uut(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .hdump(hdump), .scrx(scrx), .flip(flip),
    .fix_cs(fix_cs), .scr_cs(scr_cs), .wait_n(wait_n)
);
task step;
    begin
        @(negedge clk);
        hdump=hdump+9'd1;
        @(posedge clk); #1;
    end
endtask
task check;
    input condition;
    input [255:0] message;
    begin
        if(!condition) begin $display("FAIL: %s",message); $finish; end
    end
endtask
initial begin
    $dumpfile("test.lxt"); $dumpvars;
    repeat(3) step(); rst=0;
    for(flipped=0;flipped<2;flipped=flipped+1)
    for(scroll=0;scroll<8;scroll=scroll+1)
    for(phase=0;phase<8;phase=phase+1)
    for(layer=0;layer<2;layer=layer+1) begin
        @(negedge clk);
        flip=flipped!=0; scrx=scroll; hdump=phase;
        fix_cs=0; scr_cs=0;
        repeat(4) begin @(posedge clk); #1; @(negedge clk); end
        check(wait_n,"inactive access must release wait");
        previous=layer==0 ? (~hdump[2]^flip) : (~((hdump+scrx)>>2)&1)^flip;
        fix_cs=layer==0; scr_cs=layer==1;
        #1; check(!wait_n,"access must assert wait");
        edges=0; cycles=0;
        while(!wait_n && cycles<22) begin
            step();
            current=layer==0 ? (~hdump[2]^flip) : (~((hdump+scrx)>>2)&1)^flip;
            if(previous && !current) edges=edges+1;
            previous=current; cycles=cycles+1;
            if(edges<2) check(!wait_n,"wait released before two edges");
        end
        check(wait_n,"access must finish within 22 pixels");
        check(edges==2,"access must use exactly two edges");
        @(negedge clk); fix_cs=0; scr_cs=0;
        #1; check(wait_n,"deasserting select must release wait");
    end
    $display("PASS: foreground/background waits, all phases, scroll and flip");
    $finish;
end
initial begin #1000000; $display("FAIL: timeout"); $finish; end
endmodule
