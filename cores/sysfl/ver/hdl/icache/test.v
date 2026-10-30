/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst_n=0, req=0, inval=0, snoop=0;
reg [31:2] addr=0, snoop_addr=0;
wire [31:0] data, bus_addr;
wire [31:2] vaddr;
wire valid, busy, bus_req;
reg [31:0] memory[0:1023];
integer waitcnt=4, reads=0, checks=0, i, before_reads;
wire ack=bus_req && waitcnt==0 && !snoop;
always #5 clk=~clk;

jt960_icache #(
    .LINES ( 8 )
) uut(
    .clk         ( clk                    ),
    .rst_n       ( rst_n                  ),
    .snoop       ( snoop                  ),
    .snoop_addr  ( snoop_addr             ),
    .inval       ( inval                  ),
    .req         ( req                    ),
    .req_demand  ( 1'b1                   ),
    .addr        ( addr                   ),
    .data        ( data                   ),
    .vaddr       ( vaddr                  ),
    .valid       ( valid                  ),
    .busy        ( busy                   ),
    .bus_req     ( bus_req                ),
    .bus_addr    ( bus_addr               ),
    .bus_rdata   ( memory[bus_addr[11:2]] ),
    .bus_ack     ( ack                    )
);

always @(posedge clk) begin
    if(!rst_n) begin waitcnt<=4; reads<=0; end
    else if(bus_req) begin
        if(ack) begin waitcnt<=4+($unsigned($random)%8); reads<=reads+1; end
        else if(waitcnt>0) waitcnt<=waitcnt-1;
    end
    if(rst_n && valid && !snoop) begin
        if(data!==memory[vaddr[11:2]]) $fatal(1,"stale fetch %h got=%h expected=%h",{vaddr,2'b0},data,memory[vaddr[11:2]]);
        checks<=checks+1;
    end
end

task fetch_word(input [31:0] address);
    integer cycles;
begin
    @(negedge clk); addr=address[31:2]; req=1;
    @(posedge clk); #1;
    @(negedge clk); req=0;
    cycles=0;
    while(!(valid && vaddr==address[31:2]) && cycles<300) begin
        @(posedge clk); #1; cycles=cycles+1;
    end
    if(cycles==300 || data!==memory[address[11:2]]) $fatal(1,"fetch failed %h",address);
end
endtask

task drain;
    integer cycles;
begin
    cycles=0;
    while(busy && cycles<300) begin @(posedge clk); #1; cycles=cycles+1; end
    if(busy) $fatal(1,"fill failed to finish");
end
endtask

initial begin
    for(i=0;i<1024;i=i+1) memory[i]=32'h12345678^(i*32'h01010101);
    repeat(3) @(negedge clk);
    rst_n=1; drain;
    fetch_word(32'h28);
    if(reads!=1 || !busy) $fatal(1,"critical word did not restart early");
    drain;
    if(reads!=4) $fatal(1,"line refill is not four words");
    before_reads=reads;
    fetch_word(32'h20); fetch_word(32'h24); fetch_word(32'h2c);
    if(reads!=before_reads) $fatal(1,"filled line missed");
    fetch_word(32'h44);
    before_reads=reads;
    fetch_word(32'h28);
    if(!busy || reads!=before_reads) $fatal(1,"hit blocked behind refill");
    drain;
    @(negedge clk); snoop=1; snoop_addr=30'h8; memory[8]=32'h87654321;
    @(negedge clk); snoop=0;
    before_reads=reads; fetch_word(32'h20);
    if(reads==before_reads || data!==32'h87654321) $fatal(1,"write did not invalidate line");
    drain;
    fetch_word(32'h68);
    @(negedge clk); snoop=1; snoop_addr=30'h1a; memory[26]=32'habcdef01;
    @(negedge clk); snoop=0;
    fetch_word(32'h68); drain;
    for(i=0;i<500;i=i+1) begin
        fetch_word(($unsigned($random)%1024)*4);
    end
    drain;
    for(i=0;i<8;i=i+1) begin fetch_word(i*16); drain; end
    @(negedge clk); inval=1; memory[0]=32'h11223344;
    @(negedge clk); inval=0; snoop=1; snoop_addr=30'h1c;
    @(negedge clk); snoop=0;
    drain;
    before_reads=reads; fetch_word(32'h0);
    if(reads==before_reads || data!==32'h11223344) $fatal(1,"full invalidation retained a line");
    drain;
    $display("PASS: critical word first, hit under fill, write invalidation, refill cancellation, %0d transparent answers",checks);
    $finish;
end
initial begin
    #10000000;
    $fatal(1,"timeout");
end
endmodule
