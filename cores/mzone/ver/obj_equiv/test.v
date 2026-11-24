// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
module test;
wire pipeline_done;
reg clk=0,rst=1,cen2=0,pxl_cen=0,hs=0,flip=0,draw=0,hflip=0;
object_pipeline pipeline(clk,pipeline_done);
always #5 clk=~clk;
always @(posedge clk) cen2<=!cen2;
reg [8:0] h=350,xpos=0;
reg [7:0] code=0,prog_addr=0;
reg [3:0] pal=0,row=0,prog_data=0;
reg prog_en=0;
reg [15:0] latency=0;
wire busy,ref_busy,cs,ref_cs,ok,ref_ok;
wire [12:0] addr,ref_addr;
wire [31:0] data,ref_data;
wire [3:0] pxl,ref_pxl;
`include "patterns.vh"
object_rom rom(clk,rst,cs,addr,latency,data,ok);
object_rom ref_rom(clk,rst,ref_cs,ref_addr,latency,ref_data,ref_ok);
jtmzone_objdraw dut(
 .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.HS(hs),.hdump(h),.flip(flip),
 .draw(draw),.busy(busy),.code(code),.xpos(xpos),.pal(pal),.hflip(hflip),.ysub(row),
 .prog_data(prog_data),.prog_addr(prog_addr),.prog_en(prog_en),
 .rom_addr(addr),.rom_cs(cs),.rom_data(data),.rom_ok(ok),.pxl(pxl));
jtmzone_objdraw_reference original(
 .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.cen2(cen2),.HS(hs),.hdump(h),.flip(flip),
 .draw(draw),.busy(ref_busy),.code(code),.xpos(xpos),.pal(pal),.hflip(hflip),.ysub(row),
 .prog_data(prog_data),.prog_addr(prog_addr),.prog_en(prog_en),
 .rom_addr(ref_addr),.rom_cs(ref_cs),.rom_data(ref_data),.rom_ok(ref_ok),.pxl(ref_pxl));
reg checking=0,boundary_phase=0;
integer cycles=0,pixels=0,cases=0,wraps=0,overlaps=0,holes=0,erased=0,nonzero=0;
integer boundary_busy=0,boundary_differences=0;
reg [3:0] expected[0:511];
reg bank=0;
reg [3:0] last_pixel=0;
integer i,j,gf,hf,delay_case,row_case,period_case,period=4;
integer index,position;
reg [3:0] color;
always @(negedge clk) if(checking) begin
    cycles=cycles+1;
    if(boundary_phase && pxl!==ref_pxl) boundary_differences=boundary_differences+1;
    if(^{busy,cs}===1'bx || (cs && ^addr===1'bx))
        $fatal(1,"unknown object request control");
    if(^pxl===1'bx) $fatal(1,"unknown object output");
end
// No draw requests during this task: switch line banks exactly on HS rising.
task switch_line;
 begin
    @(negedge clk);pxl_cen=0;h=350;hs=0;
    repeat(4) @(negedge clk);
    hs=1;bank=!bank;
    if(busy) boundary_busy=boundary_busy+1;
    repeat(4) @(negedge clk);
    hs=0;
 end
endtask
// Independently composite an entire logical sprite into the write bank.
task sprite;
 input [7:0] c;
 input [8:0] x;
 input [3:0] p,y;
 input hf_input;
 begin
    @(negedge clk);h=350;code=c;xpos=x;pal=p;row=y;hflip=hf_input;draw=1;
    wait(busy && ref_busy);@(negedge clk);draw=0;
    wait(!busy && !ref_busy);repeat(8) @(negedge clk);
    for(j=0;j<16;j=j+1) begin
        position=(x+(hf_input?15-j:j))&255;
        index=(bank?256:0)+position;
        color=palette(p,pen(c,y,j));
        if(color!=0) begin
            if(expected[index]!=0) overlaps=overlaps+1;
            expected[index]=color;
        end else if(expected[index]!=0) holes=holes+1;
        if(x[7:0]+j>255) wraps=wraps+1;
    end
 end
endtask
// Hold each coordinate through the synchronous read/erase pipeline. The read
// pulses have the same 4/8-master-clock spacing as production pixel enables.
task read_line;
 integer raw,local_h,a;
 reg enabled;
 begin
    for(raw=0;raw<384;raw=raw+1) begin
        @(negedge clk);h=raw;pxl_cen=1;
        local_h=(raw-(flip?6:54))&511;
        enabled=(local_h>=510 || local_h<240);
        a=((bank?0:256)+((local_h+(flip?16:9)+1)&255));
        if(enabled) begin
            last_pixel=expected[a];
            expected[a]=0;
            if(checking) erased=erased+1;
        end
        @(negedge clk);pxl_cen=0;
        repeat(period-2) @(negedge clk);
        if(checking && ref_pxl!==last_pixel)
            $fatal(1,"frozen object reference disagrees with independent compositor");
        if(checking && pxl!==last_pixel)
            $fatal(1,"object scoreboard case=%0d h=%0d bank=%b address=%0d got=%h expected=%h",cases,raw,bank,a,pxl,last_pixel);
        if(checking) pixels=pixels+1;
        if(checking && pxl!=0) nonzero=nonzero+1;
    end
    @(negedge clk);h=350;pxl_cen=0;
 end
endtask
// Read a whole line with production-spaced enables, without an atomic
// scoreboard, to compare split-bank transactions against the frozen drawer.
task drain_line;
 integer raw;
 begin
    for(raw=0;raw<384;raw=raw+1) begin
        @(negedge clk);h=raw;pxl_cen=1;
        @(negedge clk);pxl_cen=0;
        repeat(period-2) @(negedge clk);
    end
    @(negedge clk);h=350;pxl_cen=0;
 end
endtask
initial begin
    for(i=0;i<512;i=i+1) expected[i]=0;
    for(i=0;i<256;i=i+1) begin
        @(negedge clk);prog_en=1;prog_addr=i;prog_data=palette(i[7:4],i[3:0]);
    end
    @(negedge clk);prog_en=0;rst=0;
    repeat(8) @(negedge clk);
    // Settle uninitialized output and delay registers through real reads.
    read_line;switch_line;read_line;switch_line;
    checking=1;
    for(period_case=0;period_case<2;period_case=period_case+1)
    for(gf=0;gf<2;gf=gf+1)
    for(hf=0;hf<2;hf=hf+1)
    for(delay_case=0;delay_case<4;delay_case=delay_case+1)
    for(row_case=0;row_case<4;row_case=row_case+1) begin
        period=period_case==0?4:8;flip=gf;
        case(delay_case)
            0:latency=0;1:latency=1;2:latency=9;3:latency=63;
        endcase
        // Both X bits above the physical 8-bit circular address are exercised.
        sprite(8'd2,9'd0,4'd1,row_case*5,hf);
        sprite(8'd5,9'd248,4'd3,row_case*5,hf);
        sprite(8'd7,9'd511,4'd5,row_case*5,!hf);
        sprite(8'd11,9'd256,4'd9,row_case*5,!hf);
        sprite(8'd13,9'd64,4'd2,row_case*5,hf);
        sprite(8'd17,9'd68,4'd6,row_case*5,!hf);
        sprite(8'd0,9'd68,4'd4,row_case*5,hf);
        switch_line;read_line;
        // A second presentation without drawing checks read-and-erase and
        // retention outside the finite circular interval, across both banks.
        switch_line;read_line;switch_line;read_line;
        cases=cases+1;
    end
    // Compare timing and pixels for a request pending across HS, then a
    // second HS edge during pixel writes (no atomic-sprite oracle here).
    boundary_phase=1;
    latency=400;
    @(negedge clk);h=350;code=23;xpos=240;pal=7;row=15;hflip=1;draw=1;
    wait(busy && ref_busy);@(negedge clk);draw=0;
    switch_line;
    wait(!busy && !ref_busy);repeat(8) @(negedge clk);
    drain_line;switch_line;drain_line;
    latency=3;
    @(negedge clk);h=350;code=29;xpos=64;pal=7;row=5;hflip=0;draw=1;
    wait(busy && ref_busy);@(negedge clk);draw=0;
    repeat(20) @(negedge clk);
    switch_line;
    wait(!busy && !ref_busy);repeat(8) @(negedge clk);
    drain_line;switch_line;drain_line;
    if(cases!=128 || overlaps==0 || holes==0 || wraps==0 || nonzero==0 ||
       erased==0 || rom.stalls==0 || boundary_busy==0)
        $fatal(1,"missing object coverage");
    wait(pipeline_done);
    $display("HS overrun diagnostic: %0d differing cycle samples with full-speed writes",boundary_differences);
    $display("PASS object rendering: %0d cases, %0d protocol checks, %0d pixel checks, %0d overlaps, %0d transparent holes, %0d wraps, %0d erases, %0d stalled clocks, HS while busy=%0d",cases,cycles,pixels,overlaps,holes,wraps,erased,rom.stalls,boundary_busy);
    $finish;
end
initial begin #100000000; $fatal(1,"object equivalence timeout"); end
endmodule
