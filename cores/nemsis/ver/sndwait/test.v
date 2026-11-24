`timescale 1ns/1ps
module test;
    reg clk=0, rst=1, stall_mode=0;
    wire rom_cs, rom_rd_n, rom_wr_n, rom_mreq_n, rom_rfsh_n, rom_iorq_n;
    wire [15:0] cpu_addr;
    wire rfsh_not_mreq = rom_rfsh_n && !rom_mreq_n;
    wire rom_CE_n = !(rfsh_not_mreq && cpu_addr[15:14]==2'b00);
    wire [7:0] cpu_dout, cpu_di;
    wire generated_cen, cpu_cen;
    wire rom_ok;
    wire [7:0] rom_data;
    wire [21:0] sdram_addr;
    wire rom_req;
    reg [13:0] last_addr=0;
    reg serving=0, dst=0, we=0;
    reg [15:0] din=0;
    reg [1:0] response_phase=0;
    reg [8:0] delay_count=0;
    reg [31:0] lfsr=32'h1ACE_B00C;
    integer req_count=0;
    integer writes=0, cycles=0, reads=0, long_stalls=0;
    integer last_cen_cycle=-1, min_cen_gap=1000000;
    reg write_active=0;
    reg [7:0] rom [0:16383];
    reg [7:0] baseline [0:19];
    reg [7:0] stalled [0:19];

    always #10.172 clk=~clk; // 49.15384 MHz master clock

    // Match jtnemsis_sound's Z80 ROM decode and generated mem clock gate.
    assign rom_cs = !rom_CE_n;
    jtframe_gated_cen #(.W(1),.NUM(67),.DEN(1840),.MFREQ(49153)) u_cpu_gate(
        .rst(rst), .clk(clk), .busy(rom_cs && !rom_ok), .cen(generated_cen),
        .fave(), .fworst()
    );

    // Exercise the production byte cache used behind jtframe_rom with
    // OKLATCH=1. The two response beats match jtframe_rom's selected cache
    // write protocol; address hits return the selected byte combinationally.
    jtframe_romrq_bcache #(.SDRAMW(22),.AW(14),.DW(8),.OKLATCH(1)) u_rom(
        .rst(rst), .clk(clk), .clr(1'b0), .offset(22'd0),
        .din(din), .din_ok(we), .dst(dst), .we(we),
        .req(rom_req), .sdram_addr(sdram_addr),
        .addr(cpu_addr[13:0]), .addr_ok(rom_cs),
        .data_ok(rom_ok), .dout(rom_data)
    );

    assign cpu_cen = generated_cen;

    T80s uut(
        .RESET_n(~rst), .CLK(clk), .CEN(cpu_cen), .WAIT_n(1'b1),
        .INT_n(1'b1), .NMI_n(1'b1), .BUSRQ_n(1'b1), .OUT0(1'b0),
        .DI(cpu_di), .M1_n(), .MREQ_n(rom_mreq_n), .IORQ_n(rom_iorq_n),
        .RD_n(rom_rd_n), .WR_n(rom_wr_n), .RFSH_n(rom_rfsh_n),
        .HALT_n(), .BUSAK_n(), .A(cpu_addr), .DOUT(cpu_dout)
    );

    assign cpu_di = rom_cs ? rom_data : 8'hff;

    initial begin
        rom[0]=8'h3E; rom[1]=8'h42;             // LD A,42h
        rom[2]=8'h32; rom[3]=8'h00; rom[4]=8'h80; // LD (8000h),A
        rom[5]=8'h3C;                           // INC A
        rom[6]=8'hC3; rom[7]=8'h02; rom[8]=8'h00; // JP 0002h
        for(integer i=9;i<16384;i=i+1) rom[i]=8'h00;
    end

    always @(posedge clk) begin
        if(rst) begin
            last_addr <= 0;
            serving <= 0;
            dst <= 0;
            we <= 0;
            din <= 0;
            response_phase <= 0;
            delay_count <= 0;
            lfsr <= 32'h1ACE_B00C;
            req_count <= 0;
            writes <= 0;
            cycles <= 0;
            reads <= 0;
            long_stalls <= 0;
            last_cen_cycle <= -1;
            min_cen_gap <= 1000000;
            write_active <= 0;
        end else begin
            cycles <= cycles+1;
            if(cpu_cen) begin
                if(last_cen_cycle>=0 && cycles-last_cen_cycle<min_cen_gap)
                    min_cen_gap <= cycles-last_cen_cycle;
                last_cen_cycle <= cycles;
                if(rom_cs && !rom_rd_n) begin
                    reads <= reads+1;
                end
                if(!rom_mreq_n && !rom_wr_n && cpu_addr==16'h8000 && !write_active) begin
                    if(stall_mode) stalled[writes] <= cpu_dout;
                    else baseline[writes] <= cpu_dout;
                    writes <= writes+1;
                    write_active <= 1;
                end
                if(rom_wr_n) write_active <= 0;
            end
            if(rom_cs && cpu_addr[13:0]!=last_addr) begin
                last_addr <= cpu_addr[13:0];
                if(rom_req) begin
                req_count <= req_count+1;
                    lfsr <= {lfsr[30:0],lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};
                    if(stall_mode && req_count%19==0) begin
                        delay_count <= 9'd175; // forced long waits in the stalled run only
                        long_stalls <= long_stalls+1;
                    end else begin
                        delay_count <= stall_mode ? {4'b0,lfsr[4:0]} : 0;
                    end
                end
            end
            if(rom_req && !serving) begin
                serving <= 1;
                response_phase <= 0;
            end else if(serving && delay_count!=0) begin
                delay_count <= delay_count-1'b1;
            end else if(serving) begin
                case(response_phase)
                    0: begin
                        dst <= 1;
                        we <= 1;
                        din <= {rom[(sdram_addr[13:0]<<1)+1],rom[sdram_addr[13:0]<<1]};
                        response_phase <= 1;
                    end
                    1: begin
                        dst <= 0;
                        din <= {rom[(sdram_addr[13:0]<<1)+3],rom[(sdram_addr[13:0]<<1)+2]};
                        response_phase <= 2;
                    end
                    default: begin
                        we <= 0;
                        dst <= 0;
                        serving <= 0;
                        response_phase <= 0;
                    end
                endcase
            end else begin
                we <= 0;
                dst <= 0;
            end
            if(!rom_cs) begin
                last_addr <= 0;
            end
            if(rom_ok && rom_cs && !rom_rd_n) begin
                if(rom_data !== rom[cpu_addr[13:0]]) begin
                    $display("FAIL: actual bcache byte mismatch addr=%h got=%h expected=%h",cpu_addr[13:0],rom_data,rom[cpu_addr[13:0]]);
                    $fatal(1);
                end
            end
        end
    end

    task start_case(input reg with_stalls);
        begin
            @(negedge clk); rst=1; stall_mode=with_stalls;
            repeat(6) @(negedge clk);
            rst=0;
            cycles=0;
            while(writes<20 && cycles<1000000) @(negedge clk);
            if(writes<20) begin
                $display("FAIL: T80 made only %0d writes (stall=%0d)",writes,with_stalls);
                $fatal(1);
            end
            if(with_stalls && long_stalls==0) begin
                $display("FAIL: missing long SDRAM refill stall (long=%0d)", long_stalls);
                $fatal(1);
            end
        end
    endtask

    initial begin
        start_case(0);
        for(integer i=0;i<20;i=i+1)
            if(baseline[i] !== 8'h42+i) begin
                $display("FAIL: baseline write[%0d]=%h expected=%h",i,baseline[i],8'h42+i);
                $fatal(1);
            end
        start_case(1);
        for(integer i=0;i<20;i=i+1)
            if(stalled[i] !== baseline[i]) begin
                $display("FAIL: stalled write[%0d]=%h baseline=%h",i,stalled[i],baseline[i]);
                $fatal(1);
            end
        if(long_stalls!=4) begin
            $display("FAIL: expected zero baseline and four stalled long refills; observed %0d",long_stalls);
            $fatal(1);
        end
        $display("PASS: T80 ROM bytes and 20-write signature match through actual OKLATCH=1 cache; baseline has zero injected delay, stalled run has random 0..31 and four 175-cycle refills; reads=%0d min CEN spacing=%0d clocks",reads,min_cen_gap);
        $finish;
    end
endmodule
