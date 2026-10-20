`timescale 1ns/1ps
`default_nettype none

// Timed word/fabric LINE IRQ checkpoint: published B0/B2/B10 state, PC rewind, PBX clear,
// nested graphics under MMTM/MMFM, and exact continuation of pixel writes.
module test;
    reg clk=0;
    always #5 clk=~clk;
    reg rst=1, cen=1, irq_req=0;
    wire mem_req, mem_we, mem_iaq, retire, fault;
    wire word_req,word_pending,word_early,word_we,word_iaq,word_pixel,word_lock;
    wire word_ack,word_restart,word_wait;
    wire [31:0] word_addr;
    wire [15:0] word_wdata,word_rdata;
    wire [3:0] cycle_kind;
    wire [15:0] cycle_wdata;
    wire [5:0] mem_size=6'd16;
    assign mem_we=cycle_kind==4'd1;
    assign mem_wdata={16'd0,cycle_wdata};
    integer wait_states=0,irq_after=1,rc;
    wire [31:0] expected_left=run_mode==2 ? 32'h00010000 : 32'd4-32'(irq_after);
    wire [31:0] expected_xy=run_mode==2 ? 32'h00020003 : 32'h00020002+32'(irq_after);
    wire [31:0] mem_addr, mem_wdata, pc, st;
    wire [15:0] ir;
    reg [31:0] mem_rdata=0;
    reg mem_ack=0;
    reg [15:0] words [0:1023];
    reg [31:0] baseline_addr [0:7], baseline_data [0:7];
    reg [15:0] baseline_word0=0, baseline_word1=0;
    integer retired=0, drawn=0, line_fetches=0, baseline_count=0;
    integer run_mode=0, requests=0, delay_left=0, i;
    reg busy=0, irq_sent=0, handler_seen=0;
    reg [31:0] held_addr=0, held_data=0;
    reg [5:0] held_size=0;
    reg held_we=0, held_iaq=0;

    jttms10_word #(.TIMED_PROGRAM(1)) u_cpu(
        .rst(rst), .clk(clk), .cen(cen),
        .psize(16'd4), .convdp(16'd24), .convsp(16'd24),
        .control(16'd0), .pmask(16'd0), .wvp_set(),
        .irq_req(irq_req), .irq_vector(32'hfffffec0),
        .halted(), .nmi_req(1'b0), .nmi_nostack(1'b0), .halt_req(1'b0),
        .emu_run(1'b1), .nmi_clear(), .emu_ack(),
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
        .cyc_rdata(mem_rdata[15:0]),.cyc_ack(mem_ack)
    );

    function automatic [31:0] read_field(input [31:0] addr, input [5:0] size);
        integer bit_index;
        reg [31:0] physical;
        begin
            read_field=0;
            if ((size==32 || size==16) && addr==32'hffffffe0) read_field=32'h1000;
            else if (size==16 && (addr==32'hfffffff0 || addr==32'hfffffed0)) read_field=0;
            else if ((size==32 || size==16) && addr==32'hfffffec0) read_field=32'h1300;
            else begin
                if (size<1 || size>32 || addr+{26'd0,size}>32'd16384)
                    $fatal(1,"invalid read @%h/%0d",addr,size);
                for (bit_index=0;bit_index<size;bit_index=bit_index+1) begin
                    physical=addr+bit_index;
                    read_field[bit_index]=words[physical>>4][physical[3:0]];
                end
            end
        end
    endfunction

    task automatic write_field(input [31:0] addr, input [5:0] size,
                               input [31:0] data);
        integer bit_index;
        reg [31:0] physical;
        begin
            if (size<1 || size>32 || addr+{26'd0,size}>32'd16384)
                $fatal(1,"invalid write @%h/%0d",addr,size);
            for (bit_index=0;bit_index<size;bit_index=bit_index+1) begin
                physical=addr+bit_index;
                words[physical>>4][physical[3:0]]=data[bit_index];
            end
        end
    endtask

    task automatic put_movi(input integer at_word, input [3:0] register,
                            input [31:0] value);
        begin
            words[at_word]=16'h09f0 | {12'd0,register};
            words[at_word+1]=value[15:0];
            words[at_word+2]=value[31:16];
        end
    endtask

    task automatic load_program;
        begin
            for (i=0;i<1024;i=i+1) words[i]=16'h0300;
            words['h30]=16'hc33c; words['h31]=16'ha55a;
            words['hc0]=16'hbeef;
            put_movi('h100,4'd15,32'h3000); // SP
            put_movi('h103,4'd0,32'hfffffffd); // d=-3
            put_movi('h106,4'd2,32'h00020002); // XY=(2,2)
            put_movi('h109,4'd4,32'h0200); // OFFSET
            put_movi('h10c,4'd7,32'h00000003); // b=0,a=3
            put_movi('h10f,4'd9,32'h77777777); // COLOR1
            put_movi('h112,4'd10,run_mode==2 ? 32'h00010001 : 32'd4);
            put_movi('h115,4'd11,32'h00010001); // INC1
            put_movi('h118,4'd12,32'h00000001); // INC2 +X
            put_movi('h11b,4'd13,32'hffffffff); // PATTRN required
            words['h11e]=16'h0d60; // EINT
            words['h11f]=16'hdf1a; // LINE0
            words['h120]=16'h0300; // next opcode
            words['h130]=16'h099f; words['h131]=16'hfffe; // MMTM B15, B0..14
            put_movi('h132,4'd2,32'h0c00);
            put_movi('h135,4'd3,32'h0080);
            put_movi('h138,4'd7,32'h00010001);
            put_movi('h13b,4'd9,32'h12345678);
            words['h13e]=16'h0fc0; // nested one-pixel FILL L
            words['h13f]=16'h09bf; words['h140]=16'h7fff; // MMFM B15
            words['h141]=16'h0940; // RETI
        end
    endtask

    always @(posedge clk) begin
        mem_ack<=0;
        if (rst) begin
            busy<=0;
            requests<=0;
        end else if (mem_ack) begin
            mem_ack<=0;
        end else if (!busy && mem_req) begin
            held_addr<=mem_addr;
            held_data<=mem_wdata;
            held_size<=mem_size;
            held_we<=mem_we;
            held_iaq<=mem_iaq;
            delay_left<=2+8*wait_states;
            requests<=requests+1;
            busy<=1;

        end else if (busy) begin
            if (!mem_req || mem_addr!==held_addr || mem_size!==held_size ||
                mem_we!==held_we || mem_iaq!==held_iaq ||
                (held_we && mem_wdata!==held_data))
                $fatal(1,"held request changed @%h",held_addr);
            if (delay_left!=0) delay_left<=delay_left-1;
            else begin
                if (held_we) begin
                    write_field(held_addr,held_size,held_data);
                    if (held_addr>=32'h0300 && held_addr<32'h0320) begin
                        if (drawn>=8) $fatal(1,"too many LINE writes");
                        if (run_mode==0) begin
                            baseline_addr[drawn]=held_addr;
                            baseline_data[drawn]=held_data;
                        end else if (drawn>=baseline_count ||
                                     held_addr!==baseline_addr[drawn] ||
                                     held_data!==baseline_data[drawn])
                            $fatal(1,"LINE pixel[%0d] @%h=%h expected @%h=%h",
                                drawn,held_addr,held_data,
                                baseline_addr[drawn],baseline_data[drawn]);
                        drawn<=drawn+1;
                        if (run_mode!=0 && !irq_sent && drawn+1==(run_mode==2 ? 1 : irq_after)) begin
                            irq_req<=1;
                            irq_sent<=1;
                        end
                    end
                end else mem_rdata<=read_field(held_addr,held_size);
                mem_ack<=1;
                busy<=0;
            end
        end
    end

    always @(posedge clk) if(!rst && u_cpu.u_core.step && u_cpu.u_core.ld_ir && pc==32'h11f0)
        line_fetches<=line_fetches+1;

    always @(posedge retire) begin
        #1;
        if (fault) $fatal(1,"fault IR=%h PC=%h",ir,pc);
        retired=retired+1;
    end

    always @(negedge clk) if (!rst && run_mode!=0) begin
        if (pc==32'h1300 && !handler_seen) begin
            handler_seen=1;
            irq_req=0;
            if (retired!=11 || drawn!=(run_mode==2 ? 1 : irq_after) ||
                (read_field(32'h2fc0,32) & 32'h02200000)!==32'h00200000 ||
                read_field(32'h2fe0,32)!==32'h11f0 ||
                u_cpu.u_core.u_regs.ram0[26] !==
                    expected_left ||
                u_cpu.u_core.u_regs.ram0[18]!==expected_xy)
                $fatal(1,"LINE IRQ checkpoint retire=%0d writes=%0d ST=%h PC=%h B10=%h B2=%h",
                    retired,drawn,read_field(32'h2fc0,32),
                    read_field(32'h2fe0,32),u_cpu.u_core.u_regs.ram0[26],
                    u_cpu.u_core.u_regs.ram0[18]);
        end
    end

    task automatic execute(input integer mode);
        integer timeout;
        begin
            run_mode=mode;
            rst=1;
            irq_req=0;
            irq_sent=0;
            handler_seen=0;
            drawn=0;
            retired=0;
            line_fetches=0;
            load_program();
            repeat(5) @(negedge clk);
            rst=0;
            timeout=0;
            if (mode==2) begin
                while (!handler_seen && timeout<10000) begin
                    @(negedge clk);
                    timeout=timeout+1;
                end
                if (timeout>=10000 || retired!=11 || drawn!=(run_mode==2 ? 1 : irq_after) ||
                    line_fetches!=1 || u_cpu.u_core.u_regs.ram0[26]!==32'h00010000)
                    $fatal(1,"wide COUNT checkpoint timeout=%0d retire=%0d pixels=%0d B10=%h",
                        timeout,retired,drawn,u_cpu.u_core.u_regs.ram0[26]);
            end else begin
                while (retired<(mode==0 ? 13 : 21) && timeout<30000) begin
                    @(negedge clk);
                    timeout=timeout+1;
                end
                if (timeout>=30000) $fatal(1,"LINE timeout mode=%0d PC=%h ST=%h IR=%h retired=%0d writes=%0d uaddr=%h",
                    mode,pc,st,ir,retired,drawn,u_cpu.u_core.u_ctrl.uaddr);
                if (drawn!=4 || line_fetches!=(mode==0 ? 1 : 2) ||
                    u_cpu.u_core.u_regs.ram0[16]!==32'hfffffffd ||
                    u_cpu.u_core.u_regs.ram0[18]!==32'h00020006 ||
                    u_cpu.u_core.u_regs.ram0[26]!==32'd0)
                    $fatal(1,"LINE completion mode=%0d writes=%0d fetches=%0d d=%h B2=%h COUNT=%h",
                        mode,drawn,line_fetches,u_cpu.u_core.u_regs.ram0[16],
                        u_cpu.u_core.u_regs.ram0[18],u_cpu.u_core.u_regs.ram0[26]);
                if (mode==1 && (!irq_sent || !handler_seen ||
                                u_cpu.u_core.u_regs.ram0[15]!==32'h3000 ||
                                words['hc0]!==16'hbee8))
                    $fatal(1,"LINE ISR result SP=%h nested=%h",u_cpu.u_core.u_regs.ram0[15],words['hc0]);
            end
        end
    endtask

    initial begin
        rc=$value$plusargs("WAIT_STATES=%d",wait_states);
        rc=$value$plusargs("IRQ_AFTER=%d",irq_after);
        if(irq_after<1 || irq_after>3 || wait_states<0 || wait_states>3) $fatal(1,"invalid timed LINE preset");
        execute(0);
        baseline_count=drawn;
        baseline_word0=words['h30]; baseline_word1=words['h31];
        execute(1);
        if (words['h30]!==baseline_word0 || words['h31]!==baseline_word1)
            $fatal(1,"LINE final words differ from baseline");
        $display("PASS: timed LINE IRQ after pixel%0d W%0d resumes %0d physical writes",irq_after,wait_states,drawn);
        execute(2);
        $display("PASS: LINE wide COUNT publishes 0x10000 at first IRQ checkpoint");
        $finish;
    end
endmodule
`default_nettype wire
