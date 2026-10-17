`timescale 1ns/1ps
`default_nettype none

// Architectural system-control checks. All addresses are bit addresses.
// The responder deliberately stalls every request for two or three clocks.
module test;
    reg clk=0;
    always #5 clk=~clk;
    reg rst=1, cen=1;
    reg irq_req=0, nmi_req=0, nmi_nostack=0, halt_req=0, emu_run=1;
    reg [31:0] irq_vector=32'hfffffec0; // level 9
    wire nmi_clear, emu_ack, mem_req, mem_we, mem_iaq, retire, fault;
    wire [31:0] mem_addr, mem_wdata, pc, st;
    wire [5:0] mem_size;
    wire [15:0] ir;
    reg [31:0] mem_rdata=0;
    reg mem_ack=0;
    reg [15:0] words [0:1023];
    integer retired=0, requests=0, writes=0, nmi_clears=0;
    reg [31:0] held_addr=0, held_data=0;
    reg [5:0] held_size=0;
    reg held_we=0, held_iaq=0, busy=0;
    integer delay_left=0;
    integer i, mode;

    jttms10 u_cpu(
        .rst(rst), .clk(clk), .cen(cen),
        .psize(16'd16), .convdp(16'h14),
        .irq_req(irq_req), .irq_vector(irq_vector),
        .nmi_req(nmi_req), .nmi_nostack(nmi_nostack),
        .halt_req(halt_req), .emu_run(emu_run),
        .nmi_clear(nmi_clear), .emu_ack(emu_ack),
        .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_size(mem_size), .mem_iaq(mem_iaq),
        .mem_rdata(mem_rdata), .mem_ack(mem_ack),
        .pc(pc), .st(st), .ir(ir), .retire(retire), .fault(fault)
    );

    function automatic [31:0] read_field(input [31:0] address, input [5:0] size);
        integer bit_index;
        reg [31:0] physical;
        begin
            read_field=0;
            if (size==32 && address==32'hffffffe0) read_field=32'h1000;
            else if (size==32 && address==32'hfffffec0) read_field=32'h1100;
            else if (size==32 && address==32'hfffffee0) read_field=32'h1200;
            else begin
                if (size<1 || size>32 || address+size>32'd16384)
                    $fatal(1,"invalid read @%h/%0d",address,size);
                for (bit_index=0;bit_index<32;bit_index=bit_index+1)
                    if (bit_index<size) begin
                        physical=address+bit_index;
                        read_field[bit_index]=words[physical>>4][physical[3:0]];
                    end
            end
        end
    endfunction

    task automatic write_field(input [31:0] address, input [5:0] size,
                               input [31:0] data);
        integer bit_index;
        reg [31:0] physical;
        begin
            if (size<1 || size>32 || address+size>32'd16384)
                $fatal(1,"invalid write @%h/%0d",address,size);
            for (bit_index=0;bit_index<32;bit_index=bit_index+1)
                if (bit_index<size) begin
                    physical=address+bit_index;
                    words[physical>>4][physical[3:0]]=data[bit_index];
                end
        end
    endtask

    always @(posedge clk) begin
        mem_ack<=0;
        if (rst) begin
            busy<=0;
            requests<=0;
            writes<=0;
        end else if (mem_ack) begin
            mem_ack<=0;
        end else if (!busy && mem_req) begin
            held_addr<=mem_addr;
            held_data<=mem_wdata;
            held_size<=mem_size;
            held_we<=mem_we;
            held_iaq<=mem_iaq;
            delay_left<=2+(requests%2);
            requests<=requests+1;
            busy<=1;
        end else if (busy) begin
            if (!mem_req || mem_addr!==held_addr || mem_size!==held_size ||
                mem_we!==held_we || mem_iaq!==held_iaq ||
                (held_we && mem_wdata!==held_data))
                $fatal(1,"held memory request changed");
            if (delay_left!=0) delay_left<=delay_left-1;
            else begin
                if (held_we) begin
                    write_field(held_addr,held_size,held_data);
                    writes<=writes+1;
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
    always @(posedge clk) if (!rst && fault) $fatal(1,"fault IR=%h PC=%h",ir,pc);

    task automatic next_retire(input [31:0] expected_pc, input [31:0] expected_st);
        integer old_count;
        begin
            old_count=retired;
            wait(retired>old_count);
            if (retired!=old_count+1 || pc!==expected_pc || st!==expected_st)
                $fatal(1,"retire %0d PC=%h/%h ST=%h/%h",
                    retired,pc,expected_pc,st,expected_st);
        end
    endtask

    task automatic entry_at(input [31:0] target, input integer old_retired);
        integer cycles;
        begin
            cycles=0;
            while (pc!==target && cycles<500) begin
                @(negedge clk);
                cycles=cycles+1;
                if (retired!=old_retired)
                    $fatal(1,"hardware entry retired an instruction");
            end
            if (pc!==target || retired!=old_retired || st!==32'h00000010)
                $fatal(1,"interrupt entry PC=%h ST=%h retire=%0d",pc,st,retired);
        end
    endtask

    task automatic quiet_for(input integer cycles);
        integer old_requests, old_retired;
        begin
            old_requests=requests;
            old_retired=retired;
            repeat(cycles) begin
                @(negedge clk);
                if (mem_req || requests!=old_requests || retired!=old_retired)
                    $fatal(1,"halt/EMU issued memory or retired PC=%h",pc);
            end
        end
    endtask

    initial begin
        if (!$value$plusargs("mode=%d",mode)) $fatal(1,"missing +mode");
        for (i=0;i<1024;i=i+1) words[i]=16'h0300;
        // Mode 1: EINT -> branch -> IRQ, RETI -> DINT -> IRQ masked.
        // Mode 2: PUTST makes IE visible at the following boundary.
        // Mode 3: POPST makes IE visible at the following boundary.
        // Mode 4: NMI (NMIM=0) saves context despite IE=0.
        // Mode 5: NMI (NMIM=1) wins over simultaneous HLT and saves nothing.
        // Mode 6: a core already halted ignores even NMI until HLT clears.
        // Mode 7: EMU waits without bus traffic, then RUN resumes.
        // Mode 8: EINT and RETI each enable IRQ at their next boundary.
        if ((mode>=1 && mode<=6) || mode==8) begin
            words['h100]=16'h09CF; words['h101]=16'h0300; // MOVI SP
            words['h110]=16'h0940; // IRQ handler: RETI
            words['h120]=16'h0300; // NMI handler: NOP
        end
        case (mode)
            1: begin
                words['h102]=16'h0D60; // EINT
                words['h103]=16'hC002; // JRUC +2 -> 1060
                words['h104]=16'h0300;
                words['h105]=16'h0300;
                words['h106]=16'h0360; // DINT after RETI
                words['h107]=16'h0300;
            end
            2: begin
                words['h102]=16'h09E0; words['h103]=16'h0010;
                words['h104]=16'h0020; // MOVI IL 00200010,A0
                words['h105]=16'h01A0; // PUTST A0
            end
            3: begin
                words['h102]=16'h01C0; // POPST from [0300]
                words['h030]=16'h0010; words['h031]=16'h0020;
            end
            4,5,6: begin
                words['h102]=16'h0300;
            end
            7: begin
                words['h100]=16'h0100; // EMU
                words['h101]=16'h0300;
                emu_run=0;
            end
            8: begin
                words['h102]=16'h0D60; // EINT
                words['h103]=16'h0300;
            end
            default: $fatal(1,"unknown system test mode");
        endcase
        repeat(5) @(negedge clk);
        rst=0;
        case (mode)
            1: begin
                next_retire(32'h1020,32'h10);
                next_retire(32'h1030,32'h00200010);
                next_retire(32'h1060,32'h00200010);
                irq_req=1;
                entry_at(32'h1100,3);
                irq_req=0;
                if (u_cpu.u_regs.ram0[15]!==32'h02C0 || writes!=4 ||
                    read_field(32'h02C0,32)!==32'h00200010 ||
                    read_field(32'h02E0,32)!==32'h1060)
                    $fatal(1,"IRQ stack SP=%h writes=%0d ST=%h PC=%h",
                        u_cpu.u_regs.ram0[15],writes,
                        read_field(32'h02C0,32),read_field(32'h02E0,32));
                next_retire(32'h1060,32'h00200010); // RETI
                next_retire(32'h1070,32'h00000010); // DINT
                irq_req=1;
                next_retire(32'h1080,32'h00000010); // NOP, IRQ masked
                irq_req=0;
            end
            2: begin
                next_retire(32'h1020,32'h10);
                next_retire(32'h1050,32'h10);
                next_retire(32'h1060,32'h00200010);
                irq_req=1;
                entry_at(32'h1100,3);
                irq_req=0;
                if (read_field(32'h02E0,32)!==32'h1060)
                    $fatal(1,"PUTST IRQ did not stack next PC");
                next_retire(32'h1060,32'h00200010);
            end
            3: begin
                next_retire(32'h1020,32'h10);
                next_retire(32'h1030,32'h00200010);
                irq_req=1;
                entry_at(32'h1100,2);
                irq_req=0;
                if (u_cpu.u_regs.ram0[15]!==32'h02E0 ||
                    read_field(32'h0300,32)!==32'h1030)
                    $fatal(1,"POPST IRQ stack is wrong");
                next_retire(32'h1030,32'h00200010);
            end
            4: begin
                next_retire(32'h1020,32'h10);
                nmi_req=1;
                entry_at(32'h1200,1);
                nmi_req=0;
                if (nmi_clears!=1 || writes!=4 ||
                    u_cpu.u_regs.ram0[15]!==32'h02C0 ||
                    read_field(32'h02E0,32)!==32'h1020 ||
                    read_field(32'h02C0,32)!==32'h10)
                    $fatal(1,"stacking NMI state/clear wrong");
                next_retire(32'h1210,32'h10);
            end
            5: begin
                next_retire(32'h1020,32'h10);
                nmi_nostack=1;
                nmi_req=1;
                halt_req=1;
                entry_at(32'h1200,1);
                nmi_req=0;
                if (nmi_clears!=1 || writes!=0 ||
                    u_cpu.u_regs.ram0[15]!==32'h0300)
                    $fatal(1,"no-stack NMI state/clear wrong");
                quiet_for(20); // HLT takes effect at ISR boundary
                halt_req=0;
                next_retire(32'h1210,32'h10);
            end
            6: begin
                next_retire(32'h1020,32'h10);
                halt_req=1;
                quiet_for(20);
                nmi_nostack=1;
                nmi_req=1;
                quiet_for(20);
                if (nmi_clears!=0) $fatal(1,"halted core accepted NMI");
                halt_req=0;
                entry_at(32'h1200,1);
                nmi_req=0;
                if (nmi_clears!=1) $fatal(1,"pending NMI not accepted");
            end
            7: begin
                next_retire(32'h1010,32'h10);
                if (!emu_ack) $fatal(1,"EMU did not acknowledge");
                quiet_for(20);
                emu_run=1;
                next_retire(32'h1020,32'h10);
            end
            8: begin
                next_retire(32'h1020,32'h10);
                next_retire(32'h1030,32'h00200010); // EINT
                irq_req=1;
                entry_at(32'h1100,2);
                irq_req=0;
                if (read_field(32'h02E0,32)!==32'h1030)
                    $fatal(1,"EINT next-boundary PC stack wrong");
                next_retire(32'h1030,32'h00200010); // RETI
                irq_req=1;
                entry_at(32'h1100,3);
                irq_req=0;
                if (read_field(32'h02E0,32)!==32'h1030)
                    $fatal(1,"RETI next-boundary PC stack wrong");
            end
        endcase
        $display("PASS: system control mode %0d (%0d retires, %0d requests)",
                 mode,retired,requests);
        $finish;
    end

    initial begin
        repeat(6000) @(posedge clk);
        $fatal(1,"system timeout mode=%0d PC=%h IR=%h retires=%0d",mode,pc,ir,retired);
    end
endmodule
`default_nettype wire
