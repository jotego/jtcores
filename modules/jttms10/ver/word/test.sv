`timescale 1ns/1ps
module test;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, cen = 1;
    wire word_req, word_we, word_iaq, word_lock, word_pixel, retire, fault;
    wire [31:0] word_addr, pc, st;
    wire [15:0] word_wdata, ir;
    reg [15:0] word_rdata = 0;
    reg word_ack = 0;
    reg [15:0] words [0:1023];
    reg [31:0] stack_write_addr [0:7];
    reg [15:0] stack_write_data [0:7];
    integer stack_writes=0;
    integer k;

    jttms10_word u_cpu(
        .rst(rst), .clk(clk), .cen(cen),
        .convsp(16'd0),.pmask(16'd0),.wvp_set(),.psize(16'd16), .convdp(16'h14), .control(16'h8000),
        .cache_flush(1'b0),
        .irq_req(1'b0), .irq_vector(32'd0),
        .nmi_req(1'b0), .nmi_nostack(1'b0),
        .halt_req(1'b0), .emu_run(1'b1),
        .nmi_clear(), .emu_ack(),
        .word_req(word_req), .word_pending(),.word_early(), .word_we(word_we), .word_addr(word_addr),
        .word_wdata(word_wdata), .word_iaq(word_iaq), .word_lock(word_lock),
        .pixel_srt(1'b0), .word_pixel(word_pixel),
        .word_rdata(word_rdata), .word_ack(word_ack), .word_restart(1'b0), .word_wait(1'b0),
        .pc(pc), .st(st), .ir(ir), .retire(retire), .fault(fault)
    );

    initial begin
        for (k=0; k<1024; k=k+1) words[k]=16'h0300;
        words['h20]=16'hA55A;
        words['h21]=16'h5AA5;
        words['h22]=16'h0F0F;
        words['h100]=16'h09C0; // MOVI IW 020B,A0
        words['h101]=16'h020B;
        words['h102]=16'h09C1; // MOVI IW DEAD,A1
        words['h103]=16'hDEAD;
        words['h104]=16'h8020; // MOVE A1,*A0: unaligned FS0=16 write
        words['h105]=16'h8402; // MOVE *A0,A2: read back and zero extend
        words['h106]=16'h09CF; // MOVI IW 0300,SP
        words['h107]=16'h0300;
        words['h108]=16'h09E3; // MOVI IL 60200010,A3
        words['h109]=16'h0010;
        words['h10A]=16'h6020;
        words['h10B]=16'h01A3; // PUTST A3
        words['h10C]=16'h01E0; // PUSHST
        words['h10D]=16'h0D5F; // CALLA 1140
        words['h10E]=16'h1140;
        words['h10F]=16'h0000;
        words['h110]=16'h0901; // TRAP 1 after return
        words['h114]=16'h0960; // RETS 0
        words['h120]=16'h0940; // RETI (not reached before check)
        repeat (5) @(negedge clk);
        rst=0;
    end

    reg busy=0, held_we, held_iaq, held_lock;
    reg [31:0] held_addr;
    reg [15:0] held_wdata;
    integer delay_left=0, requests=0, locked_reads=0, locked_writes=0;
    reg pause_done=0, paused_ack=0;
    integer pause_left=0;
    reg [31:0] pause_pc;
    reg drain_pending=0;
    integer drains=0;
    wire expected_iaq =
        word_addr==32'h1000 || word_addr==32'h1020 ||
        word_addr==32'h1040 || word_addr==32'h1050 ||
        word_addr==32'h1060 || word_addr==32'h1080 ||
        word_addr==32'h10B0 || word_addr==32'h10C0 ||
        word_addr==32'h10D0 ||
        word_addr==32'h1100 || word_addr==32'h1140;

    // One pulse acknowledges each physical word. The responder can accept
    // the next payload even when word_req never falls between word cycles.
    always @(posedge clk) begin
        if (rst) begin
            busy<=0;
            word_ack<=0;
            requests<=0;
            locked_reads<=0;
            locked_writes<=0;
        end else if (word_ack) begin
            word_ack<=0;
        end else if (!busy && word_req) begin
            if (word_pixel) $fatal(1,"non-pixel word test unexpectedly tagged a request");
            if (word_addr[3:0]!==4'd0)
                $fatal(1,"unaligned word address %h",word_addr);
            if (word_iaq!==expected_iaq)
                $fatal(1,"IAQ wrong for word address %h",word_addr);
            held_addr<=word_addr;
            held_wdata<=word_wdata;
            held_we<=word_we;
            held_iaq<=word_iaq;
            held_lock<=word_lock;
            delay_left<=requests%4;
            requests<=requests+1;
            if (word_lock && word_we) locked_writes<=locked_writes+1;
            if (word_lock && !word_we) locked_reads<=locked_reads+1;
            busy<=1;
        end else if (busy) begin
            if (!word_req || word_addr!==held_addr ||
                word_wdata!==held_wdata || word_we!==held_we ||
                word_iaq!==held_iaq || word_lock!==held_lock)
                $fatal(1,"word payload changed before acknowledgement");
            if (delay_left!=0)
                delay_left<=delay_left-1;
            else begin
                if (held_addr==32'hffffffe0) begin
                    if (held_we) $fatal(1,"reset vector written");
                    word_rdata<=16'h1000;
                end else if (held_addr==32'hfffffff0) begin
                    if (held_we) $fatal(1,"reset vector written");
                    word_rdata<=16'd0;
                end else if (held_addr==32'hffffffc0) begin
                    if (held_we) $fatal(1,"trap vector written");
                    word_rdata<=16'h1200;
                end else if (held_addr==32'hffffffd0) begin
                    if (held_we) $fatal(1,"trap vector written");
                    word_rdata<=16'd0;
                end else if (held_addr>=32'd16384)
                    $fatal(1,"out of range address %h",held_addr);
                else if (held_we) begin
                    if (held_addr>=32'h0280 && held_addr<32'h0300) begin
                        if (stack_writes>=8) $fatal(1,"extra stack write");
                        stack_write_addr[stack_writes]<=held_addr;
                        stack_write_data[stack_writes]<=held_wdata;
                        stack_writes<=stack_writes+1;
                    end
                    words[held_addr>>4]<=held_wdata;
                end else
                    word_rdata<=words[held_addr>>4];
                word_ack<=1;
                busy<=0;
            end
        end
    end

    // At a field-ack edge the core captures the response, including while
    // cen is low. The next clock must present req=0 so RESPONSE can drain.
    always @(posedge clk) begin
        if (rst) begin
            drain_pending<=0;
            drains<=0;
        end else begin
            if (drain_pending) begin
                if (u_cpu.field_req)
                    $fatal(1,"field request did not fall after ack");
                drains<=drains+1;
            end
            drain_pending<=u_cpu.field_ack && u_cpu.field_req;
        end
    end

    // Pause the CPU as the first field word completes. The field adapter
    // finishes independently, and the core must capture its held ack.
    always @(posedge clk) begin
        if (rst) begin
            pause_done<=0;
            pause_left<=0;
            paused_ack<=0;
        end else begin
            if (!pause_done && word_ack && held_addr==32'h0200) begin
                cen<=0;
                pause_done<=1;
                pause_left<=25;
                pause_pc<=pc;
            end else if (pause_left>0) begin
                if (pc!==pause_pc || retire)
                    $fatal(1,"CPU advanced while paused");
                pause_left<=pause_left-1;
                if (pause_left==1) cen<=1;
            end
            if (!cen && u_cpu.field_ack) paused_ack<=1;
        end
    end

    integer retired=0;
    always @(posedge retire) begin
        #1;
        if (fault) $fatal(1,"CPU fault IR=%h",ir);
        retired=retired+1;
        if (retired==4) begin
            if (pc!==32'h1060 ||
                u_cpu.u_core.u_regs.ram0[0]!==32'h020b ||
                u_cpu.u_core.u_regs.ram0[1]!==32'hffffdead ||
                u_cpu.u_core.u_regs.ram0[2]!==32'h0000dead)
                $fatal(1,"CPU state wrong PC=%h A0=%h A1=%h A2=%h",
                    pc,u_cpu.u_core.u_regs.ram0[0],
                    u_cpu.u_core.u_regs.ram0[1],u_cpu.u_core.u_regs.ram0[2]);
            if (words['h20]!==16'h6D5A || words['h21]!==16'h5EF5 ||
                words['h22]!==16'h0F0F)
                $fatal(1,"unaligned write wrong %h %h %h",
                    words['h20],words['h21],words['h22]);
            if (locked_reads!=2 || locked_writes!=2 || drains<9 ||
                !pause_done || !paused_ack)
                $fatal(1,"RMW, drain or pause coverage failed %0d/%0d drains=%0d pause=%b/%b",
                    locked_reads,locked_writes,drains,pause_done,paused_ack);
        end
        if (retired==11) begin
            if (pc!==32'h1200 || st!==32'h00000010 ||
                u_cpu.u_core.u_regs.ram0[15]!==32'h02A0 || stack_writes!=8)
                $fatal(1,"stack state PC=%h ST=%h SP=%h writes=%0d",
                    pc,st,u_cpu.u_core.u_regs.ram0[15],stack_writes);
            if (stack_write_addr[0]!==32'h02F0 || stack_write_data[0]!==16'h6020 ||
                stack_write_addr[1]!==32'h02E0 || stack_write_data[1]!==16'h0010 ||
                stack_write_addr[2]!==32'h02D0 || stack_write_data[2]!==16'h0000 ||
                stack_write_addr[3]!==32'h02C0 || stack_write_data[3]!==16'h1100 ||
                stack_write_addr[4]!==32'h02D0 || stack_write_data[4]!==16'h0000 ||
                stack_write_addr[5]!==32'h02C0 || stack_write_data[5]!==16'h1110 ||
                stack_write_addr[6]!==32'h02B0 || stack_write_data[6]!==16'h6020 ||
                stack_write_addr[7]!==32'h02A0 || stack_write_data[7]!==16'h0010)
                $fatal(1,"PUSHST/CALL/TRAP physical writes must be MSW first");
            $display("PASS: word wrapper, %0d requests, two RMW pairs, paused ack, MSW-first PUSHST/CALL/TRAP",requests);
            $finish;
        end
    end

    initial begin
        #100000;
        $fatal(1,"wrapper timed out PC=%h IR=%h requests=%0d",pc,ir,requests);
    end
endmodule
