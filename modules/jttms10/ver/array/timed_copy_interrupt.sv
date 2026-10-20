`timescale 1ns/1ps
`default_nettype none

// SPVU001A 7-8/9 and 12-176/182: completed destination-word/row checkpoints,
// PBX/RETI and nested ISR graphics. Physical words use the real timed wrapper.
module test;
    reg clk=0;
    always #5 clk=~clk;
    reg rst=1, cen=1, irq_req=0, nmi_req=0, halt_req=0;
    wire nmi_clear, retire, fault;
    wire word_req,word_pending,word_early,word_we,word_iaq,word_pixel,word_lock;
    wire word_ack,word_restart,word_wait;
    wire [31:0] word_addr, pc, st;
    wire [15:0] word_wdata,word_rdata,ir;
    wire mem_req,mem_iaq;
    wire [31:0] mem_addr;
    wire [3:0] cycle_kind;
    wire [15:0] cycle_wdata;
    reg [15:0] mem_rdata=0;
    reg mem_ack=0;
    reg [15:0] words [0:1023];
    reg busy=0, held_we=0, held_iaq=0;
    reg [31:0] held_addr=0;
    reg [15:0] held_data=0;
    integer delay_left=0, wait_states=0, pixel_size=4, width=16, xy=0;
    integer irq_after=1, mode=0, drawn=0, source_reads=0, retired=0, fetches=0;
    integer nmi_clears=0, stack_writes=0, halt_clocks=0, i;
    reg sent=0, handler_seen=0;
    integer pause_clocks=0, pause_left=0;
    reg pause_sent=0, paused_accept=0, paused_completed_irq=0;
    wire no_stack;
    wire [15:0] psize;

    assign no_stack=mode==3;
    assign psize=16'(pixel_size);

    jttms10_word #(.TIMED_PROGRAM(1)) u_cpu(
        .rst(rst),.clk(clk),.cen(cen),
        .psize(psize),.convdp(16'd21),.convsp(16'd22),
        .control(16'd0),.pmask(16'd0),.wvp_set(),
        .irq_req(irq_req),.irq_vector(32'hfffffec0),
        .halted(), .nmi_req(nmi_req),.nmi_nostack(no_stack),.halt_req(halt_req),
        .emu_run(1'b1),.nmi_clear(nmi_clear),.emu_ack(),
        .word_req(word_req),.word_pending(word_pending),.word_early(word_early),
        .word_we(word_we),.word_addr(word_addr),.word_wdata(word_wdata),
        .word_iaq(word_iaq),.word_lock(word_lock),.word_pixel(word_pixel),
        .word_rdata(word_rdata),.word_ack(word_ack),.word_restart(word_restart),.word_wait(word_wait),
        .pixel_srt(1'b0),.cache_flush(1'b0),
        .pc(pc),.st(st),.ir(ir),.retire(retire),.fault(fault)
    );

    jttms10_bus #(.TIMING(1)) u_bus(
        .clk(clk),.rst(rst),.hold_req(1'b0),.hold_ack(),
        .screen_req(1'b0),.screen_srfaddr(14'd0),.screen_dpytap(16'd0),.screen_org(1'b0),.screen_ack(),
        .refresh_req(1'b0),.refresh_row(8'd0),.refresh_cbr(1'b0),
        .host_mem_req(1'b0),.host_mem_we(1'b0),.host_mem_addr(32'd0),.host_mem_wdata(16'd0),
        .host_mem_is_io(1'b0),.host_mem_io_rdata(16'd0),.host_mem_rdata(),.host_mem_ack(),
        .word_req(word_req),.word_pending(word_pending),.word_early(word_early),.word_we(word_we),
        .word_iaq(word_iaq),.word_lock(word_lock),.word_pixel(word_pixel),
        .word_addr(word_addr),.word_wdata(word_wdata),.word_rdata(word_rdata),
        .word_ack(word_ack),.word_restart(word_restart),.word_wait(word_wait),
        .is_io(1'b0),.pixel_srt(1'b0),.io_rdata(16'd0),
        .cyc_req(mem_req),.cyc_kind(cycle_kind),.cyc_addr(mem_addr),.cyc_wdata(cycle_wdata),
        .cyc_io_rdata(),.cyc_iaq(mem_iaq),.cyc_srfaddr(),.cyc_dpytap(),.cyc_org(),.cyc_dram_row(),
        .cyc_rdata(mem_rdata),.cyc_ack(mem_ack)
    );

    function automatic [15:0] read_word(input [31:0] addr);
        begin
            if(addr==32'hffffffe0) read_word=16'h1000;
            else if(addr==32'hfffffec0 || addr==32'hfffffee0) read_word=16'h1600;
            else if(addr==32'hfffffff0 || addr==32'hfffffed0 || addr==32'hfffffef0) read_word=0;
            else begin
                if(addr[3:0]!=0 || addr>=32'h4000) $fatal(1,"invalid read %h",addr);
                read_word=words[addr>>4];
            end
        end
    endfunction

    function automatic [31:0] read_long(input [31:0] addr);
        read_long={read_word(addr+16),read_word(addr)};
    endfunction

    function automatic [15:0] source_word(input integer row, input integer column);
        source_word=16'(32'h96a5^(32'(row)*32'h3179)^(32'(column+1)*32'h1273));
    endfunction

    task automatic put_movi(input integer offset, input [3:0] number, input [31:0] value);
        begin
            words[offset]=16'h09f0|{12'd0,number};
            words[offset+1]=value[15:0]; words[offset+2]=value[31:16];
        end
    endtask

    task automatic load_program;
        integer row, column;
        begin
            for(i=0;i<1024;i=i+1) words[i]=16'h0300;
            for(i='h60;i<'he0;i=i+1) words[i]=16'hc33c;
            for(row=0;row<2;row=row+1) for(column=0;column<32;column=column+1)
                words['h20+row*32+column]=source_word(row,column);
            put_movi('h100,15,32'h3000);
            put_movi('h103,0,(xy&2)!=0 ? 32'(16/pixel_size) : 32'h0200); put_movi('h106,1,32'h0200);
            put_movi('h109,2,(xy&1)!=0 ? (32'h00010000|32'(16/pixel_size)) : 32'h0600);
            put_movi('h10c,3,32'h0400); put_movi('h10f,4,32'h01f0);
            put_movi('h112,7,32'h00020000|32'(width));
            put_movi('h115,8,32'h13579bdf); put_movi('h118,9,32'heca86420);
            words['h11b]=16'h0d60;
            words['h11c]=16'h0f00|(16'(xy)<<5); // EINT, regular PIXBLT
            words['h160]=16'h099f; words['h161]=16'hfffe; // MMTM B0..B14
            put_movi('h162,2,32'h0e00); put_movi('h165,3,32'h0400);
            put_movi('h168,7,32'h00010001); put_movi('h16b,9,32'h76543210);
            words['h16e]=16'h0fc0; // nested FILL
            words['h16f]=16'h09bf; words['h170]=16'h7fff; // MMFM B0..B14
            words['h171]=16'h0940; // RETI
            if(mode==3) words['h160]=16'h0300;
            words['he0]=16'hbeef;
        end
    endtask

    // TI defines B0/B2 at the completed-word/row checkpoint. Do not
    // assert undocumented reserved scratch-register values for this path.
    task automatic check_context;
        integer row, done_in_row;
        reg [31:0] expected_source, expected_destination;
        begin
            row=(irq_after-1)/(width*pixel_size/16);
            done_in_row=((irq_after-1)%(width*pixel_size/16)+1)*16/pixel_size;
            expected_source=32'h0200+32'(row*512)+(done_in_row==width ? 32'd512 : 32'(done_in_row*pixel_size));
            expected_destination=32'h0600+32'(row*1024)+(done_in_row==width ? 32'd1024 : 32'(done_in_row*pixel_size));
            if(u_cpu.u_core.u_regs.ram0[16]!==expected_source ||
               u_cpu.u_core.u_regs.ram0[18]!==expected_destination || source_reads!=irq_after)
                $fatal(1,"regular context B0=%h B2=%h reads=%0d",u_cpu.u_core.u_regs.ram0[16],u_cpu.u_core.u_regs.ram0[18],source_reads);
        end
    endtask

    always @(posedge clk) begin
        mem_ack<=0;
        if(rst) busy<=0;
        else if(mem_ack) mem_ack<=0;
        else if(!busy && mem_req) begin
            held_addr<=mem_addr; held_data<=cycle_wdata;
            held_we<=cycle_kind==4'd1; held_iaq<=mem_iaq;
            delay_left<=2+8*wait_states; busy<=1;
            if(cycle_kind!=4'd1 && !mem_iaq && mem_addr>=32'h0200 && mem_addr<32'h0600) begin
                if(source_reads>=width*pixel_size/8 ||
                   mem_addr!==32'h0200+32'((source_reads/(width*pixel_size/16))*512+(source_reads%(width*pixel_size/16))*16))
                    $fatal(1,"regular source[%0d] %h",source_reads,mem_addr);
                source_reads<=source_reads+1;
            end
        end else if(busy) begin
            if(!mem_req || mem_addr!==held_addr || mem_iaq!==held_iaq ||
               (cycle_kind==4'd1)!==held_we || (held_we && cycle_wdata!==held_data))
                $fatal(1,"held request changed %h",held_addr);
            if(delay_left!=0) delay_left<=delay_left-1;
            else begin
                if(held_we) begin
                    if(held_addr>=32'h4000 || held_addr[3:0]!=0) $fatal(1,"bad write %h",held_addr);
                    words[held_addr>>4]=held_data;
                    if(held_addr>=32'h2d00 && held_addr<32'h3000) begin
                        if(stack_writes<4 && held_addr!==(32'h2ff0-32'(stack_writes*16)))
                            $fatal(1,"hardware stack write order %0d @%h",stack_writes,held_addr);
                        stack_writes<=stack_writes+1;
                    end
                    if(held_addr>=32'h0600 && held_addr<32'h0e00) begin
                        if(held_addr!==32'h0600+32'((drawn/(width*pixel_size/16))*1024+(drawn%(width*pixel_size/16))*16) ||
                           held_data!==source_word(drawn/(width*pixel_size/16),drawn%(width*pixel_size/16)))
                            $fatal(1,"regular output[%0d] %h=%h",drawn,held_addr,held_data);
                        drawn<=drawn+1;
                        if(mode!=0 && !sent && drawn+1==irq_after) begin
                            if(mode>=2) nmi_req<=1; else irq_req<=1;
                            if(mode==4) halt_req<=1;
                            sent<=1;
                        end
                    end
                end else mem_rdata<=read_word(held_addr);
                mem_ack<=1; busy<=0;
            end
        end
        if(!rst && nmi_clear) nmi_clears<=nmi_clears+1;
        if(!rst && fault) $fatal(1,"fault PC=%h IR=%h",pc,ir);
        if(!rst && u_cpu.u_core.step && u_cpu.u_core.ld_ir && pc==32'h11c0) fetches<=fetches+1;
        if(!rst && u_cpu.u_core.hw_take && u_cpu.u_core.gfx_active &&
           (u_cpu.field_busy || u_cpu.post_busy || u_cpu.data_owner))
            $fatal(1,"graphics interrupt accepted with an outstanding physical field");
        if(!rst && !cen && u_cpu.field_req && u_cpu.field_ack && u_cpu.field_we)
            paused_accept<=1;
        if(!rst && !cen && u_cpu.u_core.completed && (irq_req || nmi_req))
            paused_completed_irq<=1;
    end

    always @(posedge retire) begin
        #1;
        if(fault) $fatal(1,"fault PC=%h IR=%h",pc,ir);
        retired=retired+1;
    end

    // Pause just before a logical posted write is acknowledged. The memory
    // keeps running, exercising an IRQ after acceptance while CEN is low.
    always @(negedge clk) if(!rst) begin
        if(pause_left!=0) begin
            pause_left=pause_left-1;
            if(pause_left==0) cen=1;
        end else if(!pause_sent && pause_clocks!=0 && drawn+1==irq_after &&
                    u_cpu.data_accept && u_cpu.field_we &&
                    u_cpu.field_addr>=32'h0600 && u_cpu.field_addr<32'h0e00) begin
            pause_sent=1; pause_left=pause_clocks; cen=0;
        end
    end

    always @(negedge clk) if(!rst && mode!=0) begin
        if(pc==32'h1600 && !handler_seen) begin
            handler_seen=1; irq_req=0; nmi_req=0;
            if(drawn!=irq_after || retired!=(irq_after==width*pixel_size/8 ? 11 : 10))
                $fatal(1,"regular IRQ missed destination checkpoint: mode=%0d writes=%0d expected=%0d retire=%0d",mode,drawn,irq_after,retired);
            if(no_stack) begin
                if(stack_writes!=0 || u_cpu.u_core.u_regs.ram0[15]!==32'h3000)
                    $fatal(1,"no-stack NMI pushed context");
            end else if(read_long(32'h2fe0)!==32'h11d0 ||
                        (read_long(32'h2fc0)&32'h0fffffff)!==
                        (32'h00200010|(irq_after!=width*pixel_size/8 ? 32'h02000000 : 32'd0)))
                $fatal(1,"regular IRQ stack PC=%h ST=%h",read_long(32'h2fe0),read_long(32'h2fc0));
            if(irq_after!=width*pixel_size/8) check_context();
        end
        if(mode==4 && handler_seen && halt_req) begin
            if(mem_req || retired!=10) $fatal(1,"HLT failed to hold ISR fetch");
            halt_clocks=halt_clocks+1;
            if(halt_clocks==20) halt_req=0;
        end
    end

    task automatic execute(input integer selected_mode);
        integer timeout, row, column;
        reg [15:0] pixel_mask;
        begin
            mode=selected_mode; rst=1; cen=1; irq_req=0; nmi_req=0; halt_req=0;
            sent=0; handler_seen=0; drawn=0; source_reads=0; retired=0; fetches=0;
            nmi_clears=0; stack_writes=0; halt_clocks=0;
            pause_sent=0; pause_left=0; paused_accept=0; paused_completed_irq=0;
            load_program(); repeat(5) @(negedge clk); rst=0; timeout=0;
            while((mode==3 ? !handler_seen : retired<(mode==0 ? 12 : 20)) && timeout<100000) begin
                @(negedge clk); timeout=timeout+1;
            end
            if(timeout==100000) $fatal(1,"regular IRQ timeout mode=%0d PC=%h IR=%h writes=%0d gfx=%h time=%0d active=%b",
                mode,pc,ir,drawn,u_cpu.u_core.u_gfx.uaddr,u_cpu.u_core.time_left,u_cpu.u_core.timing_active);
            if(pause_clocks!=0 && (!pause_sent || !paused_accept)) $fatal(1,"CEN pause did not cover a posted ACK");
            if(pause_clocks>=31 && mode!=0 && !paused_completed_irq)
                $fatal(1,"CEN pause did not cover a pending IRQ after posted acceptance");
            if(mode==3) begin
                repeat(20) @(negedge clk);
                if(drawn!=irq_after || nmi_clears!=1) $fatal(1,"no-stack NMI did not abandon array");
            end else begin
                if(drawn!=width*pixel_size/8 || source_reads!=width*pixel_size/8 || fetches!=1 ||
                   u_cpu.u_core.u_regs.ram0[15]!==32'h3000 ||
                   u_cpu.u_core.u_regs.ram0[16]!==32'h0600 || u_cpu.u_core.u_regs.ram0[18]!==32'h0e00 ||
                   u_cpu.u_core.u_regs.ram0[17]!==32'h0200 || u_cpu.u_core.u_regs.ram0[19]!==32'h0400 ||
                   u_cpu.u_core.u_regs.ram0[20]!==32'h01f0 ||
                   u_cpu.u_core.u_regs.ram0[24]!==32'h13579bdf || u_cpu.u_core.u_regs.ram0[25]!==32'heca86420 ||
                   (st&32'h0fffffff)!==32'h00200010 ||
                   u_cpu.u_core.u_regs.ram0[23]!==(32'h00020000|32'(width)))
                    $fatal(1,"regular completion mode=%0d writes=%0d reads=%0d fetches=%0d B0=%h B2=%h B7=%h",mode,drawn,source_reads,fetches,u_cpu.u_core.u_regs.ram0[16],u_cpu.u_core.u_regs.ram0[18],u_cpu.u_core.u_regs.ram0[23]);
                for(row=0;row<2;row=row+1) for(column=0;column<width*pixel_size/16;column=column+1)
                    if(words['h60+row*64+column]!==source_word(row,column)) $fatal(1,"final destination differs");
                for(row=0;row<2;row=row+1) begin
                    for(column=0;column<32;column=column+1)
                        if(words['h20+row*32+column]!==source_word(row,column)) $fatal(1,"source word changed");
                    for(column=width*pixel_size/16;column<64;column=column+1)
                        if(words['h60+row*64+column]!==16'hc33c) $fatal(1,"destination canary changed");
                end
                if(mode!=0 && !handler_seen) $fatal(1,"interrupt never entered");
                pixel_mask=16'((32'd1<<pixel_size)-1);
                if(mode!=0 && words['he0]!==((16'hbeef&~pixel_mask)|(16'h3210&pixel_mask)))
                    $fatal(1,"nested ISR graphics did not execute correctly");
                if(mode>=2 && nmi_clears!=1) $fatal(1,"NMI clear count %0d",nmi_clears);
                if(mode==4 && halt_clocks!=20) $fatal(1,"HLT coverage missing");
            end
            $display("PASS regular IRQ PS%0d DX%0d copy%0d waits%0d after%0d mode%0d",pixel_size,width,xy,wait_states,irq_after,mode);
        end
    endtask

    initial begin
        if($value$plusargs("PSIZE=%d",pixel_size)) begin end
        if($value$plusargs("WIDTH=%d",width)) begin end
        if($value$plusargs("COPY_MODE=%d",xy)) begin end
        if($value$plusargs("WAIT_STATES=%d",wait_states)) begin end
        if($value$plusargs("IRQ_AFTER=%d",irq_after)) begin end
        if($value$plusargs("PAUSE_CLOCKS=%d",pause_clocks)) begin end
        if((pixel_size!=1 && pixel_size!=2 && pixel_size!=4 && pixel_size!=8 && pixel_size!=16) ||
           (width!=16 && width!=32) || (xy<0 || xy>3) || wait_states<0 || pause_clocks<0 ||
           irq_after<1 || irq_after>width*pixel_size/8)
            $fatal(1,"invalid regular IRQ settings");
        execute(0); execute(1); execute(2); execute(3);
        if(irq_after!=width*pixel_size/8) execute(4);
        $finish;
    end
endmodule
