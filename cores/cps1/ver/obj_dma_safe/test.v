`timescale 1ns/1ps
module test;
`include "test_tasks.vh"
reg clk=0,clk48=0,rst=1;
always #5.208333 clk=~clk;
reg [3:0] div=0;
always @(posedge clk) begin
    clk48<=~clk48;
    if(rst || div==11) div<=0; else div<=div+1'b1;
end
wire pxl=div==11,pxl2=div==5 || div==11;
reg hb=1;
reg [8:0] vrender1=0;
reg cs1=0,cs2=0,cfg_we=0;
reg [5:1] addr=0;
reg [15:0] dout=0;
reg [1:0] dsn=3;
reg [7:0] cfg_data=0;
wire [15:0] ppu_ctrl,layer_ctrl,vram_obj_base,vram2_base;
wire obj_dma_ok;
wire [17:1] gfx_addr;
wire [15:0] gfx_data,cache_data;
wire gfx_ok,br,gfx_cs,vram_hold;
reg inject_stall=0;
wire dma_ok=gfx_ok && !inject_stall;
reg [17:1] expected_source=17'h10000;
integer source_switches=0,probe_stage=0,copy_baseline=0;
reg bank_when_stalled;
reg [9:0] counter_when_stalled;
integer words_when_stalled,swaps_when_stalled;
reg previous_rd_bank=0,previous_obj_end=1;
integer bank_swaps=0;
reg bg=0;
always @(posedge clk) bg<=!rst && br;
reg cpu_cs=0;
reg [17:1] cpu_addr=0;
reg [15:0] cpu_data=0;
wire cpu_ok;
reg [9:0] cache_addr=0;
integer words=0,requests=0,grants=0,complete_copies=0,expected_word=0;
integer f,c,j,n,snap_words,snap_requests,snap_grants;
integer frame_words[0:11],frame_requests[0:11],frame_grants[0:11];
integer deadline=0;
reg [15:0] expected_data;
reg failed=0;

task check(input condition,input string message);
    if(condition!==1'b1) begin $display("FAIL %s",message); $fatal(1,"cadence assertion"); end
endtask

jtcps1_mmr #(.REGSIZE(24)) uut_mmr(
 .rst(rst),.clk(clk),.pxl_cen(pxl),.frame_start(1'b0),.line_inc(1'b0),
 .ppu_rstn(1'b1),.ppu1_cs(cs1),.ppu2_cs(cs2),.addr(addr),.dsn(dsn),.cpu_dout(dout),
 .cfg_we(cfg_we),.cfg_data(cfg_data),.ppu_ctrl(ppu_ctrl),.layer_ctrl(layer_ctrl),
 .obj_dma_ok(obj_dma_ok),.vram_obj_base(vram_obj_base),.vram2_base(vram2_base),
 .cab_1p(4'd0),.coin(4'd0),.joystick1(10'd0),.joystick2(10'd0),.joystick3(10'd0),.joystick4(10'd0));

jtcps1_dma uut(
 .rst(rst),.clk(clk),.pxl_cen(pxl),.pxl2_cen(pxl2),.HB(hb),.vrender1(vrender1),.flip(1'b0),
 .scrdma_en(ppu_ctrl[3:1]),.vram1_base(16'h9000),.hpos1(16'd0),.vpos1(16'd0),
 .vram2_base(vram2_base),.hpos2(16'd0),.vpos2(16'd0),.vram3_base(16'h9080),.hpos3(16'd0),.vpos3(16'd0),
 .vram_row_base(16'h9100),.row_offset(16'd0),.row_en(ppu_ctrl[0]),
 .tile_addr(8'd0),.tile_data(),.objdma_en(1'b1),.vram_obj_base(vram_obj_base),
 .obj_table_addr(cache_addr),.obj_dma_ok(obj_dma_ok),.obj_table_data(cache_data),
 .vram_pal_base(16'h9140),.pal_dma_ok(1'b0),.colmix_addr(12'd0),.pal_page_en(6'd0),
 .vram_addr(gfx_addr),.vram_data(gfx_data),.vram_ok(dma_ok),.vram_cs(gfx_cs),.br(br),.bg(bg));

jtcps1_vram uut_vram(
 .rst(rst),.clk_cpu(clk48),.clk_gfx(clk),.hold_rst(vram_hold),
 .cpu_cs(cpu_cs),.cpu_rnw(1'b0),.cpu_addr(cpu_addr),.cpu_din(cpu_data),.cpu_dsn(2'b00),.cpu_ok(cpu_ok),
 .gfx_cs(gfx_cs),.gfx_addr(gfx_addr),.gfx_dout(gfx_data),.gfx_ok(gfx_ok));

always @(posedge clk) begin
    deadline<=deadline+1;
    if(deadline>4000000) begin $display("FAIL watchdog"); $fatal(1,"timeout"); end
    if(!rst) begin
        if(uut.rd_obj_bank!==previous_rd_bank) begin
            check(vrender1===9'd0,"display bank changes only at the frame boundary");
            check(previous_obj_end===1'b1,"display bank presents only a completed prior copy");
            bank_swaps<=bank_swaps+1;
        end
        previous_rd_bank<=uut.rd_obj_bank;
        previous_obj_end<=uut.obj_end;
        if(br) requests<=requests+1;
        if(br && bg) grants<=grants+1;
        if(pxl2 && bg && br && uut.step==8 && dma_ok && uut.cur_task[1]) begin
            check(uut.obj_cnt===expected_word[9:0],"accepted OBJ counter sequence is0..1023");
            check(gfx_addr===expected_source+expected_word,"accepted OBJ source address is contiguous");
            expected_data=(expected_word==3) ? 16'hff00 : ((expected_source==17'h10000 ? 16'h2000:16'h3000) ^ expected_word[15:0]);
            check(gfx_data===expected_data,"accepted source data matches distinctive VRAM pattern");
            words<=words+1;
            if(expected_word==1023) begin
                expected_word=0; complete_copies<=complete_copies+1;
                if(source_switches>0) begin
                    expected_source=source_switches==2 ? 17'h14000:17'h10000;
                    source_switches=source_switches-1;
                end
            end
            else expected_word=expected_word+1;
        end
    end
end

task mmr_write(input [5:1] regno,input [15:0] value,input b);
    begin
        @(negedge clk); addr=regno;dout=value;dsn=0;cs1=!b;cs2=b;
        @(negedge clk);cs1=0;cs2=0;dsn=3;
        repeat(10) @(negedge clk); // total12 clocks preserves divider phase
    end
endtask

task run_frame(input trig);
    begin
        snap_words=words;snap_requests=requests;snap_grants=grants;
        mmr_write(trig ? 5'h00:5'h02,trig ? 16'h9200:16'h9040,1'b0);
        for(n=0;n<262;n=n+1) begin
            @(negedge clk);vrender1=n;hb=0;
            repeat(31) @(negedge clk);hb=1;
            repeat(352) @(negedge clk); // synthetic384-clock line, divisible by12
            if(probe_stage==1 && n==64) mmr_write(0,16'h9280,0);
            if(probe_stage==2 && n==250) begin
                inject_stall=1;
                bank_when_stalled=uut.rd_obj_bank;
                counter_when_stalled=uut.obj_cnt;
                words_when_stalled=words;
                swaps_when_stalled=bank_swaps;
            end
            if(probe_stage==2 && n==259) mmr_write(0,16'h9280,0);
            if(probe_stage==3 && n==2) begin
                check(uut.rd_obj_bank===bank_when_stalled,"line0 overrun does not expose an incomplete bank");
                check(words==words_when_stalled && uut.obj_cnt===counter_when_stalled,"blocked acknowledgement preserves accepted-word count and copy position across line0");
                check(vram_obj_base===16'h9280,"new live base is visible while the old copy remains stalled");
                check(uut.obj_end===1'b0 && uut.obj_cnt>900,"stalled old copy was not restarted at line0");
            end
            if(probe_stage==3 && n==3) mmr_write(0,16'h9200,0);
            if(probe_stage==3 && n==10) inject_stall=0;
            if(probe_stage==3 && n==30) begin
                check(uut.obj_end===1'b1,"old copy finishes after acknowledgement resumes");
                check(uut.rd_obj_bank===bank_when_stalled,"completion during visible scanout does not swap the display bank");
                check(complete_copies==copy_baseline+1,"no deferred transfer starts during visible scanout");
            end
            if(probe_stage==4 && n==2) begin
                check(uut.rd_obj_bank!==bank_when_stalled,"next boundary presents the completed old copy");
                check(words>snap_words && expected_word>0,"fresh next-boundary copy makes accepted-read progress from the expected current source");
            end
        end
    end
endtask

task check_cache(input [15:0] prefix);
    begin
        for(j=0;j<5;j=j+1) begin
            @(negedge clk);cache_addr=j;repeat(2) @(negedge clk);
            check(cache_data===(j<3 ? (prefix ^ j[15:0]):16'd0),"cache prefix retained and marker/tail zero-filled");
        end
        @(negedge clk);cache_addr=1023;repeat(2) @(negedge clk);
        check(cache_data===16'd0,"last cache word is zero-filled");
        repeat(6) @(negedge clk); // keep setup length a multiple of12 clocks
    end
endtask

initial begin
    $dumpfile("test.lxt");$dumpvars(0,rst,vrender1,complete_copies,failed);
    for(c=0;c<24;c=c+1) begin
        @(negedge clk);cfg_we=1;cfg_data=c==6 ? 8'h14:0;
        @(negedge clk);cfg_we=0;
    end
    repeat(12) @(negedge clk);rst=0;
    wait(vram_hold===1'b0);
    for(c=0;c<1024;c=c+1) begin
        @(negedge clk48);cpu_cs=1;cpu_addr=17'h10000+c;cpu_data=c==3 ? 16'hff00:(16'h2000 ^ c[15:0]);
    end
    for(c=0;c<1024;c=c+1) begin
        @(negedge clk48);cpu_cs=1;cpu_addr=17'h14000+c;cpu_data=c==3 ? 16'hff00:(16'h3000 ^ c[15:0]);
    end
    @(negedge clk48);cpu_cs=0;
    mmr_write(5'h11,0,0);mmr_write(5'h0a,16'h3900,1);
    check(ppu_ctrl===0 && layer_ctrl===16'h3900,"object-only configuration reached production MMR");
    // Two positive-control copies fill both banks before observing HOLD.
    run_frame(1);run_frame(1);check_cache(16'h2000);
    for(c=0;c<4;c=c+1) begin
        for(f=0;f<2;f=f+1) begin
            run_frame(c==1 || c==2);
            frame_words[c*2+f]=words-snap_words;
            frame_requests[c*2+f]=requests-snap_requests;
            frame_grants[c*2+f]=grants-snap_grants;
            $display("FRAME case=%0d sample=%0d words=%0d requests=%0d grants=%0d",c,f,
                frame_words[c*2+f],frame_requests[c*2+f],frame_grants[c*2+f]);$fflush();
            if(f>0 && frame_words[c*2+f]!=1024) failed=1;
        end
        check_cache(16'h2000);
    end
    for(c=0;c<4;c=c+1) begin
        for(f=1;f<2;f=f+1) begin
            if(frame_requests[c*2+f]!=frame_requests[3] || frame_grants[c*2+f]!=frame_grants[3]) failed=1;
        end
    end
    check(!failed,"ABBA periodic cadence and request budgets match before hazard injection");
    mmr_write(0,16'h9200,0);expected_source=17'h10000;
    probe_stage=1;run_frame(0);
    $display("MID_COPY base rewrite preserved all1024 old-source reads");
    expected_source=17'h14000;probe_stage=0;run_frame(0);
    $display("NEXT_FRAME new source applies to all1024 reads");
    mmr_write(0,16'h9200,0);expected_source=17'h10000;
    source_switches=0;copy_baseline=complete_copies;
    probe_stage=2;run_frame(0);
    check(inject_stall && uut.obj_end===1'b0,"delayed-ack probe leaves a copy unfinished at frame end");
    probe_stage=3;run_frame(0);
    check(complete_copies==copy_baseline+1,"completed old copy waits for the next boundary");
    check(uut.rd_obj_bank===bank_when_stalled,"old display bank survives the entire overrun frame");
    check(bank_swaps==swaps_when_stalled,"overrun and visible completion cause no bank swap");
    check_cache(16'h3000);
    probe_stage=4;run_frame(0);
    check(complete_copies==copy_baseline+2,"a fresh next-boundary copy completes without restart or data loss");
    check(bank_swaps==swaps_when_stalled+1,"only the following frame boundary presents the completed table");
    check_cache(16'h2000);
    $display("DELAYED_ACK display bank held through the full overrun frame; fresh copy starts/presents only at the next boundary");
    $display("CADENCE completed_copies=%0d expected_next_word=%0d boundary_only_bank_swaps=%0d",complete_copies,expected_word,bank_swaps);
    if(failed) begin
        $display("FAIL synthetic periodic OBJ copy/cost differs between HOLD and TRIG");$finish;
    end else pass();
end
endmodule
