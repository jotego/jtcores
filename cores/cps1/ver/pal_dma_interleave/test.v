`timescale 1ns/1ps
module test;
reg clk=0, rst=1, hb=1, pal_trigger=0;
reg [5:0] page_mask=0;
reg [11:0] color_addr=0;
reg [15:0] data_seed=16'h50a5;
wire [15:0] color_data;
wire [17:1] vram_addr;
wire br, vram_cs;
reg bg=0;
reg [8:0] render_line=0;
integer run_clock=0, obj_reads=0, scr_reads=0;
integer inject_stage=0;
integer cycles=0, run_reads=0, run_br=0, run_writes=0;
integer first_reads=0, first_br=0, first_boundary_br=0;
integer first_read_by_page[0:5];
integer reads_by_page[0:5];
integer writes_by_page[0:5];
integer expected_seed[0:5];
integer expected_source[0:5];
integer i, guard, expected_source_page, first_enabled_page, enabled_page_count;
reg [5:0] active_mask;
reg running=0, seen_br=0, midchange=0, boundary_mode=0;
reg [15:0] vram_data=16'h0;

always #5 clk=~clk;
always @(negedge clk) if(running) begin
    run_clock=run_clock+1;
    if(boundary_mode && inject_stage==0 && (|uut.cur_task[10:5]) &&
       uut.pal_cnt==511 && uut.pal_wr_cnt==510 && uut.step==1) begin
        hb=0;
        inject_stage=1;
    end else if(boundary_mode && inject_stage==1) begin
        hb=1;
        render_line=render_line==1 ? 9'd15 : render_line+1'b1;
        inject_stage=2;
    end else if(!boundary_mode || inject_stage==2) begin
        if(run_clock%1024==900) hb=0;
        if(run_clock%1024==0) begin hb=1; render_line=render_line==1 ? 9'd15 : render_line+1'b1; end // OBJ starts at line 0, scroll rows load from line 15
    end
end
always @(posedge clk) begin
    bg <= !rst && br;
    cycles <= cycles+1;
    vram_data <= vram_addr[15:1] ^ data_seed;
    if(cycles>1000000) begin
        $display("FAIL palette DMA watchdog");
        $fatal(1);
    end
    if(running) begin
        if(br) begin
            seen_br <= 1;
            run_br <= run_br+1;
        end
        if(br && bg && uut.step==4'd8 && (|uut.cur_task[10:5])) begin
            if(!(|uut.cur_task[10:5])) begin
                $display("FAIL non-palette task reached during isolated transfer");
                $fatal(1);
            end
            run_reads <= run_reads+1;
            for(i=0;i<6;i=i+1) begin
                if(uut.cur_task[5+i]) begin
                    if(first_read_by_page[i]<0) first_read_by_page[i] <= uut.pal_rd_page;
                    reads_by_page[i] <= reads_by_page[i]+1;
                end
            end
        end
        if(br && bg && uut.step==4'd8 && uut.cur_task[1]) obj_reads <= obj_reads+1;
        if(br && bg && uut.step==4'd8 && uut.cur_task[2]) scr_reads <= scr_reads+1;
        if(uut.pal_wr) begin
            run_writes <= run_writes+1;
            if(uut.pal_wr_page>=3'd6) begin
                $display("FAIL palette write spilled beyond page5: page=%0d",uut.pal_wr_page);
                $fatal(1);
            end
            if(!active_mask[uut.pal_wr_page]) begin
                $display("FAIL palette write to disabled page %0d mask %02x task=%03x cnt=%0d wr_cnt=%0d rd_page=%0d",uut.pal_wr_page,active_mask,uut.cur_task,uut.pal_cnt,uut.pal_wr_cnt,uut.pal_rd_page);
                $fatal(1);
            end
            writes_by_page[uut.pal_wr_page] <= writes_by_page[uut.pal_wr_page]+1;
        end
        if(midchange && run_reads==200) page_mask <= 6'h00;
    end
end

jtcps1_dma uut(
    .rst(rst), .clk(clk), .pxl_cen(1'b1), .pxl2_cen(1'b1),
    .HB(hb), .vrender1(render_line), .flip(1'b0),
    .scrdma_en(3'b001),
    .vram1_base(16'd0), .hpos1(16'd0), .vpos1(16'd0),
    .vram2_base(16'd0), .hpos2(16'd0), .vpos2(16'd0),
    .vram3_base(16'd0), .hpos3(16'd0), .vpos3(16'd0),
    .vram_row_base(16'd0), .row_offset(16'd0), .row_en(1'b0), .row_scr(),
    .tile_addr(8'd0), .tile_data(),
    .objdma_en(1'b1), .vram_obj_base(16'd0), .obj_table_addr(10'd0),
    .obj_dma_ok(1'b0), .obj_table_data(),
    .vram_pal_base(16'h9140), .pal_dma_ok(pal_trigger),
    .colmix_addr(color_addr), .pal_data(color_data), .pal_page_en(page_mask),
    .vram_addr(vram_addr), .vram_data(vram_data), .vram_ok(1'b1),
    .vram_clr(), .vram_cs(vram_cs), .rfsh_en(), .br(br), .bg(bg),
    .watch_scr1(), .watch_scr2(), .watch_scr3(), .watch_pal(), .watch_row(), .watch_obj()
);

task check(input reg ok, input string message);
begin
    if(ok!==1'b1) begin
        $display("FAIL %s",message);
        $fatal(1);
    end
end
endtask

task run_case(input [5:0] mask, input reg change_mask, input [15:0] seed,
              input reg reset_before, input reg inject_boundary);
begin
    @(negedge clk); hb=1; pal_trigger=0; page_mask=mask; data_seed=seed; running=0;
    if(reset_before) begin
        rst=1;
        repeat(8) @(negedge clk);
        rst=0;
    end
    repeat(8) @(negedge clk);
    run_reads=0; run_br=0; run_writes=0; seen_br=0; run_clock=0; render_line=0; obj_reads=0; scr_reads=0;
    boundary_mode=inject_boundary;
    inject_stage=0;
    active_mask=mask; midchange=change_mask;
    for(integer p=0;p<6;p=p+1) begin
        first_read_by_page[p]=-1;
        reads_by_page[p]=0;
        writes_by_page[p]=0;
    end
    running=1;
    pal_trigger=1;
    repeat(2) @(negedge clk);
    pal_trigger=0;
    hb=0;
    repeat(2) @(negedge clk);
    hb=1;
    guard=0;
    while(!seen_br && guard<100) begin @(negedge clk); guard=guard+1; end
    check(seen_br,"palette BR starts after trigger");
    guard=0;
    while(br && guard<30000) begin @(negedge clk); guard=guard+1; end
    check(!br,"palette BR completes");
    @(negedge clk); running=0;
    if(boundary_mode) check(inject_stage==2,"word-511 HB boundary was exercised");
    $display("observed palette mask=%02x reads=%0d BR=%0d writes=%0d",mask,run_reads,run_br,run_writes);
    $display("integration OBJ=%0d SCR=%0d lines=%0d",obj_reads,scr_reads,render_line);
    check(obj_reads>4 && scr_reads>=100,"interleaved OBJ and SCR reads occurred");
    check(run_reads==6*512+1,"all six palette pages consume fixed read budget");
    if(first_reads==0) begin first_reads=run_reads; first_br=run_br; end
    check(run_reads==first_reads,"read budget independent of mask");
    if(reset_before && !boundary_mode)
        check(run_br==first_br,"BR budget independent of mask under identical client phase");
    if(reset_before && boundary_mode) begin
        if(first_boundary_br==0) first_boundary_br=run_br;
        check(run_br==first_boundary_br,"boundary BR budget independent of mask");
    end
    enabled_page_count=0;
    for(integer p=0;p<6;p=p+1) enabled_page_count=enabled_page_count+mask[p];
    check(run_writes==enabled_page_count*512,"no extra write beyond enabled pages");
    for(integer p=0;p<6;p=p+1) begin
        check(first_read_by_page[p]>=0,"all six page tasks executed");
        $display("  page %0d source=%0d reads=%0d writes=%0d",p,first_read_by_page[p],reads_by_page[p],writes_by_page[p]);
        check(writes_by_page[p]==(mask[p] ? 512 : 0),
              "each enabled physical page receives exactly 512 words");
        first_enabled_page=-1;
        for(integer q=5;q>=0;q=q-1)
            if(mask[q]) first_enabled_page=q;
        // MAME's source pointer stays at page zero across leading disabled
        // pages, then advances through every later page, even skipped ones.
        expected_source_page=(first_enabled_page<0 || p<first_enabled_page) ?
                             0 : p-first_enabled_page;
        check(first_read_by_page[p]==expected_source_page,
              "source-page mapping matches leading-skip and later-gap rules");
        if(mask[p]) begin
            expected_seed[p]=seed;
            expected_source[p]=expected_source_page;
        end
        for(integer word_index=0;word_index<512;word_index=word_index+1) begin
            @(negedge clk); color_addr={p[2:0],word_index[8:0]};
            repeat(2) @(negedge clk);
            if(color_data!==(((16'ha000+expected_source[p]*512+word_index)&16'h7fff) ^ expected_seed[p])) begin
                $display("FAIL visible palette page=%0d word=%0d got=%04x expected=%04x",
                    p,word_index,color_data,(((16'ha000+expected_source[p]*512+word_index)&16'h7fff) ^ expected_seed[p]));
                $fatal(1);
            end
        end
    end
    $display("palette mask=%02x reads=%0d BR=%0d writes=%0d",mask,run_reads,run_br,run_writes);
end
endtask

initial begin
    run_case(6'h3f,1'b0,16'h50a5,1'b1,1'b0);
    run_case(6'h00,1'b0,16'h30a5,1'b1,1'b0);
    run_case(6'h01,1'b0,16'h41a5,1'b1,1'b0);
    run_case(6'h02,1'b0,16'h22a5,1'b1,1'b0);
    run_case(6'h03,1'b0,16'h33a5,1'b1,1'b0);
    run_case(6'h0a,1'b0,16'h0aa5,1'b1,1'b0);
    run_case(6'h3f,1'b1,16'h55a5,1'b1,1'b0);
    run_case(6'h3f,1'b0,16'h66a5,1'b0,1'b0);
    run_case(6'h0a,1'b0,16'h77a5,1'b0,1'b0);
    run_case(6'h3f,1'b0,16'h88a5,1'b1,1'b1);
    run_case(6'h0a,1'b0,16'h99a5,1'b1,1'b1);
    $display("PASS fixed palette DMA under OBJ, SCR, and word-511 HB interruption");
    $finish;
end
endmodule
