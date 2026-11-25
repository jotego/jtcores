`timescale 1ns/1ps
// CPS1 line DMA: per-line bus header and SCR3 tile row cadence.
module test;
reg clk=0, rst=1;               // 96 MHz
reg [3:0] pixdiv=0;
wire pxl_cen  = pixdiv==4'd11;  // 8 MHz
wire pxl2_cen = pixdiv==4'd5 || pixdiv==4'd11;
wire [8:0] hdump,vdump,vrender,vrender1;
wire hb, vb;
reg  [3:1] scrdma_en=0;
reg  objdma_en=0;
reg  [7:0] tile_addr=0;
wire [15:0] tile_data;
reg  [15:0] t220, t222, t224, t225;
wire [17:1] vram_addr;
wire br, vram_cs;
reg  bg=0;

always #5.208 clk=~clk;
always @(posedge clk) begin
    if(rst || pixdiv==4'd11) pixdiv<=0; else pixdiv<=pixdiv+1'b1;
    bg <= !rst && br;
end

jtcps1_timing u_timing(.clk(clk),.cen8(pxl_cen),.hdump(hdump),.vdump(vdump),.vrender(vrender),.vrender1(vrender1),
    .line_start(),.line_inc(),.frame_start(),.HS(),.VS(),.VB(vb),.preVB(),.HB(hb),.debug_bus(8'd0));

jtcps1_dma uut(.rst(rst),.clk(clk),.pxl_cen(pxl_cen),.pxl2_cen(pxl2_cen),.HB(hb),.vrender1(vrender1),.flip(1'b0),
    .scrdma_en(scrdma_en),.vram1_base(16'h9000),.hpos1(16'd0),.vpos1(16'd0),.vram2_base(16'h9040),.hpos2(16'd0),.vpos2(16'd3),
    .vram3_base(16'h9080),.hpos3(16'd0),.vpos3(16'd0),.vram_row_base(16'h9100),.row_offset(16'd0),.row_en(1'b0),.row_scr(),
    .tile_addr(tile_addr),.tile_data(tile_data),.objdma_en(objdma_en),.vram_obj_base(16'h9200),.obj_table_addr(10'd0),.obj_dma_ok(1'b0),
    .obj_table_data(),.vram_pal_base(16'h9140),.pal_dma_ok(1'b0),.colmix_addr(12'd0),.pal_data(),.pal_page_en(6'd0),
    .vram_addr(vram_addr),.vram_data(vram_addr[16:1]),.vram_ok(1'b1),.vram_clr(),.vram_cs(vram_cs),.rfsh_en(),.br(br),.bg(bg),
    .watch_scr1(),.watch_scr2(),.watch_scr3(),.watch_pal(),.watch_row(),.watch_obj());

// Per frame: BR intervals, their length range (pxl2 ticks) and SCR3 rows.
integer len=0, nbr=0, minlen=0, maxlen=0, scr3=0, scr3_words=0;
reg last_br=0, last_vb=0, last_scr3=0;
always @(posedge clk) begin
    last_vb <= vb;
    if(pxl2_cen) begin
        last_br   <= br;
        last_scr3 <= uut.cur_task[4];
        if(br) len <= len+1;
        if(!br && last_br) begin
            nbr <= nbr+1;
            if(len<minlen) minlen <= len;
            if(len>maxlen) maxlen <= len;
            len <= 0;
        end
        if(uut.cur_task[4] && !last_scr3) scr3 <= scr3+1;
        if(br && bg && uut.cur_task[4] && uut.step==4'd8) scr3_words <= scr3_words+1;
    end
end

task frame(output integer n, output integer lo, output integer hi, output integer s3, output integer w3);
    begin
        @(posedge vb);
        nbr=0; minlen=1000000; maxlen=0; scr3=0; scr3_words=0;
        @(posedge vb);
        n=nbr; lo=minlen; hi=maxlen; s3=scr3; w3=scr3_words;
    end
endtask

task check(input ok, input [8*64-1:0] msg);
    if(!ok) begin $display("FAIL %0s",msg); $fatal(1); end
endtask

integer n, lo, hi, s3, w3;
initial begin
    repeat(20) @(posedge clk); rst=0;
    repeat(2) @(posedge vb);
    // No tasks: the bus is still requested on every line for the header
    frame(n,lo,hi,s3,w3);
    $display("idle: %0d BR/frame, %0d..%0d pxl2 ticks", n, lo, hi);
    check(n==262, "idle line DMA must request the bus on all 262 lines");
    check(lo==10 && hi==10, "idle line BR must last 10 16MHz ticks (0.625us)");
    // Object DMA: 4 words per line on 256 lines plus the header
    objdma_en=1;
    repeat(2) @(posedge vb);
    frame(n,lo,hi,s3,w3);
    $display("obj:  %0d BR/frame, %0d..%0d pxl2 ticks", n, lo, hi);
    check(n==262, "object DMA must request the bus on all lines");
    check(hi>=lo+16 && hi<=lo+18, "an OBJ line adds 4 words (16 ticks) to the header");
    // SCR3 tile rows are 32 lines tall
    objdma_en=0; scrdma_en=3'b100;
    repeat(2) @(posedge vb);
    frame(n,lo,hi,s3,w3);
    $display("scr3: %0d tile rows, %0d words", s3, w3);
    check(s3==8 && w3==8*30, "SCR3 must fetch one 30-word row every 32 lines");
    // SCR2 words 220-225 belong to the same row and bank
    scrdma_en=3'b010;
    repeat(3) @(posedge vb);
    @(negedge vb);
    repeat(40) @(posedge hb);
    tile_addr=220; repeat(4) @(posedge clk); t220=tile_data;
    tile_addr=222; repeat(4) @(posedge clk); t222=tile_data;
    tile_addr=224; repeat(4) @(posedge clk); t224=tile_data;
    tile_addr=225; repeat(4) @(posedge clk); t225=tile_data;
    $display("scr2 tail: %h %h %h %h", t220, t222, t224, t225);
    check(t224-t222==t222-t220 && t225==(t224|16'd1), "SCR2 words 224/225 must come from the SCR2 bank");
    $display("PASS");
    $finish;
end
endmodule
