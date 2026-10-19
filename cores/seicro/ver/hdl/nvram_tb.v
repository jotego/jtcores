/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-10-2026 */

module nvram_tb;
parameter NSC=0;
reg clk=0, rst=1, run=0, reset_req=0, dip_pause=1, nvram_en=1;
reg [5:0] cnt=0;
wire cen=cnt[3:0]==0;
wire [14:0] rom_addr;
wire rom_cs, shared_we, nvram_we;
wire [10:0] shared_addr;
wire [7:0] shared_din, nvram_addr, nvram_din, debug_view;
reg [7:0] rom_data, shared_dout, nvram_dout;
reg [7:0] rom[0:32767], shared[0:2047], battery[0:255];
wire [3:0] dac;
wire rom_ok=cnt>=8;
integer i, p=0, loop_start, writes=0;

always #5 clk=~clk;
always @(posedge clk) begin
    cnt<=cnt+6'd1;
    rom_data<=rom[rom_addr];
    shared_dout<=shared[shared_addr];
    nvram_dout<=battery[nvram_addr];
    if(shared_we) shared[shared_addr]<=shared_din;
    if(nvram_we) begin
        battery[nvram_addr]<=nvram_din;
        writes<=writes+1;
    end
end

jtseicro_mcu dut(
    .rst         ( rst         ),
    .cpu_rst     ( rst         ),
    .clk         ( clk         ),
    .cen         ( cen         ),
    .release_clk ( cnt[5]      ),
    .run         ( run         ),
    .reset_req   ( reset_req   ),
    .dip_pause   ( dip_pause   ),
    .nsc8105     ( NSC!=0      ),
    .dipsw       ( 24'hfae3f5  ),
    .nvram_en    ( nvram_en    ),
    .nvram_addr  ( nvram_addr  ),
    .nvram_din   ( nvram_din   ),
    .nvram_we    ( nvram_we    ),
    .nvram_dout  ( nvram_dout  ),
    .rom_addr    ( rom_addr    ),
    .rom_cs      ( rom_cs      ),
    .rom_data    ( rom_data    ),
    .rom_ok      ( rom_ok      ),
    .shared_addr ( shared_addr ),
    .shared_din  ( shared_din  ),
    .shared_we   ( shared_we   ),
    .shared_dout ( shared_dout ),
    .dac         ( dac         ),
    .debug_view  ( debug_view  )
);

task emit;
    input [7:0] value;
    begin rom[p]=value; p=p+1; end
endtask

task op;
    input [7:0] value;
    begin emit(NSC ? {value[6],value[7],value[5:2],value[0],value[1]} : value); end
endtask

task wordcode;
    input [15:0] value;
    begin emit(value[15:8]); emit(value[7:0]); end
endtask

initial begin
    for(i=0;i<32768;i=i+1) rom[i]=0;
    for(i=0;i<2048;i=i+1) shared[i]=0;
    for(i=0;i<256;i=i+1) battery[i]=8'h55;
    shared[2046]=8'h80;
    shared[2047]=0;
    op(8'h8e); wordcode(16'h007f);
    op(8'hce); wordcode(16'h1000);
    op(8'h4f);
    loop_start=p;
    op(8'ha7); emit(0);
    op(8'h4c);
    op(8'h08);
    op(8'h8c); wordcode(16'h1100);
    op(8'h26); emit(loop_start-p-1);
    op(8'hce); wordcode(16'h1000);
    loop_start=p;
    op(8'ha6); emit(0);
    op(8'h43);
    op(8'ha7); emit(0);
    op(8'h08);
    op(8'h8c); wordcode(16'h1100);
    op(8'h26); emit(loop_start-p-1);
    op(8'h86); emit(8'hc3);
    op(8'hb7); wordcode(16'hf800);
    op(8'h20); emit(8'hfe);
    repeat(20) @(negedge clk); rst=0; run=1;
    wait(shared[0]==8'hc3);
    @(negedge clk); dip_pause=0;
    if(writes!=512) $fatal(1,"NVRAM transaction count %0d",writes);
    for(i=0;i<256;i=i+1)
        if(battery[i]!==~i[7:0]) $fatal(1,"NVRAM MCU round-trip %02x=%02x",i,battery[i]);
    force dut.addr=16'h1003;
    repeat(3) @(negedge clk);
    if(dut.din!==8'hfc) $fatal(1,"NVRAM did not replace DIP address");
    nvram_en=0;
    #1;
    if(dut.din!==8'h05) $fatal(1,"DIP map not restored outside Frisky Tom");
    force dut.wr=1'b1;
    repeat(30) @(negedge clk);
    if(nvram_we) $fatal(1,"NVRAM write while paused/disabled");
    nvram_en=1; reset_req=1;
    repeat(30) @(negedge clk);
    if(nvram_we) $fatal(1,"NVRAM write during reset");
    for(i=0;i<256;i=i+1)
        if(battery[i]!==~i[7:0]) $fatal(1,"NVRAM lost across MCU reset");
    $display("PASS NVRAM MCU=%0d: 256-byte read/write, DIP overlay, pause and reset retention",NSC);
    $finish;
end

initial begin #30000000; $fatal(1,"NVRAM MCU timeout addr=%h",dut.addr); end
endmodule
