// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
// Full scanner/DMA/drawer chain, using separate synchronous RAM/ROM responders.
module object_pipeline(input clk,output reg done=0);
`include "patterns.vh"
reg rst=1,lvbl=1,flip=0;
reg [2:0] div=0;
wire pxl_cen=div==3;
reg [8:0] h=0,v=14;
wire hs=h>=320 && h<352;
reg [7:0] ram[0:1023];
wire [9:0] a,ref_a;
reg [7:0] q,ref_q;
wire [12:0] addr,ref_addr;
wire cs,ref_cs,ok,ref_ok;
wire [31:0] data,ref_data;
wire [3:0] pxl,ref_pxl;
reg [15:0] latency=0;
reg [7:0] prog_addr=0;
reg [3:0] prog_data=0;
reg prog_en=0,checking=0;
integer i,scenario,lines=0,cycles=0,opaque=0,addresses=0;
integer compared_pixels=0,overrun_differences=0;
reg case_overrun=0;
reg [9:0] previous=0;
always @(posedge clk) begin
    q<=ram[a];ref_q<=ram[ref_a];
    div<=pxl_cen?0:div+1'b1;
    if(!rst && pxl_cen) begin
        h<=h==383?0:h+1'b1;
        if(h==319) begin v<=v==263?0:v+1'b1;lines<=lines+1;end
    end
end
jtmzone_obj dut(.rst(rst),.clk(clk),.pxl_cen(pxl_cen),.oram_addr(a),.oram_dout(q),
 .LVBL(lvbl),.HS(hs),.hdump(h),.vdump(v),.flip(flip),.rom_addr(addr),.rom_cs(cs),
 .rom_data(data),.rom_ok(ok),.prog_data(prog_data),.prog_addr(prog_addr),.prog_en(prog_en),.pxl(pxl));
jtmzone_obj_reference original(.rst(rst),.clk(clk),.pxl_cen(pxl_cen),.oram_addr(ref_a),.oram_dout(ref_q),
 .LVBL(lvbl),.HS(hs),.hdump(h),.vdump(v),.flip(flip),.rom_addr(ref_addr),.rom_cs(ref_cs),
 .rom_data(ref_data),.rom_ok(ref_ok),.prog_data(prog_data),.prog_addr(prog_addr),.prog_en(prog_en),.pxl(ref_pxl));
object_rom rom(clk,rst,cs,addr,latency,data,ok);
object_rom ref_rom(clk,rst,ref_cs,ref_addr,latency,ref_data,ref_ok);
always @(negedge clk) if(checking) begin
    cycles=cycles+1;
    if(a!==ref_a) $fatal(1,"object DMA address mismatch");
    if(^{a,cs}===1'bx || (cs && ^addr===1'bx))
        $fatal(1,"unknown object DMA/request control");
    if(hs && !dut.hs_l && (dut.busy || original.busy)) case_overrun=1;
    if(lines>=5 && pxl_cen) begin
        if(!case_overrun) begin
            compared_pixels=compared_pixels+1;
            if(pxl!==ref_pxl)
                $fatal(1,"rendered pixel mismatch without HS overrun case=%0d h=%0d v=%0d",scenario,h,v);
        end else if(pxl!==ref_pxl) overrun_differences=overrun_differences+1;
    end
    if(lines>=5 && ^pxl===1'bx) $fatal(1,"unknown warmed-up object pipeline pixel");
    if(pxl_cen && pxl!=0) opaque=opaque+1;
    if(a!=previous) begin
        if(a!==previous+10'd1) $fatal(1,"object DMA skipped byte");
        previous=a;addresses=addresses+1;
    end
end
initial begin
    for(i=0;i<1024;i=i+1) ram[i]=0;
    for(i=0;i<60;i=i+1) begin
        ram[4*i]=(i[0]?8'h40:0)|(i[1]?8'h80:0)|{4'd0,i[3:0]};
        ram[4*i+1]=i<8?220:0;
        ram[4*i+2]=i==3?0:i+1;
        ram[4*i+3]=i<4?64+i*2:i==4?248:i==5?255:i==6?0:i==7?1:i*7;
    end
    for(i=0;i<256;i=i+1) begin
        @(negedge clk);prog_addr=i;prog_data=palette(i[7:4],i[3:0]);prog_en=1;
    end
    @(negedge clk);prog_en=0;
    for(scenario=0;scenario<8;scenario=scenario+1) begin
        checking=0;case_overrun=0;rst=1;lvbl=1;flip=scenario[0];
        latency=scenario<2?0:scenario<4?1:scenario<6?9:63;
        repeat(8) @(negedge clk);
        h=0;v=14;div=0;lines=0;previous=0;rst=0;
        repeat(8) @(negedge clk);
        checking=1;lvbl=0;
        wait(lines==4);@(negedge clk);
        if(a!==240) $fatal(1,"object DMA did not copy exactly 240 bytes");
        // CPU changes to live RAM after DMA must not alter this render table.
        ram[2]=ram[2]^8'h71;
        lvbl=1;
        wait(lines==24);@(negedge clk);
        if(a!==240) $fatal(1,"object DMA unexpectedly restarted outside vblank");
        checking=0;
    end
    if(addresses!=8*240 || opaque==0 || rom.stalls==0)
        $fatal(1,"missing full object pipeline coverage");
    $display("Checked full object pipeline: 8 cases, %0d cycle comparisons, %0d DMA byte advances, %0d nonzero pixel samples",cycles,addresses,opaque);
    if(compared_pixels==0) $fatal(1,"no non-overrun pixel comparisons");
    $display("Pipeline pixels: %0d exact comparisons before any HS overrun; %0d differing overrun samples (diagnostic)",compared_pixels,overrun_differences);
    done=1;
end
endmodule
