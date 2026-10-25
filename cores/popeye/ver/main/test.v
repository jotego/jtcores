/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps
module test;
reg clk=0;
wire [3:0] done;
always #10.417 clk=~clk;
main_case #(.BOARD(0),.ROMFILE("main0.hex")) c0(clk,done[0]);
main_case #(.BOARD(1),.ROMFILE("main1.hex")) c1(clk,done[1]);
main_case #(.BOARD(2),.ROMFILE("main2.hex")) c2(clk,done[2]);
main_case #(.BOARD(3),.ROMFILE("main3.hex")) c3(clk,done[3]);
initial begin
    $dumpfile("test.lxt");$dumpvars(1,c0.uut);
    repeat(2048)@(posedge clk);$dumpoff;
    wait(&done);$display("PASS");$finish;
end
initial begin repeat(250000)@(posedge clk);$fatal(1,"FAIL CPU timeout");end
endmodule

module main_case #(parameter BOARD=0,ROMFILE="main0.hex")(input clk,output reg done=0);
reg rst=1,wdmode=0,vb=0,pause=1,busrq_n=1,dma_cs=0;
reg [10:0] dma_addr=0;
reg [7:0] marker=0,irq_count=0,read_ay=0,read_cab=0;
wire cpu_cen,psg_cen,reset_n,busak_n,csv,csbw_n,dwrbk_n,memwr0,bdir,bc1,prot_cs,prot_we,prot_addr,main_cs;
wire [12:0] ad;
wire [7:0] dd,cpu_dout,blprot_addr,main_data;
wire [14:0] main_addr;
wire busy;
wire [11:0] work_addr;
wire work_we;
wire [7:0] work_dout;
jtframe_ram #(.AW(12)) u_work(.clk(clk),.cen(1'b1),.addr(work_addr),.data(cpu_dout),.we(work_we),.q(work_dout));
reg main_ok=0;
reg [14:0] last_addr=0;
reg [5:0] latency=0;
integer text_writes=0,bg_writes=0,ay_writes=0;
wire [15:0] rom_addr={wdmode,main_addr};
assign busy=main_cs&&!main_ok;
jtframe_ram #(.AW(16),.SIMHEXFILE(ROMFILE)) u_rom(.clk(clk),.cen(1'b1),.data(8'd0),.addr(rom_addr),.we(1'b0),.q(main_data));
jtframe_gated_cen #(.W(1),.NUM(1),.DEN(12)) u_cpu_cen(.rst(rst),.clk(clk),.busy(busy),.cen(cpu_cen),.fave(),.fworst());
jtframe_gated_cen #(.W(1),.NUM(1),.DEN(24)) u_psg_cen(.rst(rst),.clk(clk),.busy(1'b0),.cen(psg_cen),.fave(),.fworst());
always @(posedge clk)begin
 last_addr<=main_addr;
 if(!main_cs||main_addr!=last_addr)begin latency<=0;main_ok<=0;end
 else if(!main_ok)begin latency<=latency+6'd1;if(latency==6'd4+{4'd0,main_addr[1:0]})main_ok<=1;end
 if(!rst&&memwr0)begin
  case(uut.A)
   16'h8c00:irq_count<=cpu_dout;
   16'h8c11:read_ay<=cpu_dout;
   16'h8c12:read_cab<=cpu_dout;
   16'h8c1f:marker<=cpu_dout;
   default:begin end
  endcase
  if(csv)text_writes<=text_writes+1;
  if(!dwrbk_n)bg_writes<=bg_writes+1;
 end
 if(!rst&&bdir)ay_writes<=ay_writes+1;
end
jtpopeye_main uut(
 .work_addr(work_addr),.work_we(work_we),.work_dout(work_dout),
 .rst(rst),.clk(clk),.cpu_cen(cpu_cen),.psg_cen(psg_cen),.vb(vb),.initeo(1'b1),
 .tpp1rom(BOARD==1||BOARD==3),.boot(BOARD==2),.tpp1ram(BOARD==1||BOARD==2),.tnx1(BOARD==3),
 .reset_n(reset_n),.cab_1p(2'b10),.coin(1'b0),.service(1'b0),.dip_pause(pause),
 .joystick1(6'h3f),.joystick2(6'h3f),.busrq_n(busrq_n),.busak_n(busak_n),.dma_cs(dma_cs),.dma_addr(dma_addr),
 .ad(ad),.dd(dd),.cpu_dout(cpu_dout),.csv(csv),.csbw_n(csbw_n),.dwrbk_n(dwrbk_n),.memwr0(memwr0),
 .bdir(bdir),.bc1(bc1),.ay_dout(8'ha5),.prot_cs(prot_cs),.prot_we(prot_we),.prot_addr(prot_addr),.prot_dout(8'hf8),
 .blprot_addr(blprot_addr),.blprot_data(8'h00),.main_cs(main_cs),.main_addr(main_addr),.main_data(main_data),.main_ok(main_ok)
);
task field;
begin
 @(negedge clk);vb=1;repeat(100)@(negedge clk);vb=0;repeat(100)@(negedge clk);
end
endtask
// CPU RAM address 8C10 passes through the board's scrambled address wiring.
localparam [10:0] DMA_8C10=11'h437;
integer n;
initial begin
 repeat(16)@(negedge clk);rst=0;
 wait(marker==8'hc3);repeat(100)@(negedge clk);
 if(read_ay!==8'ha5||read_cab!==8'hd4)$fatal(1,"FAIL board %0d I/O %h %h",BOARD,read_ay,read_cab);
 if(text_writes==0||bg_writes==0||ay_writes==0)$fatal(1,"FAIL peripheral strobes board %0d",BOARD);
 busrq_n=0;wait(!busak_n);dma_addr=DMA_8C10;dma_cs=1;repeat(4)@(negedge clk);
 if(dd!==8'ha5)$fatal(1,"FAIL board %0d DMA RAM got %h",BOARD,dd);
 dma_cs=0;busrq_n=1;wait(busak_n);
 pause=0;field();if(irq_count!==0)$fatal(1,"FAIL pause board %0d",BOARD);
 pause=1;
 for(n=1;n<=3;n=n+1)begin field();wait(irq_count==n);repeat(1000)@(negedge clk);end
 wdmode=1;rst=1;marker=0;repeat(16)@(negedge clk);rst=0;
 wait(marker==8'h5a);repeat(100)@(negedge clk);
 repeat(4)field();repeat(100)@(negedge clk);
 if(reset_n!==0)$fatal(1,"FAIL watchdog board %0d",BOARD);
 $display("board %0d: synthetic ROM/I/O/RAM/DMA, pause/NMI and watchdog passed",BOARD);done=1;
end
endmodule
