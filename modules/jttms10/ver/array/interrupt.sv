`timescale 1ns/1ps
`default_nettype none

// Compare a PIXBLT/FILL destination stream with and without a mid-array IRQ.
// All addresses are bit addresses. Delayed ACKs exercise request hold behavior.
module test;
    reg clk=0;
    always #5 clk=~clk;
    reg rst=1, cen=1, irq_req=0;
    reg [15:0] pixel_size=16, plane_mask=0, control=0;
    wire mem_req, mem_we, mem_iaq, retire, fault;
    wire [31:0] mem_addr, mem_wdata, pc, st;
    wire [5:0] mem_size;
    wire [15:0] ir;
    reg [31:0] mem_rdata=0;
    reg mem_ack=0;
    reg [15:0] words [0:1023];
    reg [31:0] baseline_addr [0:31], baseline_data [0:31];
    reg [15:0] baseline_mem [0:31];
    integer baseline_count=0, drawn=0, retired=0, array_fetches=0;
    integer run_mode=0, variant=0, requests=0, delay_left=0, i;
    reg busy=0, irq_sent=0, handler_seen=0, pbx_seen=0;
    reg [31:0] held_addr=0, held_data=0;
    reg [5:0] held_size=0;
    reg held_we=0, held_iaq=0;

    jttms10 u_cpu(
        .rst(rst), .clk(clk), .cen(cen),
        .psize(pixel_size), .convdp(16'd24), .convsp(16'd24),
        .control(control), .pmask(plane_mask), .wvp_set(), .mem_pixel(),
        .irq_req(irq_req), .irq_vector(32'hfffffec0),
        .nmi_req(1'b0), .nmi_nostack(1'b0), .halt_req(1'b0),
        .emu_run(1'b1), .nmi_clear(), .emu_ack(),
        .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_size(mem_size), .mem_iaq(mem_iaq),
        .mem_program(), .mem_rdata(mem_rdata), .mem_ack(mem_ack),
        .pc(pc), .st(st), .ir(ir), .retire(retire), .fault(fault)
    );

    function automatic [31:0] read_field(input [31:0] addr, input [5:0] size);
        integer bit_index;
        reg [31:0] physical;
        begin
            read_field=0;
            if (size==32 && addr==32'hffffffe0) read_field=32'h1000;
            else if (size==32 && addr==32'hfffffec0) read_field=32'h1200;
            else begin
                if (size<1 || size>32 || addr+size>32'd16384)
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
            if (size<1 || size>32 || addr+size>32'd16384)
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
            words[at_word]=16'h09f0 | regno;
            words[at_word+1]=value[15:0];
            words[at_word+2]=value[31:16];
        end
    endtask

    task automatic load_program;
        begin
            for (i=0;i<1024;i=i+1) words[i]=16'h0300;
            put_movi('h100,4'd15,32'h3000); // SP
            put_movi('h103,4'd0,variant==0 ? 32'd0 :
                                    variant==2 ? 32'h0214 : 32'h0204); // B0
            put_movi('h106,4'd1,32'h0080);  // B1 SPTCH
            put_movi('h109,4'd2,variant==0 ? 32'h0600 :
                                    variant==2 ? 32'h0614 : 32'h0604); // B2
            put_movi('h10c,4'd3,32'h0080);  // B3 DPTCH
            put_movi('h10f,4'd7,variant==0 ? 32'h00020004 : 32'h00020005);
            put_movi('h112,4'd9,32'h55aa55aa); // COLOR1 for FILL/ISR
            words['h115]=16'h0d60; // EINT
            words['h116]=variant==0 ? 16'h0fc0 : 16'h0f00; // FILL L / PIXBLT L,L
            words['h117]=16'h0300; // next instruction after array
            words['h120]=16'h099f; words['h121]=16'hfffe; // MMTM B15, B0..B14
            put_movi('h122,4'd2,32'h0900);
            put_movi('h125,4'd7,32'h00010001);
            put_movi('h128,4'd9,32'h12345678);
            words['h12b]=16'h0fc0; // nested one-pixel FILL L
            words['h12c]=16'h09bf; words['h12d]=16'h7fff; // MMFM B15, B0..B14
            words['h12e]=16'h0940; // RETI
            for (i='h60;i<='h6f;i=i+1) words[i]=16'hc33c;
            for (i='h20;i<='h2f;i=i+1) words[i]=16'h1357 ^ (i*16'h0111);
            words['h90]=16'hbeef;
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
            delay_left<=2+(requests%3);
            requests<=requests+1;
            busy<=1;
            if (mem_iaq && mem_addr==32'h1160) array_fetches<=array_fetches+1;
        end else if (busy) begin
            if (!mem_req || mem_addr!==held_addr || mem_size!==held_size ||
                mem_we!==held_we || mem_iaq!==held_iaq ||
                (held_we && mem_wdata!==held_data))
                $fatal(1,"held request changed @%h",held_addr);
            if (delay_left!=0) delay_left<=delay_left-1;
            else begin
                if (held_we) begin
                    write_field(held_addr,held_size,held_data);
                    if (held_addr>=32'h0600 && held_addr<32'h0700) begin
                        if (drawn>=32) $fatal(1,"too many array writes");
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
                        if (run_mode==1 && !irq_sent) begin
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

    always @(posedge retire) begin
        #1;
        if (fault) $fatal(1,"fault IR=%h PC=%h",ir,pc);
        retired=retired+1;
    end

    always @(negedge clk) if (!rst && run_mode==1) begin
        if (pc==32'h1200 && !handler_seen) begin
            handler_seen=1;
            irq_req=0;
            if (retired!=8 || drawn!=(variant==1 ? 3 : 1))
                $fatal(1,"IRQ entered outside first destination checkpoint: retire=%0d writes=%0d",
                    retired,drawn);
            if (read_field(32'h2fc0,32)!==32'h02200010 ||
                read_field(32'h2fe0,32)!==32'h1170)
                $fatal(1,"PBX stack ST=%h PC=%h",
                    read_field(32'h2fc0,32),read_field(32'h2fe0,32));
            pbx_seen=1;
        end
    end

    task automatic execute(input integer mode);
        integer timeout;
        begin
            run_mode=mode;
            pixel_size=variant==0 ? 16'd16 : 16'd4;
            plane_mask=variant==0 ? 16'd0 : 16'h2222;
            control=variant==0 ? 16'd0 :
                    variant==2 ? 16'h2900 : 16'h2800; // XOR + optional PBH
            rst=1;
            irq_req=0;
            irq_sent=0;
            handler_seen=0;
            pbx_seen=0;
            drawn=0;
            retired=0;
            array_fetches=0;
            load_program();
            repeat(5) @(negedge clk);
            rst=0;
            timeout=0;
            while (retired<(mode==0 ? 10 : 17) && timeout<20000) begin
                @(negedge clk);
                timeout=timeout+1;
            end
            if (timeout>=20000) $fatal(1,"PBX timeout mode=%0d PC=%h ST=%h IR=%h retires=%0d writes=%0d B0=%h B2=%h B7=%h B10=%h B14=%h uaddr=%h",
                                       mode,pc,st,ir,retired,drawn,
                                       u_cpu.u_regs.ram0[16],u_cpu.u_regs.ram0[18],
                                       u_cpu.u_regs.ram0[23],u_cpu.u_regs.ram0[26],
                                       u_cpu.u_regs.ram0[30],u_cpu.u_ctrl.uaddr);
            if (drawn!=(variant==0 ? 8 : 10) || array_fetches!=1 ||
                u_cpu.u_regs.ram0[18] !== (variant==0 ? 32'h06c0 :
                                          variant==2 ? 32'h0714 : 32'h0704))
                $fatal(1,"completion mode=%0d writes=%0d fetches=%0d B2=%h",
                    mode,drawn,array_fetches,u_cpu.u_regs.ram0[18]);
            if (mode==1 && (!irq_sent || !handler_seen || !pbx_seen ||
                            u_cpu.u_regs.ram0[15]!==32'h3000 ||
                            words['h90] !== (variant==0 ? 16'h5678 : 16'hbee7)))
                $fatal(1,"IRQ/ISR result SP=%h nested=%h",u_cpu.u_regs.ram0[15],words['h90]);
        end
    endtask

    initial begin
        for (variant=0;variant<3;variant=variant+1) begin
            execute(0);
            baseline_count=drawn;
            for (i=0;i<32;i=i+1) baseline_mem[i]=words['h60+i];
            execute(1);
            for (i=0;i<32;i=i+1)
                if (words['h60+i]!==baseline_mem[i])
                    $fatal(1,"variant%0d destination word %0d=%h expected %h",
                        variant,i,words['h60+i],baseline_mem[i]);
            $display("PASS: PBX variant %0d resumes %0d destination writes",
                     variant,drawn);
        end
        $finish;
    end
endmodule
`default_nettype wire
