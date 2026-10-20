`timescale 1ns/1ps
`default_nettype none

// Compare a PIXBLT/FILL destination stream with and without a mid-array IRQ.
// All addresses are bit addresses. Delayed ACKs exercise request hold behavior.
module test;
    reg clk=0;
    always #5 clk=~clk;
    reg rst=1, cen=1, irq_req=0, nmi_req=0;
    reg nmi_nostack=0, halt_req=0;
    reg [15:0] pixel_size=16, plane_mask=0, control=0;
    wire mem_req, mem_we, mem_iaq, retire, fault;
    wire [31:0] mem_addr, mem_wdata, pc, st;
    wire [5:0] mem_size;
    wire [15:0] ir;
    reg [31:0] mem_rdata=0;
    reg mem_ack=0;
    reg [15:0] words [0:1023];
    reg [31:0] baseline_addr [0:255], baseline_data [0:255];
    reg [31:0] baseline_source_addr [0:15];
    reg [5:0] baseline_source_size [0:15];
    reg [15:0] baseline_mem [0:79];
    reg [31:0] baseline_b0, baseline_b2;
    integer baseline_count=0, drawn=0, retired=0, array_fetches=0;
    integer nmi_clears=0, stack_writes=0, halt_cycles=0;
    integer source_reads=0, baseline_source_reads=0;
    integer run_mode=0, variant=0, requests=0, delay_left=0, i;
    integer fill_size=16, fill_xy=0;
    reg [15:0] fill_width=4, nested_fill_expected=16'h5678;
    reg busy=0, irq_sent=0, handler_seen=0, pbx_seen=0;
    wire nmi_clear;
    reg [31:0] held_addr=0, held_data=0;
    reg [5:0] held_size=0;
    reg held_we=0, held_iaq=0;

    jttms10 u_cpu(
        .rst(rst), .clk(clk), .cen(cen),
        .psize(pixel_size), .convdp(16'd24), .convsp(16'd24),
        .control(control), .pmask(plane_mask), .wvp_set(), .mem_pixel(),
        .irq_req(irq_req), .irq_vector(32'hfffffec0),
        .nmi_req(nmi_req), .nmi_nostack(nmi_nostack), .halt_req(halt_req),
        .emu_run(1'b1), .nmi_clear(nmi_clear), .emu_ack(),
        .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_size(mem_size), .mem_iaq(mem_iaq),
        .mem_program(), .mem_post(), .mem_fast(), .mem_overlap(), .mem_reverse(), .mem_next_data(32'd0), .mem_next_valid(1'b0), .mem_next_first_valid(1'b0),
        .mem_rdata(mem_rdata), .mem_ack(mem_ack), .mem_cached(1'b0), .mem_busy(1'b0), .mem_phase(3'd0), .mem_slot(1'b1),
        .pc(pc), .st(st), .ir(ir), .retire(retire), .fault(fault)
    );

    function automatic [31:0] read_field(input [31:0] addr, input [5:0] size);
        integer bit_index;
        reg [31:0] physical;
        begin
            read_field=0;
            if (size==32 && addr==32'hffffffe0) read_field=32'h1000;
            else if (size==32 && addr==32'hfffffec0)
                read_field=variant>=6 ? 32'h1400 : 32'h1200;
            else if (size==32 && addr==32'hfffffee0)
                read_field=variant>=6 ? 32'h1400 : 32'h1200;
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

    task automatic put_movi(input integer at_word, input [3:0] regno,
                            input [31:0] value);
        begin
            words[at_word]=16'h09f0 | {12'd0,regno};
            words[at_word+1]=value[15:0];
            words[at_word+2]=value[31:16];
        end
    endtask

    task automatic load_program;
        begin
            for (i=0;i<1024;i=i+1) words[i]=16'h0300;
            put_movi('h100,4'd15,32'h3000); // SP
            put_movi('h103,4'd0,variant==0 ? 32'hface1234 :
                                    variant==2 ? 32'h0214 :
                                    variant>=3 ? 32'h020d : 32'h0204); // B0
            put_movi('h106,4'd1,variant>=3 ? 32'h00a0 : 32'h0080); // B1
            put_movi('h109,4'd2,variant==0 ? ((fill_xy!=0) ? 32'h00010000 : 32'h0600) :
                                    variant==2 ? 32'h0614 : 32'h0604); // B2
            put_movi('h10c,4'd3,variant>=3 ? 32'h0200 : 32'h0080); // B3
            put_movi('h10f,4'd7,variant>=3 ?
                ((32'd2 << 16) | (variant==3 ? 32'd32 :
                                 variant==4 ? 32'd33 : 32'd65)) :
                variant==0 ? {16'd2,fill_width} : 32'h00020005);
            // Native XY starts at Y=1 with OFFSET580 and pitch80 ->600.
            // FILL does not use binary COLOR0, so retain the program length.
            put_movi('h112,(variant==0 && fill_xy!=0) ? 4'd4 : 4'd8,
                     (variant==0 && fill_xy!=0) ? 32'h0580 : 32'h33333333);
            put_movi('h115,4'd9,variant>=3 ? 32'haaaaaaaa : 32'h55aa55aa);
            words['h118]=16'h0d60; // EINT
            words['h119]=variant==0 ? ((fill_xy!=0) ? 16'h0fe0 : 16'h0fc0) :
                         variant>=3 ? 16'h0f80 : 16'h0f00;
            words['h11a]=16'h0300; // next instruction after array
            words['h120]=16'h099f; words['h121]=16'hfffe; // MMTM B15, B0..B14
            put_movi('h122,4'd2,32'h0c00);
            put_movi('h125,4'd7,32'h00010001);
            put_movi('h128,4'd9,32'h12345678);
            words['h12b]=16'h0fc0; // nested one-pixel FILL L
            words['h12c]=16'h09bf; words['h12d]=16'h7fff; // MMFM B15, B0..B14
            words['h12e]=16'h0940; // RETI
            if (run_mode==3) words['h120]=16'h0300; // no-stack NMI abandons array
            if (variant>=6) begin
                // W3 clips DY=3 to rows Y=1..2. Variant 7 reverses both axes
                // and reads the full-color source through a linear pointer.
                put_movi('h103,4'd0,variant==7 ? 32'h0200 : 32'hface1234);
                put_movi('h106,4'd1,32'h0080);
                put_movi('h109,4'd2,32'd0); // XY=(0,0)
                put_movi('h10c,4'd3,32'h0080);
                put_movi('h10f,4'd7,32'h00030004); // DY=3, DX=4
                put_movi('h115,4'd9,32'h55aa55aa);
                put_movi('h118,4'd4,32'h0600); // OFFSET
                put_movi('h11b,4'd5,32'h00010000); // WSTART=(0,1)
                put_movi('h11e,4'd6,32'h00020003); // WEND=(3,2)
                words['h121]=16'h0d60; // EINT
                words['h122]=variant==6 ? 16'h0fe0 : 16'h0f20;
                words['h123]=16'h0300;
                words['h140]=16'h099f; words['h141]=16'hfffe;
                put_movi('h142,4'd2,32'h0c00);
                put_movi('h145,4'd7,32'h00010001);
                put_movi('h148,4'd9,32'h12345678);
                words['h14b]=16'h0fc0; // nested one-pixel FILL L
                words['h14c]=16'h09bf; words['h14d]=16'h7fff;
                words['h14e]=16'h0940;
            end
            for (i='h60;i<='h9f;i=i+1) words[i]=16'hc33c;
            for (i='h20;i<='h3f;i=i+1) words[i]=16'h1357 ^ (i[15:0]*16'h0111);
            words['hc0]=16'hbeef;
        end
    endtask

    always @(posedge clk) begin
        mem_ack<=0;
        if (rst) begin
            busy<=0;
            requests<=0;
            stack_writes<=0;
        end else if (mem_ack) begin
            mem_ack<=0;
        end else if (!busy && mem_req) begin
            held_addr<=mem_addr;
            held_data<=mem_wdata;
            held_size<=mem_size;
            held_we<=mem_we;
            held_iaq<=mem_iaq;
            delay_left<=2+(requests%3);
            requests<=requests+1;
            busy<=1;
            if (mem_iaq && mem_addr==(variant>=6 ? 32'h1220 : 32'h1190))
                array_fetches<=array_fetches+1;
            if ((variant>=3 && variant<=5 || variant==7) &&
                !mem_we && mem_addr>=32'h0200 &&
                mem_addr<32'h0400) begin
                if (source_reads>=16) $fatal(1,"too many binary source reads");
                if (run_mode==0) begin
                    baseline_source_addr[source_reads]=mem_addr;
                    baseline_source_size[source_reads]=mem_size;
                end else if (source_reads>=baseline_source_reads ||
                             mem_addr!==baseline_source_addr[source_reads] ||
                             mem_size!==baseline_source_size[source_reads])
                    $fatal(1,"source read[%0d] @%h/%0d expected @%h/%0d",
                        source_reads,mem_addr,mem_size,
                        baseline_source_addr[source_reads],
                        baseline_source_size[source_reads]);
                source_reads<=source_reads+1;
            end
        end else if (busy) begin
            if (!mem_req || mem_addr!==held_addr || mem_size!==held_size ||
                mem_we!==held_we || mem_iaq!==held_iaq ||
                (held_we && mem_wdata!==held_data))
                $fatal(1,"held request changed @%h",held_addr);
            if (delay_left!=0) delay_left<=delay_left-1;
            else begin
                if (held_we) begin
                    write_field(held_addr,held_size,held_data);
                    if (held_addr>=32'h2d00 && held_addr<32'h3000)
                        stack_writes<=stack_writes+1;
                    if (held_addr>=32'h0600 && held_addr<32'h0a00) begin
                        if (variant==0 && held_size!==6'd16)
                            $fatal(1,"FILL PS%0d expected full-word write, observed %0d bits",fill_size,held_size);
                        if (drawn>=256) $fatal(1,"too many array writes");
                        if (run_mode==0) begin
                            baseline_addr[drawn]=held_addr;
                            baseline_data[drawn]=held_data;
                        end else if (drawn>=baseline_count ||
                                     held_addr!==baseline_addr[drawn] ||
                                     held_data!==baseline_data[drawn])
                            $fatal(1,"array stream[%0d] @%h=%h expected @%h=%h",
                                drawn,held_addr,held_data,
                                baseline_addr[drawn],baseline_data[drawn]);
                        drawn<=drawn+1;
                        if (run_mode!=0 && !irq_sent) begin
                            if (run_mode>=2) nmi_req<=1;
                            else irq_req<=1;
                            if (run_mode==4) halt_req<=1;
                            irq_sent<=1;
                        end
                    end
                end else mem_rdata<=read_field(held_addr,held_size);
                mem_ack<=1;
                busy<=0;
            end
        end
    end

    always @(posedge retire) begin
        #1;
        if (fault) $fatal(1,"fault IR=%h PC=%h",ir,pc);
        retired=retired+1;
    end

    always @(posedge clk) if (!rst && nmi_clear) nmi_clears<=nmi_clears+1;

    always @(negedge clk) if (!rst && run_mode!=0) begin
        if (pc==(variant>=6 ? 32'h1400 : 32'h1200) && !handler_seen) begin
            handler_seen=1;
            irq_req=0;
            nmi_req=0;
            if (retired!=(variant>=6 ? 12 : 9) ||
                drawn!=(variant>=6 ? 4 :
                         (variant==1 || variant>=3) ? 3 : 1))
                $fatal(1,"IRQ entered outside first destination checkpoint: retire=%0d writes=%0d",
                    retired,drawn);
            if (run_mode==3) begin
                if (stack_writes!=0 || u_cpu.u_regs.ram0[15]!==32'h3000)
                    $fatal(1,"no-stack NMI wrote context: writes=%0d SP=%h",
                        stack_writes,u_cpu.u_regs.ram0[15]);
            end else if ((read_field(32'h2fc0,32) & 32'h02200010)!==32'h02200010 ||
                         read_field(32'h2fe0,32)!==
                             (variant>=6 ? 32'h1230 : 32'h11a0))
                $fatal(1,"PBX stack ST=%h PC=%h",
                    read_field(32'h2fc0,32),read_field(32'h2fe0,32));
            if (variant>=3 && variant<=5 && run_mode!=3 &&
                (source_reads!=1 ||
                               baseline_source_addr[0]!==32'h020d ||
                               baseline_source_size[0]!==6'd32 ||
                               u_cpu.u_regs.ram0[16]!==32'h022d))
                $fatal(1,"binary source checkpoint reads=%0d B0=%h first=%h/%0d",
                    source_reads,u_cpu.u_regs.ram0[16],
                    baseline_source_addr[0],baseline_source_size[0]);
            if (variant>=6 && run_mode!=3) begin
                if (u_cpu.u_regs.ram0[26]!==
                        (variant==6 ? 32'h00040fe0 : 32'h00040f20) ||
                    u_cpu.u_regs.ram0[28]!==
                        (variant==6 ? 32'd0 : 32'h00020000) ||
                    (variant==7 &&
                        (u_cpu.u_regs.ram0[29]!==32'h00000290 ||
                         u_cpu.u_regs.ram0[30]!==32'h00000690)))
                    $fatal(1,"W3 PBX image B10=%h B12=%h B13=%h B14=%h",
                        u_cpu.u_regs.ram0[26],u_cpu.u_regs.ram0[28],
                        u_cpu.u_regs.ram0[29],u_cpu.u_regs.ram0[30]);
            end
            if ((variant==0 || variant==6) && run_mode!=3 &&
                u_cpu.u_regs.ram0[16]!==32'hface1234)
                $fatal(1,"FILL checkpoint changed B0=%h",u_cpu.u_regs.ram0[16]);
            if (run_mode!=3) pbx_seen=1;
        end
        if (run_mode==4 && handler_seen && halt_req) begin
            if (halt_cycles>0 && (mem_req || retired!=9))
                $fatal(1,"HLT allowed handler fetch/retire before release");
            halt_cycles=halt_cycles+1;
            if (halt_cycles==20) halt_req=0;
        end
    end

    task automatic execute(input integer mode);
        integer timeout, row, segment, index, width, remaining, expected_size;
        begin
            run_mode=mode;
            pixel_size=variant==0 ? fill_size[15:0] : 16'd4;
            plane_mask=(variant==0 || variant>=3) ? 16'd0 : 16'h2222;
            control=variant==6 ? 16'h00c0 :
                    variant==7 ? 16'h03c0 :
                    (variant==0 || variant>=3) ? 16'd0 :
                    variant==2 ? 16'h2900 : 16'h2800; // XOR + optional PBH
            rst=1;
            irq_req=0;
            nmi_req=0;
            nmi_nostack=(mode==3);
            halt_req=0;
            irq_sent=0;
            handler_seen=0;
            pbx_seen=0;
            drawn=0;
            retired=0;
            array_fetches=0;
            source_reads=0;
            nmi_clears=0;
            halt_cycles=0;
            load_program();
            repeat(5) @(negedge clk);
            rst=0;
            timeout=0;
            while (retired<(variant>=6 ? (mode==0 ? 13 : 20) :
                           (mode==0 ? 11 : mode==3 ? 10 : 18)) &&
                   timeout<30000) begin
                @(negedge clk);
                timeout=timeout+1;
            end
            if (timeout>=30000) $fatal(1,"PBX timeout mode=%0d variant=%0d PC=%h ST=%h IR=%h retires=%0d writes=%0d B0=%h B2=%h B7=%h B10=%h B14=%h uaddr=%h",
                                       mode,variant,pc,st,ir,retired,drawn,
                                       u_cpu.u_regs.ram0[16],u_cpu.u_regs.ram0[18],
                                       u_cpu.u_regs.ram0[23],u_cpu.u_regs.ram0[26],
                                       u_cpu.u_regs.ram0[30],u_cpu.u_ctrl.uaddr);
            if (mode==3) begin
                if (!irq_sent || !handler_seen || nmi_clears!=1 ||
                    retired!=10 || drawn!=3 || source_reads!=1 ||
                    array_fetches!=1 || stack_writes!=0 ||
                    u_cpu.u_regs.ram0[15]!==32'h3000 ||
                    words['hc0]!==16'hbeef)
                    $fatal(1,"no-stack NMI failed: retires=%0d writes=%0d src=%0d stack=%0d",
                        retired,drawn,source_reads,stack_writes);
            end else begin
            if (drawn!=(variant>=6 ? 8 : variant==0 ? 8 : variant>=3 ?
                          2*(variant==3 ? 32 : variant==4 ? 33 : 65) : 10) ||
                array_fetches!=1 ||
                (variant<6 && u_cpu.u_regs.ram0[18] !==
                    (variant==0 ? 32'h06c0 : variant==2 ? 32'h0714 :
                     variant>=3 ? 32'h0a04 : 32'h0704)))
                $fatal(1,"completion mode=%0d writes=%0d fetches=%0d B2=%h",
                    mode,drawn,array_fetches,u_cpu.u_regs.ram0[18]);
            if (mode!=0 && (!irq_sent || !handler_seen || !pbx_seen ||
                            u_cpu.u_regs.ram0[15]!==32'h3000 ||
                            words['hc0] !== (variant==0 ? nested_fill_expected :
                                             variant>=3 ? 16'hbee8 : 16'hbee7)))
                $fatal(1,"IRQ/ISR result SP=%h nested=%h",u_cpu.u_regs.ram0[15],words['hc0]);
            if ((variant==0 || variant==6) &&
                u_cpu.u_regs.ram0[16]!==32'hface1234)
                $fatal(1,"FILL completion changed B0=%h",u_cpu.u_regs.ram0[16]);
            if ((mode==2 || mode==4) && nmi_clears!=1)
                $fatal(1,"NMI clear pulse count=%0d",nmi_clears);
            if (mode==4 && halt_cycles!=20)
                $fatal(1,"HLT did not hold ISR fetch for 20 clocks");
            if (variant>=3 && variant<=5 && source_reads !=
                              2*(variant==3 ? 1 : variant==4 ? 2 : 3))
                $fatal(1,"binary source segment count variant=%0d count=%0d",
                    variant,source_reads);
            if (variant>=3 && variant<=5 && u_cpu.u_regs.ram0[16]!==32'h034d)
                $fatal(1,"binary B0 completion variant=%0d value=%h",
                    variant,u_cpu.u_regs.ram0[16]);
            if (variant>=3 && variant<=5 && mode==0) begin
                width=variant==3 ? 32 : variant==4 ? 33 : 65;
                index=0;
                for (row=0;row<2;row=row+1)
                    for (segment=0;segment<(width+31)/32;segment=segment+1) begin
                        remaining=width-segment*32;
                        expected_size=remaining>32 ? 32 : remaining;
                        if (baseline_source_addr[index] !==
                                32'h020d+row*32'h00a0+segment*32 ||
                            baseline_source_size[index] !== expected_size[5:0])
                            $fatal(1,"binary source segment[%0d] @%h/%0d expected @%h/%0d",
                                index,baseline_source_addr[index],
                                baseline_source_size[index],
                                32'h020d+row*32'h00a0+segment*32,expected_size);
                        index=index+1;
                    end
            end
            end
        end
    endtask

    initial begin
        if ($value$plusargs("FILL_PSIZE=%d",fill_size)) begin end
        if ($value$plusargs("FILL_XY=%d",fill_xy)) begin end
        if (fill_xy!=0 && fill_xy!=1) $fatal(1,"invalid FILL_XY mode");
        case (fill_size)
            1: begin fill_width=64; nested_fill_expected=16'hbeee; end
            2: begin fill_width=32; nested_fill_expected=16'hbeec; end
            4: begin fill_width=16; nested_fill_expected=16'hbee8; end
            8: begin fill_width=8; nested_fill_expected=16'hbe78; end
            16: begin fill_width=4; nested_fill_expected=16'h5678; end
            default: $fatal(1,"invalid FILL_PSIZE=%0d",fill_size);
        endcase
        $display("FILL checkpoint pixel size: %0d",fill_size);
        for (variant=0;variant<(fill_size==16 && fill_xy==0 ? 8 : 1);variant=variant+1) begin
            execute(0);
            baseline_count=drawn;
            baseline_b0=u_cpu.u_regs.ram0[16];
            baseline_b2=u_cpu.u_regs.ram0[18];
            baseline_source_reads=source_reads;
            for (i=0;i<80;i=i+1) baseline_mem[i]=words['h60+i];
            execute(1);
            if (variant>=6 &&
                (u_cpu.u_regs.ram0[16]!==baseline_b0 ||
                 u_cpu.u_regs.ram0[18]!==baseline_b2))
                $fatal(1,"W3 canonical B0/B2 mismatch %h/%h expected %h/%h",
                    u_cpu.u_regs.ram0[16],u_cpu.u_regs.ram0[18],
                    baseline_b0,baseline_b2);
            if (source_reads!=baseline_source_reads)
                $fatal(1,"source stream count variant%0d=%0d expected%0d",
                    variant,source_reads,baseline_source_reads);
            for (i=0;i<80;i=i+1)
                if (words['h60+i]!==baseline_mem[i])
                    $fatal(1,"variant%0d destination word %0d=%h expected %h",
                        variant,i,words['h60+i],baseline_mem[i]);
            $display("PASS: PBX variant %0d resumes %0d destination writes",
                     variant,drawn);
            if (variant==0) begin
                execute(2);
                for (i=0;i<80;i=i+1)
                    if (words['h60+i]!==baseline_mem[i])
                        $fatal(1,"FILL NMI PS%0d destination word %0d differs",fill_size,i);
                if (fill_xy!=0)
                    $display("PASS: FILL XY PS%0d IRQ/NMI resumes eight full-word writes",fill_size);
                else
                    $display("PASS: FILL PS%0d IRQ/NMI resumes eight full-word writes",fill_size);
            end
            if (variant==4) begin
                execute(2); // NMI uses the same word checkpoint without IE gating.
                if (source_reads!=baseline_source_reads)
                    $fatal(1,"NMI source stream count=%0d expected=%0d",
                        source_reads,baseline_source_reads);
                for (i=0;i<80;i=i+1)
                    if (words['h60+i]!==baseline_mem[i])
                        $fatal(1,"NMI destination word %0d=%h expected %h",
                            i,words['h60+i],baseline_mem[i]);
                $display("PASS: PBX NMI binary DX33 resumes %0d destination writes",
                         drawn);
                execute(3); // no-stack NMI abandons the interrupted array.
                $display("PASS: no-stack NMI abandons array without a PBX stack");
                execute(4); // NMI wins over simultaneous HLT; ISR waits for release.
                if (source_reads!=baseline_source_reads)
                    $fatal(1,"NMI+HLT source stream count=%0d expected=%0d",
                        source_reads,baseline_source_reads);
                for (i=0;i<80;i=i+1)
                    if (words['h60+i]!==baseline_mem[i])
                        $fatal(1,"NMI+HLT destination word %0d=%h expected %h",
                            i,words['h60+i],baseline_mem[i]);
                $display("PASS: PBX NMI+HLT stacks context and resumes after release");
            end
        end
        $finish;
    end
endmodule
`default_nettype wire
